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

async function proxyRequest(request: Request, path: string) {
  const url = new URL(request.url);
  const targetUrl = `${SUPABASE_INTERNAL_URL}/auth/v1/${path}${url.search}`;

  const headers = new Headers();
  for (const [key, value] of request.headers.entries()) {
    if (key.toLowerCase() !== "host") {
      headers.set(key, value);
    }
  }

  const response = await fetch(targetUrl, {
    method: request.method,
    headers,
    body: request.method !== "GET" && request.method !== "HEAD" ? await request.text() : undefined,
  });

  const responseHeaders = new Headers();
  for (const [key, value] of response.headers.entries()) {
    if (key.toLowerCase() !== "transfer-encoding") {
      responseHeaders.set(key, value);
    }
  }

  return new Response(await response.text(), {
    status: response.status,
    headers: responseHeaders,
  });
}
