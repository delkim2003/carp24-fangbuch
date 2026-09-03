import { defineMiddleware } from "astro:middleware";
import { createServerClient } from "@supabase/ssr";
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
          const header = context.request.headers.get("cookie");
          if (!header) return [];
          return header
            .split(";")
            .map((pair) => {
              const idx = pair.indexOf("=");
              if (idx === -1) return null;
              return {
                name: pair.slice(0, idx).trim(),
                value: pair.slice(idx + 1).trim(),
              };
            })
            .filter(Boolean) as { name: string; value: string }[];
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