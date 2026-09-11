export const prerender = false;

const SUPABASE_INTERNAL_URL = "http://supabase-kong:8000";

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

  let body: string | undefined;
  if (request.method !== "GET" && request.method !== "HEAD") {
    try {
      body = await request.text();
    } catch (e) {
      console.error("[SUPA-PROXY] body read failed:", e);
    }
  }

  try {
    const response = await fetch(targetUrl, {
      method: request.method,
      headers,
      body: body || undefined,
    });

    const responseHeaders = new Headers();
    for (const [key, value] of response.headers.entries()) {
      if (!SKIP_HEADERS.has(key.toLowerCase())) {
        responseHeaders.set(key, value);
      }
    }
    responseHeaders.set("Access-Control-Allow-Origin", url.origin);
    responseHeaders.set("Access-Control-Allow-Credentials", "true");

    return new Response(await response.text(), {
      status: response.status,
      headers: responseHeaders,
    });
  } catch (err: any) {
    console.error("[SUPA-PROXY] Error:", err?.message, "cause:", err?.cause?.code);
    return new Response(JSON.stringify({ error: "Proxy error", detail: err?.message }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }
}
