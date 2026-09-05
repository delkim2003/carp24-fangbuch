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
        secure: true,
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return { error: "Nicht angemeldet.", status: 401 };

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") return { error: "Keine Berechtigung.", status: 403 };

  const supabaseAdmin = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY
  );

  return { supabaseAdmin, user };
}

const ALLOWED_TYPES = ["catch", "forum", "chat", "marketplace"] as const;

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
  const action = url.searchParams.get("action") || "";
  const type = url.searchParams.get("type") || "catch";
  const q = url.searchParams.get("q") || "";

  if (!ALLOWED_TYPES.includes(type as any)) {
    return new Response(JSON.stringify({ error: "Ungültiger Typ." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ── CSV Export ──────────────────────────────────────
  if (action === "export") {
    const esc = (v: any): string => {
      const s = v == null ? "" : String(v);
      if (s.includes(",") || s.includes('"') || s.includes("\n") || s.includes("\r")) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    };

    if (type === "catch") {
      let query = supabaseAdmin
        .from("catches")
        .select("id, user_id, species, weight_kg, water_id, created_at, deleted_at")
        .order("created_at", { ascending: false })
        .limit(10000);
      if (q) query = query.ilike("species", `%${q}%`);
      const { data } = await query;
      let items = (data ?? []) as any[];

      const userIds = [...new Set(items.map((i) => i.user_id).filter(Boolean))];
      let nameMap = new Map<string, string>();
      if (userIds.length > 0) {
        const { data: profiles } = await supabaseAdmin
          .from("profiles")
          .select("id, display_name")
          .in("id", userIds);
        nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      }

      const waterIds = [...new Set(items.map((i) => i.water_id).filter(Boolean))];
      let waterMap = new Map<string, string>();
      if (waterIds.length > 0) {
        const { data: waters } = await supabaseAdmin
          .from("waters")
          .select("id, name")
          .in("id", waterIds);
        waterMap = new Map((waters ?? []).map((w: any) => [w.id, w.name]));
      }

      const rows = items.map((i) => ({
        id: i.id,
        user_id: i.user_id,
        display_name: nameMap.get(i.user_id) ?? "Unbekannt",
        species: i.species ?? "",
        weight_kg: i.weight_kg ?? "",
        water_name: waterMap.get(i.water_id) ?? "",
        created_at: i.created_at ?? "",
        deleted_at: i.deleted_at ?? "",
      }));

      const cols = ["id", "user_id", "display_name", "species", "weight_kg", "water_name", "created_at", "deleted_at"];
      const bom = "\uFEFF";
      const csv = bom + cols.map((c) => esc(c)).join(",") + "\r\n" +
        rows.map((r) => cols.map((c) => esc((r as any)[c])).join(",")).join("\r\n") + "\r\n";

      return new Response(csv, {
        status: 200,
        headers: {
          "Content-Type": "text/csv; charset=utf-8",
          "Content-Disposition": 'attachment; filename="catches.csv"',
        },
      });
    }

    if (type === "forum") {
      let threadQuery = supabaseAdmin
        .from("forum_threads")
        .select("id, user_id, title, body, created_at")
        .order("created_at", { ascending: false })
        .limit(10000);
      if (q) threadQuery = threadQuery.or(`title.ilike.%${q}%,body.ilike.%${q}%`);
      const { data: threads } = await threadQuery;

      let postQuery = supabaseAdmin
        .from("forum_posts")
        .select("id, user_id, thread_id, body, created_at")
        .order("created_at", { ascending: false })
        .limit(10000);
      if (q) postQuery = postQuery.ilike("body", `%${q}%`);
      const { data: posts } = await postQuery;

      const allItems = [
        ...(threads ?? []).map((t: any) => ({ ...t, _type: "thread" })),
        ...(posts ?? []).map((p: any) => ({ ...p, _type: "post" })),
      ].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

      const userIds = [...new Set(allItems.map((i) => i.user_id).filter(Boolean))];
      let nameMap = new Map<string, string>();
      if (userIds.length > 0) {
        const { data: profiles } = await supabaseAdmin
          .from("profiles")
          .select("id, display_name")
          .in("id", userIds);
        nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      }

      const rows = allItems.map((i) => ({
        id: i.id,
        user_id: i.user_id,
        display_name: nameMap.get(i.user_id) ?? "Unbekannt",
        type: i._type,
        title: i.title ?? "",
        body: (i.body ?? "").slice(0, 500),
        created_at: i.created_at ?? "",
      }));

      const cols = ["id", "user_id", "display_name", "type", "title", "body", "created_at"];
      const bom = "\uFEFF";
      const csv = bom + cols.map((c) => esc(c)).join(",") + "\r\n" +
        rows.map((r) => cols.map((c) => esc((r as any)[c])).join(",")).join("\r\n") + "\r\n";

      return new Response(csv, {
        status: 200,
        headers: {
          "Content-Type": "text/csv; charset=utf-8",
          "Content-Disposition": 'attachment; filename="forum.csv"',
        },
      });
    }

    if (type === "chat") {
      let query = supabaseAdmin
        .from("chat_messages")
        .select("id, user_id, body, created_at")
        .order("created_at", { ascending: false })
        .limit(10000);
      if (q) query = query.ilike("body", `%${q}%`);
      const { data } = await query;
      let items = (data ?? []) as any[];

      const userIds = [...new Set(items.map((i) => i.user_id).filter(Boolean))];
      let nameMap = new Map<string, string>();
      if (userIds.length > 0) {
        const { data: profiles } = await supabaseAdmin
          .from("profiles")
          .select("id, display_name")
          .in("id", userIds);
        nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      }

      const rows = items.map((i) => ({
        id: i.id,
        user_id: i.user_id,
        display_name: nameMap.get(i.user_id) ?? "Unbekannt",
        body: (i.body ?? "").slice(0, 500),
        created_at: i.created_at ?? "",
      }));

      const cols = ["id", "user_id", "display_name", "body", "created_at"];
      const bom = "\uFEFF";
      const csv = bom + cols.map((c) => esc(c)).join(",") + "\r\n" +
        rows.map((r) => cols.map((c) => esc((r as any)[c])).join(",")).join("\r\n") + "\r\n";

      return new Response(csv, {
        status: 200,
        headers: {
          "Content-Type": "text/csv; charset=utf-8",
          "Content-Disposition": 'attachment; filename="chat.csv"',
        },
      });
    }

    if (type === "marketplace") {
      let query = supabaseAdmin
        .from("marketplace_items")
        .select("id, user_id, title, price, status, created_at")
        .order("created_at", { ascending: false })
        .limit(10000);
      if (q) query = query.ilike("title", `%${q}%`);
      const { data } = await query;
      let items = (data ?? []) as any[];

      const userIds = [...new Set(items.map((i) => i.user_id).filter(Boolean))];
      let nameMap = new Map<string, string>();
      if (userIds.length > 0) {
        const { data: profiles } = await supabaseAdmin
          .from("profiles")
          .select("id, display_name")
          .in("id", userIds);
        nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      }

      const rows = items.map((i) => ({
        id: i.id,
        user_id: i.user_id,
        display_name: nameMap.get(i.user_id) ?? "Unbekannt",
        title: i.title ?? "",
        price: i.price ?? "",
        status: i.status ?? "",
        created_at: i.created_at ?? "",
      }));

      const cols = ["id", "user_id", "display_name", "title", "price", "status", "created_at"];
      const bom = "\uFEFF";
      const csv = bom + cols.map((c) => esc(c)).join(",") + "\r\n" +
        rows.map((r) => cols.map((c) => esc((r as any)[c])).join(",")).join("\r\n") + "\r\n";

      return new Response(csv, {
        status: 200,
        headers: {
          "Content-Type": "text/csv; charset=utf-8",
          "Content-Disposition": 'attachment; filename="marketplace.csv"',
        },
      });
    }
  }

  // ── Regular paginated JSON ──────────────────────────

  const page = Math.max(1, parseInt(url.searchParams.get("page") || "1", 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get("limit") || "25", 10) || 25));
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let items: any[] = [];
  let total = 0;

  if (type === "catch") {
    let countQuery = supabaseAdmin
      .from("catches")
      .select("*", { count: "exact", head: true });
    if (q) countQuery = countQuery.ilike("species", `%${q}%`);
    const { count } = await countQuery;
    total = count ?? 0;

    let query = supabaseAdmin
      .from("catches")
      .select("id, user_id, species, weight_kg, water_id, created_at, deleted_at")
      .order("created_at", { ascending: false })
      .range(from, to);
    if (q) query = query.ilike("species", `%${q}%`);
    const { data } = await query;
    items = data ?? [];

    const userIds = [...new Set(items.map((i) => i.user_id).filter(Boolean))];
    if (userIds.length > 0) {
      const { data: profiles } = await supabaseAdmin
        .from("profiles")
        .select("id, display_name")
        .in("id", userIds);
      const nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      items = items.map((i) => ({ ...i, display_name: nameMap.get(i.user_id) ?? "Unbekannt" }));
    }

    const waterIds = [...new Set(items.map((i) => i.water_id).filter(Boolean))];
    if (waterIds.length > 0) {
      const { data: waters } = await supabaseAdmin
        .from("waters")
        .select("id, name")
        .in("id", waterIds);
      const waterMap = new Map((waters ?? []).map((w: any) => [w.id, w.name]));
      items = items.map((i) => ({ ...i, water_name: waterMap.get(i.water_id) ?? "" }));
    }
  } else if (type === "forum") {
    let threadCountQuery = supabaseAdmin
      .from("forum_threads")
      .select("*", { count: "exact", head: true });
    if (q) threadCountQuery = threadCountQuery.or(`title.ilike.%${q}%,body.ilike.%${q}%`);
    const { count: threadCount } = await threadCountQuery;

    let postCountQuery = supabaseAdmin
      .from("forum_posts")
      .select("*", { count: "exact", head: true });
    if (q) postCountQuery = postCountQuery.ilike("body", `%${q}%`);
    const { count: postCount } = await postCountQuery;

    total = (threadCount ?? 0) + (postCount ?? 0);

    // Fetch all matching threads and posts, merge, sort, then paginate in memory
    const combinedLimit = Math.min(total, 2000);
    let threadQuery = supabaseAdmin
      .from("forum_threads")
      .select("id, user_id, title, body, created_at")
      .order("created_at", { ascending: false })
      .limit(combinedLimit);
    if (q) threadQuery = threadQuery.or(`title.ilike.%${q}%,body.ilike.%${q}%`);

    let postQuery = supabaseAdmin
      .from("forum_posts")
      .select("id, user_id, thread_id, body, created_at")
      .order("created_at", { ascending: false })
      .limit(combinedLimit);
    if (q) postQuery = postQuery.ilike("body", `%${q}%`);

    const [threadRes, postRes] = await Promise.all([
      threadQuery,
      postQuery,
    ]);

    const allItems = [
      ...(threadRes.data ?? []).map((t: any) => ({ ...t, _type: "thread" })),
      ...(postRes.data ?? []).map((p: any) => ({ ...p, _type: "post" })),
    ].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

    // Apply real pagination on the merged, sorted result
    items = allItems.slice(from, from + limit);

    const userIds = [...new Set(items.map((i) => i.user_id).filter(Boolean))];
    if (userIds.length > 0) {
      const { data: profiles } = await supabaseAdmin
        .from("profiles")
        .select("id, display_name")
        .in("id", userIds);
      const nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      items = items.map((i) => ({ ...i, display_name: nameMap.get(i.user_id) ?? "Unbekannt" }));
    }
  } else if (type === "chat") {
    let countQuery = supabaseAdmin
      .from("chat_messages")
      .select("*", { count: "exact", head: true });
    if (q) countQuery = countQuery.ilike("body", `%${q}%`);
    const { count } = await countQuery;
    total = count ?? 0;

    let query = supabaseAdmin
      .from("chat_messages")
      .select("id, user_id, body, created_at")
      .order("created_at", { ascending: false })
      .range(from, to);
    if (q) query = query.ilike("body", `%${q}%`);
    const { data } = await query;
    items = data ?? [];

    const userIds = [...new Set(items.map((i) => i.user_id).filter(Boolean))];
    if (userIds.length > 0) {
      const { data: profiles } = await supabaseAdmin
        .from("profiles")
        .select("id, display_name")
        .in("id", userIds);
      const nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      items = items.map((i) => ({ ...i, display_name: nameMap.get(i.user_id) ?? "Unbekannt" }));
    }
  } else if (type === "marketplace") {
    let countQuery = supabaseAdmin
      .from("marketplace_items")
      .select("*", { count: "exact", head: true });
    if (q) countQuery = countQuery.ilike("title", `%${q}%`);
    const { count } = await countQuery;
    total = count ?? 0;

    let query = supabaseAdmin
      .from("marketplace_items")
      .select("id, user_id, title, price, status, created_at")
      .order("created_at", { ascending: false })
      .range(from, to);
    if (q) query = query.ilike("title", `%${q}%`);
    const { data } = await query;
    items = data ?? [];

    const userIds = [...new Set(items.map((i) => i.user_id).filter(Boolean))];
    if (userIds.length > 0) {
      const { data: profiles } = await supabaseAdmin
        .from("profiles")
        .select("id, display_name")
        .in("id", userIds);
      const nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      items = items.map((i) => ({ ...i, display_name: nameMap.get(i.user_id) ?? "Unbekannt" }));
    }
  }

  const totalPages = Math.max(1, Math.ceil(total / limit));

  return new Response(JSON.stringify({
    items,
    pagination: { page, limit, total, totalPages },
  }), {
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

  const { supabaseAdmin, user } = g;
  let body: { type?: string; id?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.type || !body.id) {
    return new Response(JSON.stringify({ error: "Typ und ID erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!ALLOWED_TYPES.includes(body.type as any)) {
    return new Response(JSON.stringify({ error: "Ungültiger Typ." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (body.type === "catch") {
    const { error } = await supabaseAdmin
      .from("catches")
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", body.id);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    await writeAudit(supabaseAdmin, user.id, "content.delete", body.type, body.id, {});
  } else {
    const tableMap: Record<string, string> = {
      forum: "forum_threads",
      chat: "chat_messages",
      marketplace: "marketplace_items",
    };
    const table = tableMap[body.type];
    if (table) {
      const { error } = await supabaseAdmin.from(table).delete().eq("id", body.id);
      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }
    }
    await writeAudit(supabaseAdmin, user.id, "content.delete", body.type, body.id, {});
  }

  return new Response(JSON.stringify({ success: true }), {
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

  const { supabaseAdmin, user } = g;

  let body: { contentId?: string; contentType?: string; updates?: Record<string, any> };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.contentId || !body.contentType || !body.updates) {
    return new Response(JSON.stringify({ error: "contentId, contentType und updates erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const ALLOWED_CONTENT_TYPES = ["catch", "post", "comment"];
  if (!ALLOWED_CONTENT_TYPES.includes(body.contentType)) {
    return new Response(JSON.stringify({ error: "Ungültiger contentType. Erlaubt: catch, post, comment." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const ALLOWED_UPDATES: Record<string, string[]> = {
    catch: ["notes", "bait", "method", "water_name", "species_custom"],
    post: ["title", "body"],
    comment: ["body"],
  };

  const allowed = ALLOWED_UPDATES[body.contentType];
  const cleaned: Record<string, any> = {};
  for (const key of Object.keys(body.updates)) {
    if (allowed.includes(key)) {
      cleaned[key] = body.updates[key];
    }
  }

  if (Object.keys(cleaned).length === 0) {
    return new Response(JSON.stringify({ error: "Keine gültigen Felder zum Aktualisieren." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  cleaned.updated_at = new Date().toISOString();

  const TABLE_MAP: Record<string, string> = {
    catch: "catches",
    post: "forum_posts",
    comment: "chat_messages",
  };

  const table = TABLE_MAP[body.contentType];

  const { error } = await supabaseAdmin
    .from(table)
    .update(cleaned)
    .eq("id", body.contentId);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  await writeAudit(supabaseAdmin, user.id, "content.update", body.contentType, body.contentId, { updates: cleaned });

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};