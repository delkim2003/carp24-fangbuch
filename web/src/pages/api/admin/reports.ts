import { getAdminClient } from "./_auth";
import { csrfGuard } from "./_csrf";

export const prerender = false;

async function writeAudit(supabaseAdmin: any, actorId: string, action: string, targetType: string, targetId: string, details: any) {
  await supabaseAdmin.from("admin_audit_log").insert({
    actor_id: actorId,
    action,
    target_type: targetType,
    target_id: targetId,
    details,
  });
}

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
  const action = url.searchParams.get("action") || "";
  const statusFilter = url.searchParams.get("status") || "open";

  const tableMap: Record<string, { table: string; fields: string }> = {
    catch: { table: "catches", fields: "id,user_id,species,weight_kg,water_id,created_at" },
    forum_thread: { table: "forum_threads", fields: "id,user_id,title,body,created_at" },
    forum_post: { table: "forum_posts", fields: "id,user_id,body,created_at" },
    chat_message: { table: "chat_messages", fields: "id,user_id,body,created_at" },
    marketplace_item: { table: "marketplace_items", fields: "id,user_id,title,price,status,created_at" },
  };

  // ── CSV Export ──────────────────────────────────────
  if (action === "export") {
    let query = supabaseAdmin
      .from("content_reports")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(10000);

    if (statusFilter === "open") {
      query = query.eq("status", "open");
    } else if (statusFilter === "resolved") {
      query = query.in("status", ["resolved", "dismissed", "escalated"]);
    }

    const { data: reports } = await query;

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
      const t = typeKeys[i];
      for (const item of contentResults[i].data ?? []) {
        contentMap.set(`${t}:${item.id}`, item);
        if (item.user_id) ownerIds.add(item.user_id);
        if (t === "catch" && item.water_id) waterIds.add(item.water_id);
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

    const ownerMap = new Map<string, string>();
    for (const p of ownerProfiles.data ?? []) {
      ownerMap.set(p.id, p.display_name);
    }
    const waterMap = new Map<string, string>();
    for (const w of watersResult.data ?? []) {
      waterMap.set(w.id, w.name);
    }

    const esc = (v: any): string => {
      const s = v == null ? "" : String(v);
      if (s.includes(",") || s.includes('"') || s.includes("\n") || s.includes("\r")) {
        return '"' + s.replace(/\"/g, '""') + '"';
      }
      return s;
    };

    const rows = (reports ?? []).map((r: any) => {
      const reporterName = r.reporter_id ? (reporterMap.get(r.reporter_id) ?? "Unbekannt") : "Unbekannt";
      let preview: any = null;
      let ownerName = "Unbekannt";
      const mapping = tableMap[r.target_type];
      if (mapping) {
        const content = contentMap.get(`${r.target_type}:${r.target_id}`);
        if (content) {
          preview = content;
          if (r.target_type === "catch" && content.water_id) {
            const wName = waterMap.get(content.water_id);
            if (wName) preview = { ...preview, water_name: wName };
          }
          if (content.user_id) {
            ownerName = ownerMap.get(content.user_id) ?? "Unbekannt";
          }
        }
      }
      return {
        id: r.id,
        reporter_id: r.reporter_id ?? "",
        reporter_name: reporterName,
        target_type: r.target_type ?? "",
        target_id: r.target_id ?? "",
        reason: r.reason ?? "",
        status: r.status ?? "",
        created_at: r.created_at ?? "",
        resolved_at: r.resolved_at ?? "",
        owner_name: ownerName,
        preview_species: preview?.species ?? "",
        preview_weight_kg: preview?.weight_kg ?? "",
        preview_water_name: preview?.water_name ?? "",
        preview_title: preview?.title ?? "",
        preview_body: (preview?.body ?? "").slice(0, 200),
        preview_price: preview?.price ?? "",
      };
    });

    const cols = [
      "id", "reporter_id", "reporter_name", "target_type", "target_id",
      "reason", "status", "created_at", "resolved_at", "owner_name",
      "preview_species", "preview_weight_kg", "preview_water_name",
      "preview_title", "preview_body", "preview_price",
    ];
    const bom = "\uFEFF";
    const csv = bom + cols.map((c) => esc(c)).join(",") + "\r\n" +
      rows.map((r) => cols.map((c) => esc((r as any)[c])).join(",")).join("\r\n") + "\r\n";

    return new Response(csv, {
      status: 200,
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": 'attachment; filename="reports.csv"',
      },
    });
  }

  // ── Regular paginated JSON ──────────────────────────

  const page = Math.max(parseInt(url.searchParams.get("page") || "1", 10), 1);
  const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit") || "25", 10) || 25, 1), 100);
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let countQuery = supabaseAdmin
    .from("content_reports")
    .select("*", { count: "exact", head: true });

  if (statusFilter === "open") {
    countQuery = countQuery.eq("status", "open");
  } else if (statusFilter === "resolved") {
    countQuery = countQuery.in("status", ["resolved", "dismissed", "escalated"]);
  }

  const { count, error: countError } = await countQuery;
  if (countError) {
    return new Response(JSON.stringify({ error: countError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let dataQuery = supabaseAdmin
    .from("content_reports")
    .select("*")
    .order("created_at", { ascending: false })
    .range(from, to);

  if (statusFilter === "open") {
    dataQuery = dataQuery.eq("status", "open");
  } else if (statusFilter === "resolved") {
    dataQuery = dataQuery.in("status", ["resolved", "dismissed", "escalated"]);
  }

  const { data: reports, error } = await dataQuery;
  if (error) {
    console.error("[admin]", error);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const totalPages = Math.ceil((count ?? 0) / limit);

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
    const t = typeKeys[i];
    for (const item of contentResults[i].data ?? []) {
      contentMap.set(`${t}:${item.id}`, item);
      if (item.user_id) ownerIds.add(item.user_id);
      if (t === "catch" && item.water_id) waterIds.add(item.water_id);
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

  return new Response(JSON.stringify({ reports: enriched, pagination: { page, limit, total: count ?? 0, totalPages } }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;
  const auth = await getAdminClient(locals);
  if ("error" in auth) {
    return new Response(JSON.stringify({ error: auth.error }), {
      status: auth.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { supabaseAdmin, user } = auth;
  let body: { action?: string; reportId?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.action || !body.reportId) {
    return new Response(JSON.stringify({ error: "action und reportId erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { action, reportId } = body;

  if (action === "dismiss") {
    const { error } = await supabaseAdmin
      .from("content_reports")
      .update({
        status: "dismissed",
        dismissed_at: new Date().toISOString(),
        dismissed_by: user.id,
      })
      .eq("id", reportId);

    if (error) {
      console.error("[admin]", error);
      return new Response(JSON.stringify({ error: "Interner Fehler" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    await writeAudit(supabaseAdmin, user.id, "report.dismiss", "report", reportId, {});
    return new Response(JSON.stringify({ success: true, status: "dismissed" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (action === "escalate") {
    const { error } = await supabaseAdmin
      .from("content_reports")
      .update({
        status: "escalated",
        escalated_at: new Date().toISOString(),
        escalated_by: user.id,
      })
      .eq("id", reportId);

    if (error) {
      console.error("[admin]", error);
      return new Response(JSON.stringify({ error: "Interner Fehler" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    await writeAudit(supabaseAdmin, user.id, "report.escalate", "report", reportId, {});
    return new Response(JSON.stringify({ success: true, status: "escalated" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ error: "Unbekannte Aktion: " + action }), {
    status: 400,
    headers: { "Content-Type": "application/json" },
  });
};

export const PATCH = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;
  const auth = await getAdminClient(locals);
  if ("error" in auth) {
    return new Response(JSON.stringify({ error: auth.error }), {
      status: auth.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { supabaseAdmin, user } = auth;
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
    .update({ status: "resolved", resolved_at: new Date().toISOString(), resolved_by: user.id })
    .eq("id", body.id);

  if (error) {
    console.error("[admin]", error);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  await writeAudit(supabaseAdmin, user.id, "report.resolve", "report", body.id, {});

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const DELETE = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;
  const auth = await getAdminClient(locals);
  if ("error" in auth) {
    return new Response(JSON.stringify({ error: auth.error }), {
      status: auth.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { supabaseAdmin, user } = auth;
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
    .update({ status: "resolved", resolved_at: new Date().toISOString(), resolved_by: user.id })
    .eq("id", body.id);

  if (error) {
    console.error("[admin]", error);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  await writeAudit(supabaseAdmin, user.id, "report.delete_content", "report", body.id, {
    target_type: body.target_type,
    target_id: body.target_id,
  });

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};