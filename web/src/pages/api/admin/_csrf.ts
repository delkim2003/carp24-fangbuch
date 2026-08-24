const ALLOWED_ORIGINS = [
  "http://100.93.250.103:8094",
  "http://100.93.250.103:8055",
];

export function csrfGuard(request: Request): Response | null {
  const origin = request.headers.get("origin") || request.headers.get("referer") || "";
  if (origin && !ALLOWED_ORIGINS.some((a) => origin.startsWith(a))) {
    return new Response(JSON.stringify({ error: "CSRF" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  return null;
}
