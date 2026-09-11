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

const SKIP_HEADERS = new Set(["host", "origin", "referer", "connection", "transfer-encoding"]);

async function proxyRequest(request: Request, path: string) {
  const url = new URL(request.url);
  const targetUrl = `${SUPABASE_INTERNAL_URL}/auth/v1/${path}${url.search}`;

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
    headers.set("authorization", `Bearer ${anonKey}`);
  }

  let body: string | undefined;
  if (request.method !== "GET" && request.method !== "HEAD") {
    body = await request.text();
  }

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

  return new Response(await response.text(), {
    status: response.status,
    headers: responseHeaders,
  });
}
