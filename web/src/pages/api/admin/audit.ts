import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { parseCookieHeader } from "@supabase/ssr";

export const prerender = false;

async function guard(request: Request) {
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
        secure: false,
      },
    },
  );

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) return { error: "Nicht angemeldet.", status: 401 };

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", session.user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") return { error: "Keine Berechtigung.", status: 403 };

  const supabaseAdmin = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY
  );

  return { supabaseAdmin, session };
}

export const GET = async ({ request }: { request: Request }) => {
  const g = await guard(request);
  if ("error" in g) {
    return new Response(JSON.stringify({ error: g.error }), {
      status: g.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { supabaseAdmin } = g;
  const url = new URL(request.url);
  const limit = Math.min(parseInt(url.searchParams.get("limit") || "100", 10), 500);
  const page = Math.max(parseInt(url.searchParams.get("page") || "1", 10), 1);

  const from = (page - 1) * limit;
  const to = from + limit - 1;

  // Count total rows first
  const { count: total, error: countError } = await supabaseAdmin
    .from("admin_audit_log")
    .select("*", { count: "exact", head: true });

  if (countError) {
    return new Response(JSON.stringify({ error: countError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Fetch paginated data
  const { data: logs, error } = await supabaseAdmin
    .from("admin_audit_log")
    .select("id, actor_id, action, target_type, target_id, details, created_at")
    .order("created_at", { ascending: false })
    .range(from, to);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const totalPages = Math.ceil((total ?? 0) / limit);

  const actorIds = [...new Set((logs ?? []).map((l: any) => l.actor_id).filter(Boolean))];
  let actorMap = new Map<string, string>();
  if (actorIds.length > 0) {
    const { data: actors } = await supabaseAdmin
      .from("profiles")
      .select("id, display_name")
      .in("id", actorIds);
    actorMap = new Map((actors ?? []).map((a: any) => [a.id, a.display_name]));
  }

  const enriched = (logs ?? []).map((l: any) => ({
    ...l,
    actor_name: actorMap.get(l.actor_id) ?? "Unbekannt",
  }));

  return new Response(JSON.stringify({ logs: enriched, pagination: { page, limit, total: total ?? 0, totalPages } }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};