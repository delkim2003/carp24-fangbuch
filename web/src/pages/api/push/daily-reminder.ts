import { createClient } from "@supabase/supabase-js";
import webPush from "web-push";

export const prerender = false;

export const POST = async ({ request }: { request: Request }) => {
  const cronKey = import.meta.env.CRON_KEY;
  if (!cronKey) {
    return new Response(JSON.stringify({ error: "Cron nicht konfiguriert." }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  const providedKey = request.headers.get("x-cron-key");
  if (providedKey !== cronKey) {
    return new Response(JSON.stringify({ error: "Unauthorized." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const vapidPublicKey = import.meta.env.VAPID_PUBLIC_KEY;
  const vapidPrivateKey = import.meta.env.VAPID_PRIVATE_KEY;
  const vapidSubject = import.meta.env.VAPID_SUBJECT || "mailto:info@carp24.at";

  if (!vapidPrivateKey || !vapidPublicKey) {
    return new Response(JSON.stringify({ error: "Push ist noch nicht konfiguriert." }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseAdmin = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY
  );

  const { data: subs } = await supabaseAdmin
    .from("push_subscriptions")
    .select("user_id, endpoint, keys")
    .not("user_id", "is", null);

  if (!subs || subs.length === 0) {
    return new Response(JSON.stringify({ sent: 0, skipped: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  webPush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  let sent = 0;
  let skipped = 0;

  const userMap = new Map<string, typeof subs>();
  for (const sub of subs) {
    const list = userMap.get(sub.user_id) || [];
    list.push(sub);
    userMap.set(sub.user_id, list);
  }

  for (const [userId, userSubs] of userMap) {
    const { data: lastCatch } = await supabaseAdmin
      .from("catches")
      .select("catch_ts")
      .eq("user_id", userId)
      .is("deleted_at", null)
      .order("catch_ts", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!lastCatch || lastCatch.catch_ts < sevenDaysAgo) {
      const payload = JSON.stringify({
        title: "Zeit für einen neuen Fang!",
        body: "Dein letzter Fang ist über eine Woche her. Schnapp dir deine Rute!",
        url: "/fang-erfassen",
      });

      for (const sub of userSubs) {
        try {
          await webPush.sendNotification(
            { endpoint: sub.endpoint, keys: sub.keys },
            payload
          );
          sent++;
        } catch (err: any) {
          if (err?.statusCode === 410) {
            await supabaseAdmin.from("push_subscriptions").delete().eq("endpoint", sub.endpoint);
          }
        }
      }
    } else {
      skipped += userSubs.length;
    }
  }

  return new Response(JSON.stringify({ sent, skipped }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
