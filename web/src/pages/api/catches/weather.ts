import { createServerClient, parseCookieHeader } from "@supabase/ssr";

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
    return {
      temperature_2m: current.temperature_2m,
      relative_humidity_2m: current.relative_humidity_2m,
      weather_code: current.weather_code,
      wind_speed_10m: current.wind_speed_10m,
      pressure_msl: current.pressure_msl,
      time: current.time,
      units: data?.current_units ?? {},
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

  const { data: profile } = await supabase
    .from("profiles")
    .select("is_pro")
    .eq("id", user.id)
    .single();

  if (!profile?.is_pro) {
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

  // Verify the catch belongs to this user
  const { data: catchRow, error: fetchError } = await supabase
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

  // Update the catch record
  const { error: updateError } = await supabase
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