import { createServerClient } from "@supabase/ssr";
import webPush from "web-push";

export const prerender = false;

export const POST = async ({ request, cookies }: { request: Request; cookies: any }) => {
  const vapidPublicKey = import.meta.env.VAPID_PUBLIC_KEY;
  const vapidPrivateKey = import.meta.env.VAPID_PRIVATE_KEY;
  const vapidSubject = import.meta.env.VAPID_SUBJECT || "mailto:info@carp24.at";

  if (!vapidPrivateKey || !vapidPublicKey) {
    return new Response(JSON.stringify({ error: "Push ist noch nicht konfiguriert." }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

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
              return {
                name: pair.slice(0, idx).trim(),
                value: pair.slice(idx + 1).trim(),
              };
            })
            .filter(Boolean) as { name: string; value: string }[];
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }: any) => {
            cookies.set(name, value, options);
          });
        },
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

  const { data: thread, error: threadError } = await supabase
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

  if (ownerId === session.user.id) {
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
        await supabase.from("push_subscriptions").delete().eq("endpoint", sub.endpoint);
      }
    }
  }

  return new Response(JSON.stringify({ sent }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
