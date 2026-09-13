import { createServerClient, parseCookieHeader } from "@supabase/ssr";

export const prerender = false;

// DSGVO: transiente Verarbeitung, keine Speicherung, kein Logging.
const rateLimitMap = new Map<string, number>();

async function getApiKey(supabase: any): Promise<string | null> {
  // 1. Check env var first (fast path)
  const envKey = import.meta.env.OPENROUTER_API_KEY;
  if (envKey) return envKey;

  // 2. Fall back to DB-stored key
  try {
    const { data } = await supabase
      .from("app_settings")
      .select("value")
      .eq("key", "openrouter_key")
      .single();
    return data?.value?.key || null;
  } catch {
    return null;
  }
}

// Moon phase mapping
const moonPhaseNames: Record<string, string> = {
  '0': 'Neumond',
  '0.25': 'Erstes Viertel',
  '0.5': 'Vollmond',
  '0.75': 'Letztes Viertel',
  'zunehmend': 'zunehmend',
  'abnehmend': 'abnehmend'
};

function formatMoonPhase(moonText: string): string {
  if (!moonText) return 'unbekannt';
  
  // Try exact match first
  if (moonPhaseNames[moonText]) {
    return moonPhaseNames[moonText];
  }
  
  // Try to extract numeric value
  const match = moonText.match(/(\d+(?:\.\d+)?)/);
  if (match) {
    const value = match[1];
    if (moonPhaseNames[value]) {
      return moonPhaseNames[value];
    }
  }
  
  return moonText;
}

function getMoonPhaseDescription(moonPhase: number): string {
  if (moonPhase === 0) return 'Neumond (schlechteste Bedingungen für Karpfen)';
  if (moonPhase === 0.25) return 'Erstes Viertel (gute Bedingungen)';
  if (moonPhase === 0.5) return 'Vollmond (schlechte Bedingungen für Karpfen)';
  if (moonPhase === 0.75) return 'Letztes Viertel (gute Bedingungen)';
  if (moonPhase < 0.5) return 'zunehmender Mond (gute Bedingungen) ';
  if (moonPhase > 0.5) return 'abnehmender Mond (gute Bedingungen)';
  return 'unbekannte Mondphase';
}

function getWeatherDescription(weatherText: string): string {
  const weatherMap: Record<string, string> = {
    'clear': 'klar',
    'partly cloudy': 'leicht bewölkt',
    'cloudy': 'bewölkt',
    'overcast': 'bedeckt',
    'fog': 'Nebel',
    'drizzle': 'Nieselregen',
    'light rain': 'leichter Regen',
    'rain': 'Regen',
    'heavy rain': 'starker Regen',
    'snow': 'Schnee',
    'thunderstorm': 'Gewitter'
  };
  
  const key = weatherText?.toLowerCase();
  return weatherMap[key] || weatherText || 'unbekannt';
}

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() { return parseCookieHeader(request.headers.get("Cookie") ?? ""); },
        setAll() {},
      },
      auth: { storageKey: "sb-carp24-auth-token" },
    }
  );

  let user = locals.user;

  if (!user) {
    const { data: { user: ssrUser } } = await supabase.auth.getUser();
    if (ssrUser) user = ssrUser;
  }

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userId = user.id;

  const { data: profile } = await supabase
    .from("profiles")
    .select("is_pro, role")
    .eq("id", userId)
    .single();

  if (!profile?.is_pro) {
    return new Response(
      JSON.stringify({ error: "Nur für Premium-Mitglieder verfügbar. Jetzt upgraden: /premium" }),
      { status: 403, headers: { "Content-Type": "application/json" } }
    );
  }

  // Monthly usage limit: 50/month for Pro, admin bypasses
  const isAdmin = profile?.role === "ADMIN";
  let remaining = 999;

  if (!isAdmin) {
    const { data: monthlyUsage } = await supabase.rpc("get_ai_usage_monthly", { p_user_id: userId });
    const used = monthlyUsage || 0;
    remaining = Math.max(0, 50 - used);
    if (used >= 50) {
      return new Response(
        JSON.stringify({ error: "Monatslimit erreicht (50/Monat). Nächster Monat geht es weiter." }),
        { status: 429, headers: { "Content-Type": "application/json" } }
      );
    }
  }

  // Rate-Limit: 10s pro User
  const now = Date.now();
  const lastRequest = rateLimitMap.get(userId);
  if (lastRequest && now - lastRequest < 10_000) {
    return new Response(JSON.stringify({ error: "Bitte kurz warten." }), {
      status: 429,
      headers: { "Content-Type": "application/json" },
    });
  }
  rateLimitMap.set(userId, now);

  // Look up API key (env → DB)
  const apiKey = await getApiKey(supabase);
  if (!apiKey) {
    return new Response(
      JSON.stringify({
        error:
          "KI-Assistent ist nicht konfiguriert. Bitte den API-Key im Admin-Bereich unter Einstellungen hinterlegen.",
      }),
      {
        status: 503,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  let body: { mode?: string; location?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const mode = body.mode;
  const location = body.location?.trim();
  const lat = body.lat;
  const lon = body.lon;

  if (!mode || (mode === 'forecast' && !location)) {
    return new Response(JSON.stringify({ error: "Modus oder Standort erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Fetch user's catches with weather data
  const { data: catches } = await supabase
    .from("catches")
    .select("catch_ts, weight_kg, species, water_name, weather")
    .eq("user_id", userId)
    .is("deleted_at", null)
    .order("catch_ts", { ascending: false })
    .limit(50);

  let contextStr = "Keine Fänge vorhanden.";
  let catchesWithWeather = [];
  
  if (catches && catches.length > 0) {
    catchesWithWeather = catches.filter(c => c.weather && Object.keys(c.weather).length > 0);
    
    if (catchesWithWeather.length > 0) {
      contextStr = catchesWithWeather
        .map((c: any) => {
          const date = c.catch_ts ? new Date(c.catch_ts).toLocaleDateString("de-DE") : "?";
          const kg = c.weight_kg ? c.weight_kg + " kg" : "?";
          const species = c.species || "unbekannt";
          const water = c.water_name || "unbekannt";
          const w = c.weather || {};
          const moonPhase = w.moon_text ? formatMoonPhase(w.moon_text) : 'unbekannt';
          const wInfo = w.pressure_hpa || w.weather_text || w.temp_c || w.wind_speed_kmh 
            ? `, ${w.pressure_hpa ? w.pressure_hpa + 'hPa' : '?'}, ${getWeatherDescription(w.weather_text)}, ${w.temp_c ? w.temp_c + '°C' : '?'}C, ${w.wind_speed_kmh ? w.wind_speed_kmh + 'km/h' : '?'}km/h, Mond: ${moonPhase}`
            : '';
          return `${date}, ${kg}, ${species}, ${water}${wInfo}`;
        })
        .join("\n");
    }
  }

  // Calculate confidence percentage based on data quality
  const totalCatches = catches?.length || 0;
  const withWeather = catchesWithWeather.length;
  
  // Base confidence from catch count
  let confidence = 0;
  if (withWeather >= 50) confidence = 90;
  else if (withWeather >= 30) confidence = 75;
  else if (withWeather >= 15) confidence = 55;
  else if (withWeather >= 6) confidence = 35;
  else if (withWeather >= 3) confidence = 20;
  else confidence = 10;
  
  // Bonus for diversity
  const weatherTypes = new Set(catchesWithWeather.map(c => c.weather?.weather_text).filter(Boolean));
  const moonPhases = new Set(catchesWithWeather.map(c => c.weather?.moon_text).filter(Boolean));
  const waters = new Set(catches?.map(c => c.water_name).filter(Boolean));
  
  if (weatherTypes.size >= 3) confidence += 5;
  if (moonPhases.size >= 3) confidence += 5;
  if (waters.size >= 2) confidence += 3;
  
  // Cap at 95
  confidence = Math.min(confidence, 95);

  let systemPrompt = "";
  let userPrompt = "";

  if (mode === 'best-conditions') {
    // System prompt for best conditions analysis
    systemPrompt = `
Du bist der Carp24-Fang-Assistent für optimale Angelbedingungen.

Analysiere AUSSCHLIESSLICH die bereitgestellten Fangdaten. Erfinde NICHTS.

REGELN:
- Berichte NUR was in den Daten steht
- KEINE Angelmethoden, Köder-Tipps, Rig-Empfehlungen
- KEINE allgemeinen Angelratschläge
- Wenn Daten fehlen: "Dazu liegen keine Daten vor"
- Max 150 Wörter, Deutsch, sachlich

Antworte strukturiert mit diesen Punkten (nur was Daten hergeben):
1. MONDPHASE mit den meisten/besten Fängen
2. WETTER mit den meisten/besten Fängen
3. LUFTDRUCK-Bereich mit den meisten/besten Fängen
4. TEMPERATUR-Bereich mit den meisten/besten Fängen
5. WIND-Bereich mit den meisten/besten Fängen
`;

    userPrompt = `Fang-Kontext mit Wetterdaten:
${contextStr}

Analysiere diese Daten und gib die besten Angelbedingungen für den Nutzer an.`;
  
  } else if (mode === 'forecast' && location) {
    // Forecast mode - need to fetch weather data first
    
    let lat = 0;
    let lon = 0;
    
    // Use provided lat/lon if available, otherwise geocode
    if (body.lat && body.lon) {
      lat = body.lat;
      lon = body.lon;
    } else {
      try {
        const geoResponse = await fetch(
          `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(location)}&count=1&language=de`
        );
        
        if (!geoResponse.ok) {
          throw new Error('Geocoding failed');
        }
        
        const geoData = await geoResponse.json();
        
        if (!geoData.results || geoData.results.length === 0) {
          throw new Error('Location not found');
        }
        
        lat = geoData.results[0].latitude;
        lon = geoData.results[0].longitude;
        
      } catch (error) {
        return new Response(
          JSON.stringify({ error: `Standort konnte nicht gefunden werden: ${location}` }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }
    }
    
    // Get 3-day forecast
    let forecastData = null;
    let moonData = null;
    
    try {
      // Get forecast
      const forecastResponse = await fetch(
        `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max,weathercode&timezone=auto`
      );
      
      if (!forecastResponse.ok) {
        throw new Error('Forecast fetch failed');
      }
      
      forecastData = await forecastResponse.json();
      
      // Get moon phase
      const moonResponse = await fetch(
        `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=moon_phase&timezone=auto`
      );
      
      if (!moonResponse.ok) {
        throw new Error('Moon phase fetch failed');
      }
      
      moonData = await moonResponse.json();
      
    } catch (error) {
      return new Response(
        JSON.stringify({ error: `Wetterdaten konnten nicht abgerufen werden: ${error}` }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // System prompt for forecast
    systemPrompt = `
Du bist der Carp24-Fangprognose-Assistent.

Vergleiche die Wettervorhersage mit den historischen Bestwerten des Nutzers.

REGELN:
- Berichte NUR Fakten aus den Daten
- KEINE Angelmethoden, Köder, Rigs oder allgemeine Tipps
- Wenn Daten fehlen: "Dazu liegen keine Daten vor"
- Max 200 Wörter, Deutsch, sachlich

Antworte strukturiert:
1. WETTER die nächsten 3 Tage (Temperatur, Wind, Regen, Mondphase — nur Fakten)
2. VERGLEICH: Stimmen die Vorhersage-Werte mit den historischen Bestwerten überein?
3. PROGNOTSE: Basierend auf den Daten — gute/mittlere/schlechte Aussichten (mit Begründung aus Daten)
`;

    // Format forecast data
    const dailyForecasts = forecastData?.daily || {};
    const moonPhases = moonData?.daily || {};
    
    const forecastText = dailyForecasts.time?.map((date: string, i: number) => {
      const maxTemp = dailyForecasts.temperature_2m_max?.[i] || '?°C';
      const minTemp = dailyForecasts.temperature_2m_min?.[i] || '?°C';
      const precip = dailyForecasts.precipitation_sum?.[i] || '0mm';
      const wind = dailyForecasts.windspeed_10m_max?.[i] || '0km/h';
      const weatherCode = dailyForecasts.weathercode?.[i] || 0;
      
      // Simple weather code to text mapping
      const weatherTextMap: Record<number, string> = {
        0: 'klar',
        1: 'überwiegend klar',
        2: 'teilweise bewölkt',
        3: 'bewölkt',
        45: 'Nebel',
        48: 'gefrierender Nebel',
        51: 'leichter Nieselregen',
        53: 'mäßiger Nieselregen',
        55: 'starker Nieselregen',
        56: 'gefrierender Nieselregen',
        57: 'starker gefrierender Nieselregen',
        61: 'leichter Regen',
        63: 'mäßiger Regen',
        65: 'starker Regen',
        66: 'gefrierender Regen',
        67: 'starker gefrierender Regen',
        71: 'leichter Schneefall',
        73: 'mäßiger Schneefall',
        75: 'starker Schneefall',
        77: 'Schneegriesel',
        80: 'leichte Regenschauer',
        81: 'mäßige Regenschauer',
        82: 'starke Regenschauer',
        85: 'leichte Schneeschauer',
        86: 'starke Schneeschauer',
        95: 'Gewitter',
        96: 'Gewitter mit leichtem Hagel',
        99: 'Gewitter mit starkem Hagel'
      };
      
      const weatherText = weatherTextMap[weatherCode] || 'unbekannt';
      const moonPhase = moonPhases.moon_phase?.[i] || 0;
      const moonPhaseDesc = getMoonPhaseDescription(moonPhase);
      
      return `Tag ${i+1} (${new Date(date).toLocaleDateString('de-DE')}): ${minTemp} bis ${maxTemp}, ${weatherText}, ${precip} Niederschlag, Wind ${wind}, ${moonPhaseDesc}`;
    }).join('\n');
    
    userPrompt = `Standort: ${location}

Historische beste Bedingungen des Nutzers:
${contextStr}

3-Tage-Wettervorhersage:
${forecastText}

Erstelle eine Angelprognose basierend AUSSCHLIESSLICH auf diesen Daten. Erfinde keine Angelmethoden, Köder oder Rigs. Berichte nur Fakten: Wetterdaten, Mondphasen, und ob die Bedingungen mit den historischen Bestwerten übereinstimmen.`;
   }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);

  try {
    const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "mistralai/mistral-small-2603",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
      signal: controller.signal,
    });

    clearTimeout(timeout);

    if (!res.ok) {
      const errorBody = await res.text().catch(() => "");
      return new Response(
        JSON.stringify({
          error: `KI-Dienst nicht erreichbar (${res.status}).`,
          detail: errorBody.slice(0, 200),
        }),
        {
          status: 502,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const data = await res.json();
    const answer = data.choices?.[0]?.message?.content || "Keine Antwort erhalten.";

    // Track usage (fire-and-forget, non-blocking)
    if (!isAdmin) {
      supabase.rpc("increment_ai_usage", { p_user_id: userId }).catch(() => {});
    }

    return new Response(JSON.stringify({ answer, confidence, catchesTotal: totalCatches, catchesWithWeather: withWeather, remaining }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    clearTimeout(timeout);
    return new Response(JSON.stringify({ error: "KI-Dienst nicht erreichbar." }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }
};