import { defineMiddleware } from "astro:middleware";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";
import { getMaintenance } from "./lib/settings";

const securityHeaders: Record<string, string> = {
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "geolocation=(self), camera=(), microphone=(), notifications=(), payment=(), usb=(), screen-wake-lock=()",
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
        secure: false,
      },
    }
  );

  const { data: { session } } = await supabase.auth.getSession();
  let role = "USER";
  if (session) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", session.user.id)
      .single();
    role = profile?.role ?? "USER";
  }

  console.log("[MIDDLEWARE] Path:", context.url.pathname, "Session:", session ? "found" : "null", "Role:", role);

  context.locals.session = session;
  context.locals.role = role;
  context.locals.isAdmin = role === "ADMIN" || role === "MODERATOR";

  const maintenance = await getMaintenance(supabase);
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
