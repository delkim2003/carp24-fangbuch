import { defineMiddleware } from "astro:middleware";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";
import { getMaintenance } from "./lib/settings";

const securityHeaders: Record<string, string> = {
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "geolocation=(self), camera=(), microphone=(), payment=(), usb=(), screen-wake-lock=()",
};

export const onRequest = defineMiddleware(async (context, next) => {
  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return parseCookieHeader(context.request.headers.get("Cookie") ?? "");
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            context.cookies.set(name, value, options);
          });
        },
      },
      auth: {
        storageKey: 'sb-carp24-auth-token',
      },
      cookieOptions: {
        path: '/',
        sameSite: 'lax',
        secure: context.url.protocol === 'https:',
      },
    }
  );

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
    const sessionResult = await supabase.auth.getSession();
    session = sessionResult.data.session;

    if (user) {
      const { data: profile } = await supabase
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

  const response = await next();

  for (const [key, value] of Object.entries(securityHeaders)) {
    response.headers.set(key, value);
  }

  return response;
});
