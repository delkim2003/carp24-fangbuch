import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import crypto from "crypto";
import { csrfGuard } from "./_csrf";

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
  const q = url.searchParams.get("q") || "";
  const roleFilter = url.searchParams.get("role") || "";
  const proFilter = url.searchParams.get("pro") || "";
  const bannedFilter = url.searchParams.get("banned") || "";

  const { data: authUsers } = await supabaseAdmin.auth.admin.listUsers({ perPage: 200 });
  const emailMap = new Map<string, string>();
  for (const t of authUsers.users) {
    if (t.id && t.email) emailMap.set(t.id, t.email);
  }

  let query = supabaseAdmin
    .from("profiles")
    .select("id, display_name, role, is_pro, created_at, deleted_at, banned_at, ban_reason")
    .order("created_at", { ascending: false })
    .limit(200);

  if (q) {
    query = query.or(`display_name.ilike.%${q}%,id.in.(${[...emailMap.entries()].filter(([, e]) => e.toLowerCase().includes(q.toLowerCase())).map(([id]) => id).join(",") || "00000000-0000-0000-0000-000000000000"})`);
  }
  if (roleFilter && ["USER", "MODERATOR", "ADMIN"].includes(roleFilter)) {
    query = query.eq("role", roleFilter);
  }
  if (proFilter === "true") {
    query = query.eq("is_pro", true);
  }
  if (bannedFilter === "true") {
    query = query.not("banned_at", "is", null);
  } else if (bannedFilter === "false") {
    query = query.is("banned_at", null);
  }

  const { data: profiles, error } = await query;

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const users = await Promise.all(
    (profiles ?? []).map(async (p: any) => {
      const { count: catchesCount } = await supabaseAdmin
        .from("catches")
        .select("id", { count: "exact", head: true })
        .eq("user_id", p.id)
        .is("deleted_at", null);

      const { count: openReportsCount } = await supabaseAdmin
        .from("content_reports")
        .select("id", { count: "exact", head: true })
        .eq("reporter_id", p.id)
        .eq("status", "open");

      return {
        ...p,
        email: emailMap.get(p.id) ?? "",
        catches_count: catchesCount ?? 0,
        open_reports_count: openReportsCount ?? 0,
      };
    })
  );

  return new Response(JSON.stringify({ users }), {
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
  let body: { id?: string; role?: string; is_pro?: boolean; ban?: boolean; ban_reason?: string; unban?: boolean };
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

  const { data: currentProfile } = await supabaseAdmin
    .from("profiles")
    .select("role, is_pro, banned_at")
    .eq("id", body.id)
    .single();

  if (!currentProfile) {
    return new Response(JSON.stringify({ error: "Nutzer nicht gefunden." }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (body.role && ["USER", "MODERATOR", "ADMIN"].includes(body.role)) {
    const { error } = await supabaseAdmin.from("profiles").update({ role: body.role }).eq("id", body.id);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    await writeAudit(supabaseAdmin, session.user.id, "user.role", "user", body.id, { field: "role", from: currentProfile.role, to: body.role });
  }

  if (typeof body.is_pro === "boolean") {
    const { error } = await supabaseAdmin.from("profiles").update({ is_pro: body.is_pro }).eq("id", body.id);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    await writeAudit(supabaseAdmin, session.user.id, "user.pro", "user", body.id, { field: "is_pro", from: currentProfile.is_pro, to: body.is_pro });
  }

  if (body.ban === true) {
    const reason = body.ban_reason || "Kein Grund angegeben";
    const { error } = await supabaseAdmin
      .from("profiles")
      .update({ banned_at: new Date().toISOString(), ban_reason: reason })
      .eq("id", body.id);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    await supabaseAdmin.auth.admin.updateUserById(body.id, { ban_duration: "876000h" });
    await writeAudit(supabaseAdmin, session.user.id, "user.ban", "user", body.id, { field: "banned_at", from: currentProfile.banned_at, to: "banned", reason });
  }

  if (body.unban === true) {
    const { error } = await supabaseAdmin
      .from("profiles")
      .update({ banned_at: null, ban_reason: null })
      .eq("id", body.id);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    await supabaseAdmin.auth.admin.updateUserById(body.id, { ban_duration: "none" });
    await writeAudit(supabaseAdmin, session.user.id, "user.unban", "user", body.id, { field: "banned_at", from: currentProfile.banned_at, to: null });
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const POST = async ({ request }: { request: Request }) => {
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
  let body: { action?: string; id?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (body.action === "reset_password" && body.id) {
    const newPassword = crypto.randomBytes(6).toString("hex") + "Aa1!";
    const { error } = await supabaseAdmin.auth.admin.updateUserById(body.id, { password: newPassword });
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    await writeAudit(supabaseAdmin, session.user.id, "user.reset_password", "user", body.id, {});
    return new Response(JSON.stringify({ success: true, password: newPassword }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ error: "Unbekannte Aktion." }), {
    status: 400,
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

  await writeAudit(supabaseAdmin, session.user.id, "user.delete", "user", body.id, {});

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
