import { getAdminClient } from "./_auth";

export const prerender = false;

export const GET = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const auth = await getAdminClient(locals);
  if ("error" in auth) {
    return new Response(JSON.stringify({ error: auth.error }), {
      status: auth.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { supabaseAdmin } = auth;
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
      .select("id, species, weight_kg, water_id, photos, created_at, deleted_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(100),
    supabaseAdmin
      .from("trips")
      .select("id, name, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50),
    supabaseAdmin
      .from("user_badges")
      .select("badge_id, earned_at")
      .eq("user_id", userId)
      .order("earned_at", { ascending: false }),
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
    photo: c.photos?.[0] || null,
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
    badge_id: b.badge_id,
    awarded_at: b.earned_at,
    badge_name: badgeMap.get(b.badge_id) ?? "Unbekannt",
  }));

  return new Response(
    JSON.stringify({
      profile: { ...profile, email },
      catches: enrichedCatches,
      trips: (tripsResult.data ?? []).map((t: any) => ({ ...t, title: t.name })),
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