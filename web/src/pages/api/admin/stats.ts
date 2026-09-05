import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { parseCookieHeader } from "@supabase/ssr";
import Stripe from "stripe";

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
    }
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
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

  const [signupsByDay, catchesByDay, stripeEvents, activeSubs, totalSubs, conversionUsers, recentCancellations] = await Promise.all([
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
    supabaseAdmin
      .from("subscriptions")
      .select("id", { count: "exact", head: true })
      .eq("status", "ACTIVE"),
    supabaseAdmin
      .from("subscriptions")
      .select("id", { count: "exact", head: true }),
    supabaseAdmin
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("is_pro", true),
    supabaseAdmin
      .from("stripe_events")
      .select("id", { count: "exact", head: true })
      .eq("type", "customer.subscription.deleted")
      .gte("created_at", thirtyDaysAgo),
  ]);

  const activeSubCount = activeSubs.count ?? 0;
  const churnCount = recentCancellations.count ?? 0;
  const conversionUserCount = conversionUsers.count ?? 0;
  const totalUserCount = users.count ?? 0;

  // MRR via Stripe
  let mrr = 0;
  try {
    const secretKey = import.meta.env.STRIPE_SECRET_KEY;
    const priceId = import.meta.env.STRIPE_PRICE_ID;
    if (secretKey && priceId) {
      const stripe = new Stripe(secretKey, { apiVersion: "2025-02-24.acacia" });
      const price = await stripe.prices.retrieve(priceId);
      const unitAmount = price.unit_amount ?? 0;
      mrr = (activeSubCount * unitAmount) / 100;
    }
  } catch {
    // Stripe not configured
  }

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

  const churnRate = activeSubCount > 0 ? (churnCount / activeSubCount) * 100 : 0;
  const conversionRate = totalUserCount > 0 ? (conversionUserCount / totalUserCount) * 100 : 0;

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
      revenue: {
        mrr,
        activeSubscribers: activeSubCount,
        churnRate,
        conversionRate,
        conversionUsers: conversionUserCount,
      },
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
};