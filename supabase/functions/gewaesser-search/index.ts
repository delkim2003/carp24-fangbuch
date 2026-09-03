// Gewässer-Suche via Photon (komoot) — carp24 Task 1.5
// Supabase Edge Function (Deno.serve — native Edge-Runtime-Pattern)
// Filtert OSM water/lake/river — wir suchen Gewässer, kein Straßen

interface PhotonResult {
  name: string;
  lat: number;
  lng: number;
  type: string;
}

interface CacheEntry {
  data: PhotonResult[];
  timestamp: number;
}

const CACHE_TTL_MS = 60 * 60 * 1000; // 1 Stunde
const cache = new Map<string, CacheEntry>();

const WATER_OSM_VALUES = new Set(["water", "lake", "river", "reservoir", "pond", "stream"]);

const corsHeaders = {
  "Access-Control-Allow-Origin": "http://100.93.250.103:8094",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey, x-client-info",
};

function getCached(query: string): PhotonResult[] | null {
  const entry = cache.get(query);
  if (!entry) return null;
  if (Date.now() - entry.timestamp > CACHE_TTL_MS) {
    cache.delete(query);
    return null;
  }
  return entry.data;
}

function setCached(query: string, data: PhotonResult[]): void {
  cache.set(query, { data, timestamp: Date.now() });
}

async function queryPhoton(query: string, limit: number): Promise<PhotonResult[]> {
  const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&lang=de&limit=${limit}`;
  const res = await fetch(url, {
    headers: { "User-Agent": "carp24-gewaesser-suche/1.0" },
  });

  if (res.status === 429) {
    throw new Error("rate_limited");
  }
  if (!res.ok) {
    throw new Error(`photon_http_${res.status}`);
  }

  const data = await res.json();
  const features: any[] = data?.features ?? [];

  return features
    .filter((f) => {
      const osmKey = f?.properties?.osm_key;
      const osmValue = f?.properties?.osm_value;
      return osmKey === "water" || WATER_OSM_VALUES.has(osmValue ?? "");
    })
    .map((f) => {
      const coords = f?.geometry?.coordinates ?? [0, 0]; // Photon: [lng, lat]
      return {
        name: f?.properties?.name ?? "Unbekannt",
        lat: typeof coords[1] === "number" ? coords[1] : 0,
        lng: typeof coords[0] === "number" ? coords[0] : 0,
        type: f?.properties?.osm_value ?? "water",
      };
    })
    .slice(0, limit);
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Query aus GET ?q= oder POST JSON {q, limit}
  let query = "";
  let limit = 5;
  const url = new URL(req.url);

  if (req.method === "GET") {
    query = url.searchParams.get("q") ?? "";
    limit = parseInt(url.searchParams.get("limit") ?? "5", 10);
  } else if (req.method === "POST") {
    try {
      const body = await req.json();
      query = body?.q ?? "";
      limit = body?.limit ?? 5;
    } catch {
      query = "";
    }
  }

  if (!query || query.trim().length < 2) {
    return new Response(
      JSON.stringify({ results: [], error: "query_too_short" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const cacheKey = `${query}:${limit}`;
  const cached = getCached(cacheKey);
  if (cached) {
    return new Response(
      JSON.stringify({ results: cached, cached: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    const results = await queryPhoton(query.trim(), limit);
    setCached(cacheKey, results);
    return new Response(
      JSON.stringify({ results, cached: false }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const msg = err instanceof Error ? err.message : "unknown";
    if (msg === "rate_limited") {
      // Fallback: evtl. veraltete Cache-Antwort (auch wenn TTL abgelaufen)
      const stale = cache.get(cacheKey);
      if (stale) {
        return new Response(
          JSON.stringify({ results: stale.data, cached: true, rate_limited: true }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      return new Response(
        JSON.stringify({ results: [], rate_limited: true }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    return new Response(
      JSON.stringify({ results: [], error: "geocoding_unavailable" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
