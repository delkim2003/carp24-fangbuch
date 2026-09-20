import { getSupabaseUrl, getSupabaseAnonKey } from "../../../lib/config";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";
import { createServiceClient } from "../../../lib/ssr-client";

export const prerender = false;

const OPEN_METEO_BASE = "https://api.open-meteo.com/v1/forecast";
const freeRateLimitMap = new Map<string, number>();

/**
 * Fetch current weather from Open-Meteo for given coordinates.
 * Returns structured weather data or null on failure.
 */
async function fetchWeather(
  lat: number,
  lng: number,
): Promise<Record<string, unknown> | null> {
  const url = new URL(OPEN_METEO_BASE);
  url.searchParams.set("latitude", String(lat));
  url.searchParams.set("longitude", String(lng));
  url.searchParams.set(
    "current",
    "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,pressure_msl",
  );
  url.searchParams.set("timezone", "auto");

  try {
    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(5000) });
    if (!res.ok) {
      console.error("[WEATHER] Open-Meteo HTTP", res.status, await res.text());
      return null;
    }
    const data = await res.json();
    const current = data?.current;
    if (!current) {
      console.error("[WEATHER] No current data in Open-Meteo response");
      return null;
    }
    const weatherCode = current.weather_code;
    const weatherTextMap: Record<number, string> = {
      0: 'Klar', 1: 'Überwiegend klar', 2: 'Teils bewölkt', 3: 'Bewölkt',
      45: 'Nebel', 48: 'Reifnebel',
      51: 'Leichter Nieselregen', 53: 'Nieselregen', 55: 'Starker Nieselregen',
      61: 'Leichter Regen', 63: 'Regen', 65: 'Starker Regen',
      66: 'Gefrierender Regen', 67: 'Starker gefrierender Regen',
      71: 'Leichter Schneefall', 73: 'Schneefall', 75: 'Starker Schneefall',
      77: 'Schneegriesel', 80: 'Leichte Regenschauer', 81: 'Regenschauer', 82: 'Starke Regenschauer',
      85: 'Leichte Schneeschauer', 86: 'Starke Schneeschauer',
      95: 'Gewitter', 96: 'Gewitter mit Hagel', 99: 'Starkes Gewitter mit Hagel',
    };

    // Simple moon phase calculation
    function getMoonPhase(date: Date): string {
      const year = date.getFullYear();
      const month = date.getMonth() + 1;
      const day = date.getDate();
      let c = 0, e = 0, jd = 0, b = 0;
      if (month < 3) { c = year - 1; e = month + 12; } else { c = year; e = month; }
      jd = Math.floor(365.25 * (c + 4716)) + Math.floor(30.6001 * (e + 1)) + day - 1524.5;
      b = Math.round(((jd - 2451550.1) / 29.530588853) * 100) / 100;
      const phase = ((b % 1) + 1) % 1;
      if (phase < 0.0625) return 'Neumond';
      if (phase < 0.1875) return 'Zunehmend';
      if (phase < 0.3125) return 'Erstes Viertel';
      if (phase < 0.4375) return 'Zunehmender Mond';
      if (phase < 0.5625) return 'Vollmond';
      if (phase < 0.6875) return 'Abnehmender Mond';
      if (phase < 0.8125) return 'Letztes Viertel';
      if (phase < 0.9375) return 'Abnehmend';
      return 'Neumond';
    }

    return {
      temp_c: current.temperature_2m,
      weather_text: weatherTextMap[weatherCode] || 'Unbekannt',
      pressure_hpa: Math.round(current.pressure_msl),
      wind_speed_kmh: Math.round(current.wind_speed_10m),
      humidity_pct: current.relative_humidity_2m,
      moon_text: getMoonPhase(new Date()),
      // Keep raw data for reference
      _raw: {
        weather_code: weatherCode,
        time: current.time,
      },
    };
  } catch (err) {
    console.error("[WEATHER] Fetch error:", err);
    return null;
  }
}

export const POST = async ({
  request,
  locals,
}: {
  request: Request;
  locals: App.Locals;
}) => {
  const user = locals.user;

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createServerClient(
    getSupabaseUrl(),
    getSupabaseAnonKey(),
    {
      cookies: {
        getAll() { return parseCookieHeader(request.headers.get("Cookie") ?? ""); },
        setAll() {},
      },
      auth: { storageKey: "sb-carp24-auth-token" },
    }
  );

  // Nutze isPro aus Middleware (bereits via Service-Role gecacht)
  const isPro = (locals as any).isPro ?? false;

  if (!isPro) {
    const now = Date.now();
    const lastRequest = freeRateLimitMap.get(user.id);
    if (lastRequest && now - lastRequest < 60_000) {
      return new Response(
        JSON.stringify({ error: "Bitte kurz warten (Free-Limit)." }),
        { status: 429, headers: { "Content-Type": "application/json" } }
      );
    }
    freeRateLimitMap.set(user.id, now);
  }

  let body: { catch_id?: string; lat?: number; lng?: number; catch_ts?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültiger Body." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { catch_id, lat, lng, catch_ts } = body;

  if (!catch_id || typeof catch_id !== "string") {
    return new Response(JSON.stringify({ error: "catch_id fehlt." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (lat == null || lng == null || typeof lat !== "number" || typeof lng !== "number") {
    return new Response(JSON.stringify({ error: "lat/lng fehlen oder ungültig." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!catch_ts || typeof catch_ts !== "string") {
    return new Response(JSON.stringify({ error: "catch_ts fehlt." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Check if catch_ts is within 24 hours of now
  const catchTime = new Date(catch_ts).getTime();
  const now = Date.now();
  const twentyFourHours = 24 * 60 * 60 * 1000;

  if (isNaN(catchTime) || now - catchTime > twentyFourHours) {
    // Outside 24h window — nothing to do, return ok
    return new Response(JSON.stringify({ ok: true, skipped: true, reason: "catch_ts älter als 24h" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Use service client for DB operations (auth already verified via middleware locals.user)
  const adminSb = createServiceClient();

  // Verify the catch belongs to this user
  const { data: catchRow, error: fetchError } = await adminSb
    .from("catches")
    .select("user_id")
    .eq("id", catch_id)
    .single();

  if (fetchError || !catchRow) {
    return new Response(JSON.stringify({ error: "Fang nicht gefunden." }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (catchRow.user_id !== user.id) {
    return new Response(JSON.stringify({ error: "Nicht dein Fang." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Fetch weather from Open-Meteo
  const weather = await fetchWeather(lat, lng);
  if (!weather) {
    return new Response(JSON.stringify({ error: "Wetterdaten konnten nicht abgerufen werden." }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Update the catch record (use service client to bypass RLS — auth already verified above)
  const { error: updateError } = await adminSb
    .from("catches")
    .update({
      weather,
      weather_auto: true,
    })
    .eq("id", catch_id);

  if (updateError) {
    console.error("[WEATHER] DB update error:", updateError.message);
    return new Response(JSON.stringify({ error: updateError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true, weather }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};