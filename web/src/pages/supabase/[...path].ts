export const prerender = false;

// Nutze SUPABASE_URL (extern für Dev) oder PUBLIC_SUPABASE_URL (intern für Docker)
const SUPABASE_INTERNAL_URL = process.env.SUPABASE_URL || process.env.PUBLIC_SUPABASE_URL || "http://supabase-kong:8000";

export async function GET({ request, params }: { request: Request; params: { path: string } }) {
  return proxyRequest(request, params.path);
}
export async function POST({ request, params }: { request: Request; params: { path: string } }) {
  return proxyRequest(request, params.path);
}
export async function PUT({ request, params }: { request: Request; params: { path: string } }) {
  return proxyRequest(request, params.path);
}
export async function DELETE({ request, params }: { request: Request; params: { path: string } }) {
  return proxyRequest(request, params.path);
}
export async function PATCH({ request, params }: { request: Request; params: { path: string } }) {
  return proxyRequest(request, params.path);
}

const SKIP_HEADERS = new Set(["host", "origin", "referer", "connection", "transfer-encoding"]);

async function proxyRequest(request: Request, path: string) {
  const url = new URL(request.url);
  const targetUrl = `${SUPABASE_INTERNAL_URL}/${path}${url.search}`;

  const headers = new Headers();
  for (const [key, value] of request.headers.entries()) {
    if (!SKIP_HEADERS.has(key.toLowerCase())) {
      headers.set(key, value);
    }
  }

  const anonKey = process.env.PUBLIC_SUPABASE_ANON_KEY || "";
  if (anonKey && !headers.has("apikey")) {
    headers.set("apikey", anonKey);
  }
  if (anonKey && !headers.has("authorization")) {
    headers.set("authorization", "Bearer " + anonKey);
  }

  let body: ArrayBuffer | undefined;
  if (request.method !== "GET" && request.method !== "HEAD") {
    try { body = await request.arrayBuffer(); } catch {}
  }

  try {
    const response = await fetch(targetUrl, {
      method: request.method,
      headers,
      body: body || undefined,
      redirect: "manual", // NICHT intern folgen — Redirect an Browser weiterleiten
    });

    const responseHeaders = new Headers();
    for (const [key, value] of response.headers.entries()) {
      if (!SKIP_HEADERS.has(key.toLowerCase())) {
        responseHeaders.set(key, value);
      }
    }
    responseHeaders.set("Access-Control-Allow-Origin", url.origin);
    responseHeaders.set("Access-Control-Allow-Credentials", "true");

    // Redirect-Location anpassen: absolut → relativ zur Domain
    const location = responseHeaders.get("location");
    if (location) {
      try {
        const locUrl = new URL(location);
        // Supabase redirectet auf interne URL → auf externe Domain umschreiben
        responseHeaders.set("location", locUrl.pathname + locUrl.search);
      } catch {
        // Bereits relativ — ok
      }
    }

    const isBodyless = response.status === 204 || response.status === 205 || response.status === 304;
    const responseBody = isBodyless ? null : await response.text();

    return new Response(responseBody, {
      status: response.status,
      headers: responseHeaders,
    });
  } catch (err: any) {
    console.error("[SUPA-PROXY] Error:", err?.message);
    return new Response(JSON.stringify({ error: "Proxy error" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }
}
