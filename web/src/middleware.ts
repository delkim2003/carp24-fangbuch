import { defineMiddleware } from "astro:middleware";
import { createSSRClient, createServiceClient } from "./lib/ssr-client";
import { getMaintenance } from "./lib/settings";

const securityHeaders: Record<string, string> = {
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "geolocation=(self), camera=(), microphone=(), payment=(), usb=(), screen-wake-lock=()",
  "Content-Security-Policy": [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://challenges.cloudflare.com https://cdn.jsdelivr.net",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "img-src 'self' data: https:",
    "font-src 'self' data: https://fonts.gstatic.com",
    "connect-src 'self' https://api.open-meteo.com https://openrouter.ai wss:",
    "frame-src https://challenges.cloudflare.com",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join("; "),
};

export const onRequest = defineMiddleware(async (context, next) => {
  const supabase = createSSRClient(context);

  // CRITICAL: getUser() validates JWT against Auth server AND refreshes tokens
  // getSession() only reads cookie — stale tokens cause redirect loops
  // P1-1: try/catch — bei DB/Netzwerk-Fehler App nicht crashen
  let user = null;
  let session = null;
  let role = "USER";
  let isPro = false;

  try {
    const authResult = await supabase.auth.getUser();
    user = authResult.data.user;
    // T1: getSession() removed — getUser() validates JWT already

    if (user) {
      const adminSb = createServiceClient();
      const { data: profile } = await adminSb
        .from("profiles")
        .select("role, is_pro")
        .eq("id", user.id)
        .single();
      role = profile?.role ?? "USER";
      isPro = profile?.is_pro ?? false;
    }
  } catch (err) {
    // Auth/DB fehlgeschlagen — App läuft ohne User weiter
    console.error("[middleware] Auth/Profile-Query fehlgeschlagen:", err);
    user = null;
    session = null;
    role = "USER";
    isPro = false;
  }

  context.locals.user = user;
  context.locals.session = session;
  context.locals.role = role;
  context.locals.isPro = isPro;
  context.locals.isAdmin = role === "ADMIN" || role === "MODERATOR";

  let maintenance = { enabled: false, message: "" };
  try {
    maintenance = await getMaintenance();
  } catch (err) {
    console.error("[middleware] Maintenance-Query fehlgeschlagen:", err);
  }
  const path = context.url.pathname.replace(/\/+$/, "") || "/";
  const isAdmin = role === "ADMIN" || role === "MODERATOR";

  if (maintenance.enabled && !isAdmin) {
    if (path.startsWith("/api/")) {
      return new Response(JSON.stringify({ error: "Wartungsarbeiten" }), {
        status: 503,
        headers: { "Content-Type": "application/json", ...securityHeaders },
      });
    }
    const isAllowed =
      path === "/login" ||
      path === "/wartung" ||
      path === "/impressum" ||
      path === "/datenschutz" ||
      path === "/404" ||
      path === "/offline";
    if (!path.startsWith("/admin") && !isAllowed) {
      return context.redirect("/wartung");
    }
  }

  // CSRF: Origin-Check für state-changing Requests (POST/PUT/DELETE/PATCH)
  // Ausnahmen: Auth-Routen (haben eigenen Schutz), Stripe-Webhook (Signature-Check), Supabase-Proxy (intern)
  const method = context.request.method;
  if (["POST", "PUT", "DELETE", "PATCH"].includes(method)) {
    const skipPaths = ["/api/auth/", "/api/stripe/webhook", "/supabase/"];
    const shouldCheck = !skipPaths.some(p => path.startsWith(p));
    if (shouldCheck) {
      const origin = context.request.headers.get("origin") || context.request.headers.get("referer") || "";
      const allowed = ["https://carp24.org", "http://localhost:8094", "http://100.93.250.103:8094"];
      const originOk = allowed.some(a => origin.startsWith(a));
      if (!originOk && origin !== "") {
        // Origin vorhanden aber nicht erlaubt → blockieren
        return new Response(JSON.stringify({ error: "CSRF check failed" }), {
          status: 403,
          headers: { "Content-Type": "application/json", ...securityHeaders },
        });
      }
      // Kein Origin = Browser-Form-Submit oder gleicher-Origin → erlauben (SameSite=Cookies schützen)
    }
  }

  const response = await next();

  for (const [key, value] of Object.entries(securityHeaders)) {
    response.headers.set(key, value);
  }

  // Cache-Header: Static Assets = 1 Jahr, HTML = no-cache, API = no-store
  const url = context.url.pathname;
  if (url.match(/\.(css|js|woff2?|ttf|eot|svg|png|jpg|jpeg|webp|gif|ico)(\?|$)/)) {
    response.headers.set("Cache-Control", "public, max-age=31536000, immutable");
  } else if (url.startsWith("/api/")) {
    response.headers.set("Cache-Control", "no-store");
  } else {
    response.headers.set("Cache-Control", "no-cache, must-revalidate");
  }

  return response;
});
