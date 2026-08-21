import { createServerClient } from "@supabase/ssr";
import webPush from "web-push";

export const prerender = false;

export const POST = async ({ request, cookies }) => {
  const vapidPublicKey = import.meta.env.VAPID_PUBLIC_KEY;
  const vapidPrivateKey = import.meta.env.VAPID_PRIVATE_KEY;
  const vapidSubject = import.meta.env.VAPID_SUBJECT || "mailto:info@carp24.at";

  if (!vapidPrivateKey || !vapidPublicKey) {
    return new Response(JSON.stringify({ error: "VAPID nicht konfiguriert." }), {
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
          cookiesToSet.forEach(({ name, value, options }) => {
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

  const { data: subs, error: fetchError } = await supabase
    .from("push_subscriptions")
    .select("endpoint, keys")
    .eq("user_id", session.user.id);

  if (fetchError || !subs || subs.length === 0) {
    return new Response(JSON.stringify({ error: "Keine Push-Subscriptions gefunden." }), {
      status: 404,
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