import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";

export const prerender = false;

async function guard(request: Request) {
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
              return { name: pair.slice(0, idx).trim(), value: pair.slice(idx + 1).trim() };
            })
            .filter(Boolean) as { name: string; value: string }[];
        },
        setAll() {},
      },
    }
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

const ALLOWED_TYPES = ["catch", "forum", "chat", "marketplace"] as const;

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
  const type = url.searchParams.get("type") || "catch";
  const q = url.searchParams.get("q") || "";

  if (!ALLOWED_TYPES.includes(type as any)) {
    return new Response(JSON.stringify({ error: "Ungültiger Typ." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  let items: any[] = [];

  if (type === "catch") {
    let query = supabaseAdmin
      .from("catches")
      .select("id, user_id, species, weight_kg, water_id, created_at, deleted_at")
      .order("created_at", { ascending: false })
      .limit(50);
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
    let threadQuery = supabaseAdmin
      .from("forum_threads")
      .select("id, user_id, title, body, created_at")
      .order("created_at", { ascending: false })
      .limit(50);
    if (q) threadQuery = threadQuery.or(`title.ilike.%${q}%,body.ilike.%${q}%`);
    const { data: threads } = await threadQuery;

    let postQuery = supabaseAdmin
      .from("forum_posts")
      .select("id, user_id, thread_id, body, created_at")
      .order("created_at", { ascending: false })
      .limit(50);
    if (q) postQuery = postQuery.ilike("body", `%${q}%`);
    const { data: posts } = await postQuery;

    const allItems = [
      ...(threads ?? []).map((t: any) => ({ ...t, _type: "thread" })),
      ...(posts ?? []).map((p: any) => ({ ...p, _type: "post" })),
    ].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()).slice(0, 50);

    const userIds = [...new Set(allItems.map((i) => i.user_id).filter(Boolean))];
    if (userIds.length > 0) {
      const { data: profiles } = await supabaseAdmin
        .from("profiles")
        .select("id, display_name")
        .in("id", userIds);
      const nameMap = new Map((profiles ?? []).map((p: any) => [p.id, p.display_name]));
      items = allItems.map((i) => ({ ...i, display_name: nameMap.get(i.user_id) ?? "Unbekannt" }));
    } else {
      items = allItems;
    }
  } else if (type === "chat") {
    let query = supabaseAdmin
      .from("chat_messages")
      .select("id, user_id, body, created_at")
      .order("created_at", { ascending: false })
      .limit(50);
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
    let query = supabaseAdmin
      .from("marketplace_items")
      .select("id, user_id, title, price, status, created_at")
      .order("created_at", { ascending: false })
      .limit(50);
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

  return new Response(JSON.stringify({ items }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const DELETE = async ({ request }: { request: Request }) => {
  const g = await guard(request);
  if ("error" in g) {
    return new Response(JSON.stringify({ error: g.error }), {
      status: g.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { supabaseAdmin } = g;
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
        if (body.type === "forum") {
          await supabaseAdmin.from("forum_posts").delete().eq("id", body.id);
        }
      }
    }
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
