const ALLOWED_ORIGINS = [
  "http://localhost:8094",
  "http://100.93.250.103:8094",
  "http://100.93.250.103:8055",
  "https://carp24.org",
];

export function csrfGuard(request: Request): Response | null {
  const origin = request.headers.get("origin") || request.headers.get("referer");
  // Kein Origin = same-site Request (Browser-Form-Submit) → erlaubt
  // SameSite=Strict Cookies schützen bereits vor CSRF
  if (!origin) {
    return null;
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