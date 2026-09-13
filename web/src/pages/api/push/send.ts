import { getSupabaseUrl, getSupabaseAnonKey, getSupabaseServiceKey } from "../../../lib/config";
import { createClient } from "@supabase/supabase-js";
import webPush from "web-push";
import { getVapidKeys } from "../../../lib/settings";

export const prerender = false;

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  let user = locals.user;
  if (!user) {
    const authHeader = request.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { createClient } = await import('@supabase/supabase-js');
      const supabaseAdmin = createClient(getSupabaseUrl(), getSupabaseServiceKey());
      const { data: { user: tokenUser } } = await supabaseAdmin.auth.getUser(token);
      if (tokenUser) user = tokenUser;
    }
  }

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseAdmin = createClient(
    getSupabaseUrl(),
    getSupabaseServiceKey()
  );

  const { data: subs, error: fetchError } = await supabaseAdmin
    .from("push_subscriptions")
    .select("endpoint, keys")
    .eq("user_id", user.id);

  if (fetchError || !subs || subs.length === 0) {
    return new Response(JSON.stringify({ error: "Keine Push-Subscriptions gefunden." }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { publicKey: vapidPublicKey, privateKey: vapidPrivateKey, subject: vapidSubject } = await getVapidKeys(supabaseAdmin);

  if (!vapidPrivateKey || !vapidPublicKey) {
    return new Response(JSON.stringify({ error: "VAPID nicht konfiguriert." }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  webPush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

  const payload = JSON.stringify({
    title: "Carp24",
    body: "Push aktiv!",
    icon: "/icons/icon-192.png",
  });

  const results = await Promise.allSettled(
    subs.map((sub: any) =>
      webPush.sendNotification(
        { endpoint: sub.endpoint, keys: sub.keys },
        payload
      )
    )
  );

  const successful = results.filter((r) => r.status === "fulfilled").length;

  return new Response(JSON.stringify({ ok: true, sent: successful, total: subs.length }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};