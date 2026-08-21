import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";

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

  const supabaseAdmin = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY
  );

  const [users, catches, reports, threads, posts, messages, items, trips] = await Promise.all([
    supabaseAdmin.from("profiles").select("id", { count: "exact", head: true }).is("deleted_at", null),
    supabaseAdmin.from("catches").select("id", { count: "exact", head: true }).is("deleted_at", null),
    supabaseAdmin.from("content_reports").select("id", { count: "exact", head: true }).eq("status", "open"),
    supabaseAdmin.from("forum_threads").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("forum_posts").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("chat_messages").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("marketplace_items").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("trips").select("id", { count: "exact", head: true }),
  ]);

  return new Response(
    JSON.stringify({
      stats: {
        users: users.count ?? 0,
        catches: catches.count ?? 0,
        openReports: reports.count ?? 0,
        forumThreads: threads.count ?? 0,
        forumPosts: posts.count ?? 0,
        chatMessages: messages.count ?? 0,
        marketplaceItems: items.count ?? 0,
        trips: trips.count ?? 0,
      },
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
};
