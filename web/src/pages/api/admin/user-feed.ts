import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";

export const prerender = false;

async function guard(request: Request) {
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
  const userId = url.searchParams.get("id");

  if (!userId) {
    return new Response(JSON.stringify({ error: "ID erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("id, display_name, role, is_pro, created_at, deleted_at, banned_at, ban_reason")
    .eq("id", userId)
    .single();

  if (!profile) {
    return new Response(JSON.stringify({ error: "Nutzer nicht gefunden." }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: authUser } = await supabaseAdmin.auth.admin.getUserById(userId);
  const email = authUser?.user?.email ?? "";

  const [
    catchesResult,
    tripsResult,
    badgesResult,
    threadsResult,
    postsResult,
    chatResult,
    marketplaceResult,
    pushCountResult,
    reportsAsReporterResult,
  ] = await Promise.all([
    supabaseAdmin
      .from("catches")
      .select("id, species, weight_kg, water_id, photo_url, created_at, deleted_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(100),
    supabaseAdmin
      .from("trips")
      .select("id, title, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50),
    supabaseAdmin
      .from("user_badges")
      .select("id, badge_id, awarded_at")
      .eq("user_id", userId)
      .order("awarded_at", { ascending: false }),
    supabaseAdmin
      .from("forum_threads")
      .select("id, title, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50),
    supabaseAdmin
      .from("forum_posts")
      .select("id, thread_id, body, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50),
    supabaseAdmin
      .from("chat_messages")
      .select("id, body, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50),
    supabaseAdmin
      .from("marketplace_items")
      .select("id, title, price, status, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50),
    supabaseAdmin
      .from("push_subscriptions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId),
    supabaseAdmin
      .from("content_reports")
      .select("id, target_type, target_id, reason, status, created_at")
      .eq("reporter_id", userId)
      .order("created_at", { ascending: false })
      .limit(50),
  ]);

  const catches = catchesResult.data ?? [];
  const catchIds = catches.map((c: any) => c.id);
  const waterIds = [...new Set(catches.map((c: any) => c.water_id).filter(Boolean))];

  let waterMap = new Map<string, string>();
  if (waterIds.length > 0) {
    const { data: waters } = await supabaseAdmin
      .from("waters")
      .select("id, name")
      .in("id", waterIds);
    waterMap = new Map((waters ?? []).map((w: any) => [w.id, w.name]));
  }

  const enrichedCatches = catches.map((c: any) => ({
    ...c,
    water_name: waterMap.get(c.water_id) ?? "",
  }));

  let reportsAgainst: any[] = [];
  if (catchIds.length > 0) {
    const { data } = await supabaseAdmin
      .from("content_reports")
      .select("id, target_type, target_id, reason, status, created_at, reporter_id")
      .in("target_id", catchIds)
      .neq("reporter_id", userId)
      .order("created_at", { ascending: false })
      .limit(50);
    reportsAgainst = data ?? [];
  }

  const badgeIds = [...new Set((badgesResult.data ?? []).map((b: any) => b.badge_id))];
  let badgeMap = new Map<string, string>();
  if (badgeIds.length > 0) {
    const { data: badgeRows } = await supabaseAdmin
      .from("badges")
      .select("id, name")
      .in("id", badgeIds);
    badgeMap = new Map((badgeRows ?? []).map((b: any) => [b.id, b.name]));
  }

  const enrichedBadges = (badgesResult.data ?? []).map((b: any) => ({
    ...b,
    badge_name: badgeMap.get(b.badge_id) ?? "Unbekannt",
  }));

  return new Response(
    JSON.stringify({
      profile: { ...profile, email },
      catches: enrichedCatches,
      trips: tripsResult.data ?? [],
      badges: enrichedBadges,
      forum_threads: threadsResult.data ?? [],
      forum_posts: postsResult.data ?? [],
      chat_messages: chatResult.data ?? [],
      marketplace_items: marketplaceResult.data ?? [],
      push_subscriptions_count: pushCountResult.count ?? 0,
      reports_as_reporter: reportsAsReporterResult.data ?? [],
      reports_against: reportsAgainst,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
};
