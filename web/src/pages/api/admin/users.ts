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

  const { data: authUsers } = await supabaseAdmin.auth.admin.listUsers({ perPage: 200 });
  const emailMap = new Map<string, string>();
  for (const u of authUsers.users) {
    if (u.id && u.email) emailMap.set(u.id, u.email);
  }

  const { data: profiles, error } = await supabaseAdmin
    .from("profiles")
    .select("id, display_name, role, is_pro, created_at, deleted_at")
    .order("created_at", { ascending: false })
    .limit(200);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const users = await Promise.all(
    (profiles ?? []).map(async (p: any) => {
      const { count } = await supabaseAdmin
        .from("catches")
        .select("id", { count: "exact", head: true })
        .eq("user_id", p.id)
        .is("deleted_at", null);

      return {
        ...p,
        email: emailMap.get(p.id) ?? "",
        catches_count: count ?? 0,
      };
    })
  );

  return new Response(JSON.stringify({ users }), {
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

  const { supabaseAdmin } = g;
  let body: { id?: string; role?: string; is_pro?: boolean };
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

  const updates: Record<string, any> = {};
  if (body.role && ["USER", "MODERATOR", "ADMIN"].includes(body.role)) updates.role = body.role;
  if (typeof body.is_pro === "boolean") updates.is_pro = body.is_pro;

  if (Object.keys(updates).length === 0) {
    return new Response(JSON.stringify({ error: "Keine Änderungen." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error } = await supabaseAdmin.from("profiles").update(updates).eq("id", body.id);

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

  const { supabaseAdmin } = g;
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
    .from("profiles")
    .update({ deleted_at: new Date().toISOString() })
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
