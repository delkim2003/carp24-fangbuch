// Wetter-Hook via Open-Meteo — carp24 Task 1.7
// Supabase Edge Function (native Edge-Runtime-Pattern)
// Holt Wetter-Snapshot für Fänge ≤24h, Forecast für Widget

interface HourlyData {
  time: string[];
  temperature_2m: number[];
  surface_pressure: number[];
  wind_speed_10m: number[];
  weather_code: number[];
}

interface DailyData {
  time: string[];
  moon_phase: number[];
}

interface OpenMeteoResponse {
  hourly: HourlyData;
  daily: DailyData;
}

interface WeatherSnapshot {
  temp_c: number;
  pressure_hpa: number;
  wind_kmh: number;
  weather_code: number;
  weather_text: string;
  moon_phase: number;
  moon_text: string;
  measured_at: string;
}

interface CacheEntry {
  data: OpenMeteoResponse;
  timestamp: number;
}

const CACHE_TTL_MS = 60 * 60 * 1000; // 1 Stunde
const cache = new Map<string, CacheEntry>();

const corsHeaders = {
  "Access-Control-Allow-Origin": "http://100.93.250.103:8094",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey, x-client-info",
};

const WMO_WEATHER_TEXT: Record<number, string> = {
  0: "sonnig",
  1: "überwiegend klar",
  2: "teils bewölkt",
  3: "bedeckt",
  45: "neblig",
  48: "neblig",
  51: "Nieselregen",
  53: "Nieselregen",
  55: "Nieselregen",
  56: "Nieselregen",
  57: "Nieselregen",
  61: "Regen",
  63: "Regen",
  65: "Regen",
  66: "Regen",
  67: "Regen",
  71: "Schnee",
  73: "Schnee",
  75: "Schnee",
  77: "Schnee",
  80: "Regenschauer",
  81: "Regenschauer",
  82: "Regenschauer",
  85: "Schneeschauer",
  86: "Schneeschauer",
  95: "Gewitter",
  96: "Gewitter",
  99: "Gewitter",
};

function moonText(phase: number): string {
  if (phase < 0.0625 || phase >= 0.9375) return "neumond";
  if (phase >= 0.0625 && phase < 0.3125) return "zunehmend";
  if (phase >= 0.3125 && phase < 0.5625) return "vollmond";
  if (phase >= 0.5625 && phase < 0.8125) return "abnehmend";
  return "abnehmend";
}

function getCached(key: string): OpenMeteoResponse | null {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.timestamp > CACHE_TTL_MS) {
    cache.delete(key);
    return null;
  }
  return entry.data;
}

function getStaleCache(key: string): OpenMeteoResponse | null {
  const entry = cache.get(key);
  if (!entry) return null;
  return entry.data;
}

function setCached(key: string, data: OpenMeteoResponse): void {
  cache.set(key, { data, timestamp: Date.now() });
}

function makeCacheKey(lat: number, lng: number): string {
  const hour = new Date().toISOString().slice(0, 13);
  return `${lat}:${lng}:${hour}`;
}

async function fetchOpenMeteo(lat: number, lng: number): Promise<OpenMeteoResponse> {
  const url =
    `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}` +
    `&past_days=1&hourly=temperature_2m,surface_pressure,wind_speed_10m,weather_code` +
    `&daily=moon_phase&timezone=Europe%2FVienna`;

  const res = await fetch(url);

  if (res.status === 429) {
    throw new Error("rate_limited");
  }
  if (!res.ok) {
    throw new Error(`open_meteo_http_${res.status}`);
  }

  return await res.json();
}

function findClosestHourIndex(times: string[], targetIso: string): number {
  const target = new Date(targetIso).getTime();
  let bestIdx = 0;
  let bestDiff = Infinity;
  for (let i = 0; i < times.length; i++) {
    const diff = Math.abs(new Date(times[i]).getTime() - target);
    if (diff < bestDiff) {
      bestDiff = diff;
      bestIdx = i;
    }
  }
  return bestIdx;
}

function extractSnapshot(
  data: OpenMeteoResponse,
  catchTs: string,
  lat: number,
  lng: number,
): WeatherSnapshot | null {
  const hourly = data.hourly;
  if (!hourly || !hourly.time || hourly.time.length === 0) return null;

  const idx = findClosestHourIndex(hourly.time, catchTs);
  const measuredAt = hourly.time[idx] ?? "";

  const moonPhase = data.daily?.moon_phase?.[0] ?? 0;

  return {
    temp_c: Math.round((hourly.temperature_2m[idx] ?? 0) * 10) / 10,
    pressure_hpa: Math.round((hourly.surface_pressure[idx] ?? 0) * 10) / 10,
    wind_kmh: Math.round((hourly.wind_speed_10m[idx] ?? 0) * 10) / 10,
    weather_code: hourly.weather_code[idx] ?? 0,
    weather_text: WMO_WEATHER_TEXT[hourly.weather_code[idx] ?? 0] ?? "unbekannt",
    moon_phase: Math.round(moonPhase * 1000) / 1000,
    moon_text: moonText(moonPhase),
    measured_at: measuredAt,
  };
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const url = new URL(req.url);
  const pathname = url.pathname.replace(/.*\/wetter-hook/, "");
  const isForecast = pathname === "/forecast";

  // GET /forecast — Forecast-Widget-Daten
  if (req.method === "GET" && isForecast) {
    const latStr = url.searchParams.get("lat");
    const lngStr = url.searchParams.get("lng");

    if (!latStr || !lngStr) {
      return new Response(
        JSON.stringify({ error: "missing_lat_lng" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const lat = parseFloat(latStr);
    const lng = parseFloat(lngStr);

    if (
      typeof lat !== "number" || isNaN(lat) ||
      typeof lng !== "number" || isNaN(lng) ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180
    ) {
      return new Response(
        JSON.stringify({ error: "invalid_coordinates" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const cacheKey = makeCacheKey(lat, lng);
    let data: OpenMeteoResponse | null = getCached(cacheKey);

    try {
      if (!data) {
        data = await fetchOpenMeteo(lat, lng);
        setCached(cacheKey, data);
      }

      const hourly = data.hourly;
      if (!hourly || !hourly.time) {
        return new Response(
          JSON.stringify({ error: "no_forecast_data" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const now = Date.now();
      const in24h = now + 24 * 60 * 60 * 1000;
      const moonPhases = data.daily?.moon_phase ?? [];

      const forecast: Array<{
        time: string;
        temp_c: number;
        wind_kmh: number;
        pressure_hpa: number;
        weather_code: number;
        moon_phase: number;
      }> = [];

      for (let i = 0; i < hourly.time.length; i++) {
        const t = new Date(hourly.time[i]).getTime();
        if (t >= now && t <= in24h) {
          const dayIdx = Math.floor(i / 24);
          forecast.push({
            time: hourly.time[i],
            temp_c: Math.round((hourly.temperature_2m[i] ?? 0) * 10) / 10,
            wind_kmh: Math.round((hourly.wind_speed_10m[i] ?? 0) * 10) / 10,
            pressure_hpa: Math.round((hourly.surface_pressure[i] ?? 0) * 10) / 10,
            weather_code: hourly.weather_code[i] ?? 0,
            moon_phase: Math.round((moonPhases[Math.min(dayIdx, moonPhases.length - 1)] ?? 0) * 1000) / 1000,
          });
        }
      }

      return new Response(
        JSON.stringify({ forecast }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    } catch (err) {
      const msg = err instanceof Error ? err.message : "unknown";
      if (msg === "rate_limited") {
        const stale = getStaleCache(cacheKey);
        if (stale) {
          const hourly = stale.hourly;
          const moonPhases = stale.daily?.moon_phase ?? [];
          const now = Date.now();
          const in24h = now + 24 * 60 * 60 * 1000;
          const forecast = [];
          for (let i = 0; i < hourly.time.length; i++) {
            const t = new Date(hourly.time[i]).getTime();
            if (t >= now && t <= in24h) {
              const dayIdx = Math.floor(i / 24);
              forecast.push({
                time: hourly.time[i],
                temp_c: Math.round((hourly.temperature_2m[i] ?? 0) * 10) / 10,
                wind_kmh: Math.round((hourly.wind_speed_10m[i] ?? 0) * 10) / 10,
                pressure_hpa: Math.round((hourly.surface_pressure[i] ?? 0) * 10) / 10,
                weather_code: hourly.weather_code[i] ?? 0,
                moon_phase: Math.round((moonPhases[Math.min(dayIdx, moonPhases.length - 1)] ?? 0) * 1000) / 1000,
              });
            }
          }
          return new Response(
            JSON.stringify({ forecast, cached: true, rate_limited: true }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
        return new Response(
          JSON.stringify({ forecast: [], rate_limited: true }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      return new Response(
        JSON.stringify({ error: "unavailable" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
  }

  // POST — Wetter-Snapshot für Fang
  if (req.method === "POST") {
    let lat: number;
    let lng: number;
    let catchTs: string;

    try {
      const body = await req.json();
      lat = body?.lat;
      lng = body?.lng;
      catchTs = body?.catch_ts;
    } catch {
      return new Response(
        JSON.stringify({ error: "invalid_json" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (
      typeof lat !== "number" || isNaN(lat) || lat < -90 || lat > 90 ||
      typeof lng !== "number" || isNaN(lng) || lng < -180 || lng > 180
    ) {
      return new Response(
        JSON.stringify({ error: "invalid_coordinates" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!catchTs || typeof catchTs !== "string") {
      return new Response(
        JSON.stringify({ error: "missing_catch_ts" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ≤24h-Check
    const catchTime = new Date(catchTs).getTime();
    if (isNaN(catchTime)) {
      return new Response(
        JSON.stringify({ error: "invalid_catch_ts" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const hoursDiff = (Date.now() - catchTime) / (60 * 60 * 1000);
    if (hoursDiff > 24) {
      return new Response(
        JSON.stringify({
          weather: null,
          reason: "older_than_24h",
          message: "Wetter-Auto nur für Fänge der letzten 24h (kostenlose Open-Meteo-API)",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Open-Meteo-Call mit Cache
    const cacheKey = makeCacheKey(lat, lng);
    let data: OpenMeteoResponse | null = getCached(cacheKey);
    let fromCache = !!data;

    try {
      if (!data) {
        data = await fetchOpenMeteo(lat, lng);
        setCached(cacheKey, data);
      }

      const snapshot = extractSnapshot(data!, catchTs, lat, lng);

      return new Response(
        JSON.stringify({ weather: snapshot, cached: fromCache }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    } catch (err) {
      const msg = err instanceof Error ? err.message : "unknown";
      if (msg === "rate_limited") {
        const stale = getStaleCache(cacheKey);
        if (stale) {
          const snapshot = extractSnapshot(stale, catchTs, lat, lng);
          return new Response(
            JSON.stringify({ weather: snapshot, cached: true, rate_limited: true }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
        return new Response(
          JSON.stringify({ weather: null, reason: "rate_limited" }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      return new Response(
        JSON.stringify({ weather: null, reason: "unavailable" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
  }

  return new Response(
    JSON.stringify({ error: "method_not_allowed" }),
    { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});