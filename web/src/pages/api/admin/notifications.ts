import { createClient } from "@supabase/supabase-js";
import webPush from "web-push";
import { csrfGuard } from "./_csrf";

export const prerender = false;

export async function getServerSideProps({ locals }: { locals: App.Locals }) {
  const user = locals.user;
  if (!user) return { props: { error: "Nicht angemeldet.", status: 401 } };

  const supabaseAdmin = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY
  );

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") return { props: { error: "Keine Berechtigung.", status: 403 } };

  return { props: { supabaseAdmin, user, actorRole: role } };
}

async function writeAudit(supabaseAdmin: any, actorId: string, action: string, targetType: string, targetId: string, details: any) {
  await supabaseAdmin.from("admin_audit_log").insert({
    actor_id: actorId,
    action,
    target_type: targetType,
    target_id: targetId,
    details,
  });
}

export const GET = async ({ locals }: { locals: App.Locals }) => {
  const { supabaseAdmin } = await getServerSideProps({ locals });
  if ("error" in supabaseAdmin) {
    return new Response(JSON.stringify({ error: supabaseAdmin.error }), {
      status: supabaseAdmin.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const url = new URL(request.url);
  const limit = Math.min(50, Math.max(1, parseInt(url.searchParams.get("limit") || "10", 10) || 10));

  const { data: notifications, error } = await supabaseAdmin
    .from("admin_notifications")
    .select("id, title, body, filter, created_by, created_at, sent_at")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ notifications: notifications ?? [] }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;
  const { supabaseAdmin, user, actorRole } = await getServerSideProps({ locals });
  if ("error" in supabaseAdmin) {
    return new Response(JSON.stringify({ error: supabaseAdmin.error }), {
      status: supabaseAdmin.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Only ADMIN may send broadcasts (MODERATOR cannot)
  if (actorRole !== "ADMIN") {
    return new Response(JSON.stringify({ error: "Nur ADMIN kann Broadcasts versenden." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: { title?: string; body?: string; filter?: { role?: string; is_pro?: boolean } };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.title || typeof body.title !== "string" || body.title.trim().length === 0) {
    return new Response(JSON.stringify({ error: "Titel erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.body || typeof body.body !== "string" || body.body.trim().length === 0) {
    return new Response(JSON.stringify({ error: "Nachricht erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Store notification
  const { data: notification, error: insertError } = await supabaseAdmin
    .from("admin_notifications")
    .insert({
      title: body.title.trim(),
      body: body.body.trim(),
      filter: body.filter ?? null,
      created_by: user.id,
    })
    .select("id")
    .single();

  if (insertError || !notification) {
    return new Response(JSON.stringify({ error: insertError?.message ?? "Fehler beim Speichern." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const notificationId = notification.id;

  // Build push subscription query with filters
  let subQuery = supabaseAdmin
    .from("push_subscriptions")
    .select("user_id, endpoint, keys");

  if (body.filter) {
    // Join with profiles to apply role/is_pro filters
    let profileQuery = supabaseAdmin
      .from("profiles")
      .select("id");

    if (body.filter.role && ["USER", "MODERATOR", "ADMIN"].includes(body.filter.role)) {
      profileQuery = profileQuery.eq("role", body.filter.role);
    }
    if (body.filter.is_pro === true) {
      profileQuery = profileQuery.eq("is_pro", true);
    }

    const { data: filteredProfiles } = await profileQuery;
    const profileIds = (filteredProfiles ?? []).map((p: any) => p.id);

    if (profileIds.length > 0) {
      subQuery = subQuery.in("user_id", profileIds);
    } else {
      // No matching profiles, nothing to send
      await supabaseAdmin
        .from("admin_notifications")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", notificationId);

      await writeAudit(supabaseAdmin, user.id, "notification.broadcast", "notification", notificationId, {
        title: body.title,
        filter: body.filter,
        sent: 0,
      });

      return new Response(JSON.stringify({ success: true, notification_id: notificationId, sent: 0 }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  const { data: subs } = await subQuery;

  if (!subs || subs.length === 0) {
    await supabaseAdmin
      .from("admin_notifications")
      .update({ sent_at: new Date().toISOString() })
      .eq("id", notificationId);

    await writeAudit(supabaseAdmin, user.id, "notification.broadcast", "notification", notificationId, {
      title: body.title,
      filter: body.filter,
      sent: 0,
    });

    return new Response(JSON.stringify({ success: true, notification_id: notificationId, sent: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Configure web-push
  const vapidPublicKey = import.meta.env.VAPID_PUBLIC_KEY;
  const vapidPrivateKey = import.meta.env.VAPID_PRIVATE_KEY;
  const vapidSubject = import.meta.env.VAPID_SUBJECT || "mailto:info@carp24.at";

  let pushConfigured = true;
  if (!vapidPrivateKey || !vapidPublicKey) {
    pushConfigured = false;
  } else {
    webPush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);
  }

  // Deduplicate by user_id (send one push per user)
  const userSubsMap = new Map<string, { endpoint: string; keys: any }[]>();
  for (const sub of subs) {
    const list = userSubsMap.get(sub.user_id) || [];
    list.push({ endpoint: sub.endpoint, keys: sub.keys });
    userSubsMap.set(sub.user_id, list);
  }

  const payload = JSON.stringify({
    title: body.title.trim(),
    body: body.body.trim(),
    url: "/dashboard",
  });

  let sent = 0;
  let expired = 0;

  if (pushConfigured) {
    for (const [, userSubs] of userSubsMap) {
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
            expired++;
          }
        }
      }
    }
  }

  // Mark as sent
  await supabaseAdmin
    .from("admin_notifications")
    .update({ sent_at: new Date().toISOString() })
    .eq("id", notificationId);

  await writeAudit(supabaseAdmin, user.id, "notification.broadcast", "notification", notificationId, {
    title: body.title,
    filter: body.filter,
    sent,
    expired,
    push_configured: pushConfigured,
  });

  return new Response(JSON.stringify({
    success: true,
    notification_id: notificationId,
    sent,
    expired,
    push_configured: pushConfigured,
    warning: !pushConfigured ? "Push ist nicht konfiguriert. Benachrichtigung wurde gespeichert, aber nicht versendet." : undefined,
  }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};