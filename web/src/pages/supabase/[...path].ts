export const prerender = false;

const SUPABASE_INTERNAL_URL = "http://100.93.250.103:8055";

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

async function proxyRequest(request: Request, path: string) {
  const url = new URL(request.url);
  const targetUrl = `${SUPABASE_INTERNAL_URL}/${path}${url.search}`;

  const headers = new Headers();
  for (const [key, value] of request.headers.entries()) {
    const lk = key.toLowerCase();
    if (lk !== "host" && lk !== "origin" && lk !== "referer") {
      headers.set(key, value);
    }
  }

  const body = request.method !== "GET" && request.method !== "HEAD"
    ? await request.text()
    : undefined;

  const response = await fetch(targetUrl, {
    method: request.method,
    headers,
    body,
  });

  const responseHeaders = new Headers();
  for (const [key, value] of response.headers.entries()) {
    const lk = key.toLowerCase();
    if (lk !== "transfer-encoding") {
      responseHeaders.set(key, value);
    }
  }
  // CORS für Browser-Zugriff
  responseHeaders.set("Access-Control-Allow-Origin", url.origin);
  responseHeaders.set("Access-Control-Allow-Credentials", "true");

  return new Response(await response.text(), {
    status: response.status,
    headers: responseHeaders,
  });
}
