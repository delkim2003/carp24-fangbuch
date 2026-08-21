import { createServerClient } from "@supabase/ssr";

export const prerender = false;

export const GET = async ({ request }: { request: Request }) => {
  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          const header = request.headers.get("cookie");
          if (!header) return [];
          return header
            .split(";")
            .map((pair) => {
              const idx = pair.indexOf("=");
              if (idx === -1) return null;
              return { name: pair.slice(0, idx).trim(), value: pair.slice(idx + 1).trim() };
            })
            .filter(Boolean) as { name: string; value: string }[];
        },
        setAll() {},
      },
    }
  );

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", session.user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") {
    return new Response(JSON.stringify({ error: "Keine Berechtigung." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      stripe_keys: !!(import.meta.env.STRIPE_SECRET_KEY && import.meta.env.STRIPE_WEBHOOK_SECRET),
      openrouter: !!import.meta.env.OPENROUTER_API_KEY,
      vapid: !!(import.meta.env.VAPID_PUBLIC_KEY && import.meta.env.VAPID_PRIVATE_KEY),
      service_role: !!import.meta.env.SUPABASE_SERVICE_ROLE_KEY,
      smtp: true,
      realtime: !!import.meta.env.PUBLIC_SUPABASE_URL,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
};
