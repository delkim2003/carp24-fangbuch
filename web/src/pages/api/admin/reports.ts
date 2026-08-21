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

  const enriched = await Promise.all(
    (reports ?? []).map(async (r: any) => {
      let reporterName = "Unbekannt";
      if (r.reporter_id) {
        const { data: reporter } = await supabaseAdmin
          .from("profiles")
          .select("display_name")
          .eq("id", r.reporter_id)
          .single();
        if (reporter) reporterName = reporter.display_name;
      }

      let preview: any = null;
      const tableMap: Record<string, { table: string; fields: string }> = {
        catch: { table: "catches", fields: "species,weight_kg,water_id,created_at" },
        forum_thread: { table: "forum_threads", fields: "title,body,created_at" },
        forum_post: { table: "forum_posts", fields: "body,created_at" },
        chat_message: { table: "chat_messages", fields: "body,created_at" },
        marketplace_item: { table: "marketplace_items", fields: "title,price,status,created_at" },
      };

      const mapping = tableMap[r.target_type];
      if (mapping) {
        const { data: content } = await supabaseAdmin
          .from(mapping.table)
          .select(mapping.fields)
          .eq("id", r.target_id)
          .single();
        if (content) {
          preview = content;
          if (r.target_type === "catch" && content.water_id) {
            const { data: water } = await supabaseAdmin
              .from("waters")
              .select("name")
              .eq("id", content.water_id)
              .single();
            if (water) preview.water_name = water.name;
          }
        }
      }

      return { ...r, reporter_name: reporterName, preview };
    })
  );

  return new Response(JSON.stringify({ reports: enriched }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const PATCH = async ({ request }: { request: Request }) => {
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

  return new Response(JSON.stringify({ success: true }), {
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

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
