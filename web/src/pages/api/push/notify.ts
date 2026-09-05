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
      const supabaseAdmin = createClient(import.meta.env.PUBLIC_SUPABASE_URL, import.meta.env.SUPABASE_SERVICE_ROLE_KEY);
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
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY
  );

  let body: any;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültiger Body." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { type, thread_id } = body;

  if (type !== "forum_reply") {
    return new Response(JSON.stringify({ error: "Unbekannter Typ." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!thread_id || typeof thread_id !== "string") {
    return new Response(JSON.stringify({ error: "thread_id fehlt." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: thread, error: threadError } = await supabaseAdmin
    .from("forum_threads")
    .select("user_id")
    .eq("id", thread_id)
    .single();

  if (threadError || !thread) {
    return new Response(JSON.stringify({ error: "Thread nicht gefunden." }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const ownerId = thread.user_id;

  if (ownerId === user.id) {
    return new Response(JSON.stringify({ sent: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: subs } = await supabase
    .from("push_subscriptions")
    .select("endpoint, keys")
    .eq("user_id", ownerId);

  if (!subs || subs.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { publicKey: vapidPublicKey, privateKey: vapidPrivateKey, subject: vapidSubject } = await getVapidKeys(supabaseAdmin);

  if (!vapidPrivateKey || !vapidPublicKey) {
    return new Response(JSON.stringify({ error: "Push ist noch nicht konfiguriert." }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  webPush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

  const payload = JSON.stringify({
    title: "Neue Antwort",
    body: "Jemand hat auf deinen Thread geantwortet.",
    url: "/forum/" + thread_id,
  });

  let sent = 0;

  for (const sub of subs) {
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

  return new Response(JSON.stringify({ sent }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
