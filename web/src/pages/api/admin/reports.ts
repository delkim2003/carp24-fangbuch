import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { csrfGuard } from "./_csrf";
import { parseCookieHeader } from "@supabase/ssr";

export const prerender = false;

async function guard(request: Request) {
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
    },
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

async function writeAudit(supabaseAdmin: any, actorId: string, action: string, targetType: string, targetId: string, details: any) {
  await supabaseAdmin.from("admin_audit_log").insert({
    actor_id: actorId,
    action,
    target_type: targetType,
    target_id: targetId,
    details,
  });
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
  const status = url.searchParams.get("status") || "open";

  let query = supabaseAdmin
    .from("content_reports")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(100);

  if (status === "open") {
    query = query.eq("status", "open");
  } else if (status === "resolved") {
    query = query.eq("status", "resolved");
  }

  const { data: reports, error } = await query;
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const tableMap: Record<string, { table: string; fields: string }> = {
    catch: { table: "catches", fields: "id,user_id,species,weight_kg,water_id,created_at" },
    forum_thread: { table: "forum_threads", fields: "id,user_id,title,body,created_at" },
    forum_post: { table: "forum_posts", fields: "id,user_id,body,created_at" },
    chat_message: { table: "chat_messages", fields: "id,user_id,body,created_at" },
    marketplace_item: { table: "marketplace_items", fields: "id,user_id,title,price,status,created_at" },
  };

  const reporterIds = [...new Set((reports ?? []).map((r: any) => r.reporter_id).filter(Boolean))];

  const targetsByType = new Map<string, string[]>();
  for (const r of reports ?? []) {
    if (r.target_type && r.target_id && tableMap[r.target_type]) {
      const arr = targetsByType.get(r.target_type) ?? [];
      arr.push(r.target_id);
      targetsByType.set(r.target_type, arr);
    }
  }

  const [reporterProfiles, ...contentResults] = await Promise.all([
    reporterIds.length > 0
      ? supabaseAdmin.from("profiles").select("id, display_name").in("id", reporterIds)
      : Promise.resolve({ data: [] }),
    ...[...targetsByType.entries()].map(([type, ids]) =>
      supabaseAdmin.from(tableMap[type].table).select(tableMap[type].fields).in("id", ids)
    ),
  ]);

  const reporterMap = new Map<string, string>();
  for (const p of reporterProfiles.data ?? []) {
    reporterMap.set(p.id, p.display_name);
  }

  const contentMap = new Map<string, any>();
  const ownerIds = new Set<string>();
  const waterIds = new Set<string>();
  const typeKeys = [...targetsByType.keys()];

  for (let i = 0; i < contentResults.length; i++) {
    const type = typeKeys[i];
    for (const item of contentResults[i].data ?? []) {
      contentMap.set(`${type}:${item.id}`, item);
      if (item.user_id) ownerIds.add(item.user_id);
      if (type === "catch" && item.water_id) waterIds.add(item.water_id);
    }
  }

  const [ownerProfiles, watersResult] = await Promise.all([
    ownerIds.size > 0
      ? supabaseAdmin.from("profiles").select("id, display_name").in("id", [...ownerIds])
      : Promise.resolve({ data: [] }),
    waterIds.size > 0
      ? supabaseAdmin.from("waters").select("id, name").in("id", [...waterIds])
      : Promise.resolve({ data: [] }),
  ]);

  const ownerMap = new Map<string, { id: string; display_name: string }>();
  for (const p of ownerProfiles.data ?? []) {
    ownerMap.set(p.id, { id: p.id, display_name: p.display_name });
  }

  const waterMap = new Map<string, string>();
  for (const w of watersResult.data ?? []) {
    waterMap.set(w.id, w.name);
  }

  const enriched = (reports ?? []).map((r: any) => {
    const reporterName = r.reporter_id ? (reporterMap.get(r.reporter_id) ?? "Unbekannt") : "Unbekannt";

    let preview: any = null;
    let ownerDisplay: any = null;
    let ownerName = "Unbekannt";

    const mapping = tableMap[r.target_type];
    if (mapping) {
      const content = contentMap.get(`${r.target_type}:${r.target_id}`);
      if (content) {
        preview = { ...content };
        if (r.target_type === "catch" && content.water_id) {
          const wName = waterMap.get(content.water_id);
          if (wName) preview.water_name = wName;
        }
        if (content.user_id) {
          const owner = ownerMap.get(content.user_id);
          if (owner) {
            ownerName = owner.display_name;
            ownerDisplay = owner;
          }
        }
      }
    }

    return { ...r, reporter_name: reporterName, preview, owner: ownerDisplay, owner_name: ownerName };
  });

  return new Response(JSON.stringify({ reports: enriched }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const PATCH = async ({ request }: { request: Request }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;
  const g = await guard(request);
  if ("error" in g) {
    return new Response(JSON.stringify({ error: g.error }), {
      status: g.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { supabaseAdmin, session } = g;
  let body: { id?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.id) {
    return new Response(JSON.stringify({ error: "ID erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error } = await supabaseAdmin
    .from("content_reports")
    .update({ status: "resolved", resolved_at: new Date().toISOString(), resolved_by: session.user.id })
    .eq("id", body.id);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  await writeAudit(supabaseAdmin, session.user.id, "report.resolve", "report", body.id, {});

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const DELETE = async ({ request }: { request: Request }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;
  const g = await guard(request);
  if ("error" in g) {
    return new Response(JSON.stringify({ error: g.error }), {
      status: g.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { supabaseAdmin, session } = g;
  let body: { id?: string; target_id?: string; target_type?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.id) {
    return new Response(JSON.stringify({ error: "ID erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (body.target_id && body.target_type) {
    const softDeleteTypes = ["catch"];
    const hardDeleteTypes = ["forum_thread", "forum_post", "chat_message", "marketplace_item"];

    if (softDeleteTypes.includes(body.target_type)) {
      await supabaseAdmin
        .from("catches")
        .update({ deleted_at: new Date().toISOString() })
        .eq("id", body.target_id);
    } else if (hardDeleteTypes.includes(body.target_type)) {
      const tableMap: Record<string, string> = {
        forum_thread: "forum_threads",
        forum_post: "forum_posts",
        chat_message: "chat_messages",
        marketplace_item: "marketplace_items",
      };
      const table = tableMap[body.target_type];
      if (table) {
        await supabaseAdmin.from(table).delete().eq("id", body.target_id);
      }
    }
  }

  const { error } = await supabaseAdmin
    .from("content_reports")
    .update({ status: "resolved", resolved_at: new Date().toISOString(), resolved_by: session.user.id })
    .eq("id", body.id);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  await writeAudit(supabaseAdmin, session.user.id, "report.delete_content", "report", body.id, {
    target_type: body.target_type,
    target_id: body.target_id,
  });

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
