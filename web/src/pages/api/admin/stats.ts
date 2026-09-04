import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { parseCookieHeader } from "@supabase/ssr";

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
        secure: false,
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

  const [
    users,
    catches,
    reports,
    threads,
    posts,
    messages,
    items,
    trips,
    proUsers,
    bannedUsers,
    openReports,
    marketContacts,
  ] = await Promise.all([
    supabaseAdmin.from("profiles").select("id", { count: "exact", head: true }).is("deleted_at", null),
    supabaseAdmin.from("catches").select("id", { count: "exact", head: true }).is("deleted_at", null),
    supabaseAdmin.from("content_reports").select("id", { count: "exact", head: true }).eq("status", "open"),
    supabaseAdmin.from("forum_threads").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("forum_posts").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("chat_messages").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("marketplace_items").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("trips").select("id", { count: "exact", head: true }),
    supabaseAdmin.from("profiles").select("id", { count: "exact", head: true }).eq("is_pro", true).is("banned_at", null),
    supabaseAdmin.from("profiles").select("id", { count: "exact", head: true }).not("banned_at", "is", null),
    supabaseAdmin.from("content_reports").select("id", { count: "exact", head: true }).eq("status", "open"),
    supabaseAdmin.from("marketplace_contacts").select("id", { count: "exact", head: true }),
  ]);

  const now = new Date();
  const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000).toISOString();

  const [signupsByDay, catchesByDay, stripeEvents] = await Promise.all([
    supabaseAdmin
      .from("profiles")
      .select("created_at")
      .gte("created_at", fourteenDaysAgo)
      .order("created_at", { ascending: true }),
    supabaseAdmin
      .from("catches")
      .select("created_at")
      .gte("created_at", fourteenDaysAgo)
      .is("deleted_at", null)
      .order("created_at", { ascending: true }),
    supabaseAdmin
      .from("stripe_events")
      .select("type, status"),
  ]);

  function groupByDay(rows: any[]): Record<string, number> {
    const result: Record<string, number> = {};
    for (let i = 13; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      const key = d.toISOString().slice(0, 10);
      result[key] = 0;
    }
    for (const row of rows ?? []) {
      const key = (row.created_at ?? "").slice(0, 10);
      if (key in result) result[key]++;
    }
    return result;
  }

  const userSignupsByDay = groupByDay(signupsByDay.data ?? []);
  const catchesByDayData = groupByDay(catchesByDay.data ?? []);

  const typeCount: Record<string, number> = {};
  const statusCount: Record<string, number> = {};
  for (const ev of stripeEvents.data ?? []) {
    typeCount[ev.type] = (typeCount[ev.type] || 0) + 1;
    statusCount[ev.status] = (statusCount[ev.status] || 0) + 1;
  }
  const topTypes = Object.entries(typeCount)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5)
    .map(([type, count]) => ({ type, count }));

  return new Response(
    JSON.stringify({
      stats: {
        users: users.count ?? 0,
        catches: catches.count ?? 0,
        openReports: openReports.count ?? 0,
        forumThreads: threads.count ?? 0,
        forumPosts: posts.count ?? 0,
        chatMessages: messages.count ?? 0,
        marketplaceItems: items.count ?? 0,
        trips: trips.count ?? 0,
        proUsers: proUsers.count ?? 0,
        bannedUsers: bannedUsers.count ?? 0,
        marketContacts: marketContacts.count ?? 0,
      },
      growth: {
        userSignupsByDay,
        catchesByDay: catchesByDayData,
      },
      stripeEvents: {
        topTypes,
        statusDistribution: statusCount,
      },
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
};
