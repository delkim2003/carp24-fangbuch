import { createServerClient } from "@supabase/ssr";
import { parseCookieHeader } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";

export const prerender = false;

export const GET = async ({ request }: { request: Request }) => {
  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return parseCookieHeader(request.headers.get("Cookie") ?? "");
        },
        setAll() {},
      },
      auth: {
        storageKey: 'sb-carp24-auth-token',
      },
      cookieOptions: {
        path: '/',
        sameSite: 'lax',
        secure: true,
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") {
    return new Response(JSON.stringify({ error: "Keine Berechtigung." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Check OpenRouter key: env first, then DB
  let openrouter = !!import.meta.env.OPENROUTER_API_KEY;

  if (!openrouter) {
    try {
      const supabaseAdmin = createClient(
        import.meta.env.PUBLIC_SUPABASE_URL,
        import.meta.env.SUPABASE_SERVICE_ROLE_KEY
      );
      const { data } = await supabaseAdmin
        .from("app_settings")
        .select("value")
        .eq("key", "openrouter_key")
        .single();
      openrouter = !!(data?.value?.key);
    } catch {
      openrouter = false;
    }
  }

  return new Response(
    JSON.stringify({
      stripe_keys: !!(import.meta.env.STRIPE_SECRET_KEY && import.meta.env.STRIPE_WEBHOOK_SECRET),
      openrouter,
      vapid: !!(import.meta.env.VAPID_PUBLIC_KEY && import.meta.env.VAPID_PRIVATE_KEY),
      service_role: !!import.meta.env.SUPABASE_SERVICE_ROLE_KEY,
      smtp: true,
      realtime: !!import.meta.env.PUBLIC_SUPABASE_URL,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
};