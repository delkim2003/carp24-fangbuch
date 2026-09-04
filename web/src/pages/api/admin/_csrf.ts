const ALLOWED_ORIGINS = [
  "http://localhost:8094",
  "http://100.93.250.103:8094",
  "http://100.93.250.103:8055",
];

export function csrfGuard(request: Request): Response | null {
  const origin = request.headers.get("origin") || request.headers.get("referer");
  if (!origin) {
    return new Response(JSON.stringify({ error: "CSRF check failed" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  const normalizedOrigin = origin.replace(/\/+$/, "");
  if (
    !ALLOWED_ORIGINS.some(
      (a) => normalizedOrigin === a || normalizedOrigin === a + "/"
    )
  ) {
    return new Response(JSON.stringify({ error: "CSRF check failed" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  return null;
}