import { escHtml } from "../../../lib/escape";
import { getAdminClient } from "./_auth";
import crypto from "crypto";
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
  const q = url.searchParams.get("q") || "";
  const roleFilter = url.searchParams.get("role") || "";
  const proFilter = url.searchParams.get("pro") || "";
  const bannedFilter = url.searchParams.get("banned") || "";

  // ── CSV Export ──────────────────────────────────────
  if (action === "export") {
    const { data: authUsers } = await supabaseAdmin.auth.admin.listUsers({ perPage: 200 });
    const emailMap = new Map<string, string>();
    for (const t of authUsers.users) {
      if (t.id && t.email) emailMap.set(t.id, t.email);
    }

    let query = supabaseAdmin
      .from("profiles")
      .select("id, display_name, role, is_pro, created_at, deleted_at, banned_at, ban_reason")
      .order("created_at", { ascending: false })
      .limit(10000);

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

    const { data: profiles } = await query;

    const rows = (profiles ?? []).map((p: any) => ({
      id: p.id,
      email: emailMap.get(p.id) ?? "",
      display_name: p.display_name ?? "",
      role: p.role ?? "USER",
      is_pro: p.is_pro ? "Ja" : "Nein",
      created_at: p.created_at ?? "",
      deleted_at: p.deleted_at ?? "",
      banned_at: p.banned_at ?? "",
      ban_reason: p.ban_reason ?? "",
    }));

    const esc = (v: any): string => {
      const s = v == null ? "" : String(v);
      if (s.includes(",") || s.includes('"') || s.includes("\n") || s.includes("\r")) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    };

    const cols = ["id", "email", "display_name", "role", "is_pro", "created_at", "deleted_at", "banned_at", "ban_reason"];
    const bom = "\uFEFF";
    const csv = bom + cols.map((c) => esc(c)).join(",") + "\r\n" +
      rows.map((r) => cols.map((c) => esc((r as any)[c])).join(",")).join("\r\n") + "\r\n";

    return new Response(csv, {
      status: 200,
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": 'attachment; filename="users.csv"',
      },
    });
  }

  // ── Regular paginated JSON ──────────────────────────

  const page = Math.max(1, parseInt(url.searchParams.get("page") || "1", 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get("limit") || "25", 10) || 25));
  const from = (page - 1) * limit;
  const to = page * limit - 1;

  const { data: authUsers } = await supabaseAdmin.auth.admin.listUsers({ perPage: 200 });
  const emailMap = new Map<string, string>();
  const lastSignInMap = new Map<string, string | null>();
  for (const t of authUsers.users) {
    if (t.id && t.email) emailMap.set(t.id, t.email);
    if (t.id) lastSignInMap.set(t.id, t.last_sign_in_at ?? null);
  }

  // Count query with identical filters
  let countQuery = supabaseAdmin
    .from("profiles")
    .select("id", { count: "exact", head: true });

  if (q) {
    countQuery = countQuery.or(`display_name.ilike.%${q}%,id.in.(${[...emailMap.entries()].filter(([, e]) => e.toLowerCase().includes(q.toLowerCase())).map(([id]) => id).join(",") || "00000000-0000-0000-0000-000000000000"})`);
  }
  if (roleFilter && ["USER", "MODERATOR", "ADMIN"].includes(roleFilter)) {
    countQuery = countQuery.eq("role", roleFilter);
  }
  if (proFilter === "true") {
    countQuery = countQuery.eq("is_pro", true);
  }
  if (bannedFilter === "true") {
    countQuery = countQuery.not("banned_at", "is", null);
  } else if (bannedFilter === "false") {
    countQuery = countQuery.is("banned_at", null);
  }

  const { count: total, error: countError } = await countQuery;

  if (countError) {
    return new Response(JSON.stringify({ error: countError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Data query with pagination range
  let query = supabaseAdmin
    .from("profiles")
    .select("id, display_name, role, is_pro, created_at, deleted_at, banned_at, ban_reason")
    .order("created_at", { ascending: false })
    .range(from, to);

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

  const profileIds = (profiles ?? []).map((p: any) => p.id);

  const [{ data: allCatches }, { data: allReports }] = await Promise.all([
    profileIds.length > 0
      ? supabaseAdmin.from("catches").select("user_id").in("user_id", profileIds).is("deleted_at", null)
      : Promise.resolve({ data: [] }),
    profileIds.length > 0
      ? supabaseAdmin.from("content_reports").select("reporter_id").in("reporter_id", profileIds).eq("status", "open")
      : Promise.resolve({ data: [] }),
  ]);

  const catchesMap = new Map<string, number>();
  for (const c of allCatches ?? []) {
    catchesMap.set(c.user_id, (catchesMap.get(c.user_id) ?? 0) + 1);
  }

  const reportsMap = new Map<string, number>();
  for (const r of allReports ?? []) {
    reportsMap.set(r.reporter_id, (reportsMap.get(r.reporter_id) ?? 0) + 1);
  }

  const users = (profiles ?? []).map((p: any) => ({
    ...p,
    email: emailMap.get(p.id) ?? "",
    last_sign_in_at: lastSignInMap.get(p.id) ?? null,
    catches_count: catchesMap.get(p.id) ?? 0,
    open_reports_count: reportsMap.get(p.id) ?? 0,
  }));

  const totalPages = Math.ceil((total ?? 0) / limit);

  return new Response(JSON.stringify({ users, pagination: { page, limit, total: total ?? 0, totalPages } }), {
    status: 200,
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
  const { supabaseAdmin, user, actorRole } = auth;
  let body: { id?: string; role?: string; is_pro?: boolean; ban?: boolean; ban_reason?: string; unban?: boolean };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Input-Validierung
  if (!body.id || !/^[0-9a-f-]{36}$/.test(body.id)) {
    return new Response(JSON.stringify({ error: "Ungültige User-ID." }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (body.role && !["USER", "MODERATOR", "ADMIN"].includes(body.role)) {
    return new Response(JSON.stringify({ error: "Ungültige Rolle." }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (body.ban_reason) {
    body.ban_reason = escHtml(String(body.ban_reason).slice(0, 500));
  }

  if (!body.id) {
    return new Response(JSON.stringify({ error: "ID erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (body.role && actorRole === "MODERATOR" && body.role !== "USER") {
    return new Response(JSON.stringify({ error: "MODERATOR darf nur die USER-Rolle vergeben." }), {
      status: 403,
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
    await writeAudit(supabaseAdmin, user.id, "user.role", "user", body.id, { field: "role", from: currentProfile.role, to: body.role });
  }

  if (typeof body.is_pro === "boolean") {
    const { error } = await supabaseAdmin.from("profiles").update({ is_pro: body.is_pro }).eq("id", body.id);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    await writeAudit(supabaseAdmin, user.id, "user.pro", "user", body.id, { field: "is_pro", from: currentProfile.is_pro, to: body.is_pro });
  }

  if ((body.ban === true || body.unban === true) && actorRole === "MODERATOR" && (currentProfile.role === "ADMIN" || currentProfile.role === "MODERATOR")) {
    return new Response(JSON.stringify({ error: "MODERATOR darf ADMIN/MODERATOR nicht bannen oder entbannen." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
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
    await writeAudit(supabaseAdmin, user.id, "user.ban", "user", body.id, { field: "banned_at", from: currentProfile.banned_at, to: "banned", reason });
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
    await writeAudit(supabaseAdmin, user.id, "user.unban", "user", body.id, { field: "banned_at", from: currentProfile.banned_at, to: null });
  }

  return new Response(JSON.stringify({ success: true }), {
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
  const { supabaseAdmin, user, actorRole } = auth;
  let body: { action?: string; id?: string; userIds?: string[]; reason?: string; actorRole?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (body.action === "bulk_ban" && Array.isArray(body.userIds) && body.userIds.length > 0) {
    const reason = body.reason || "Kein Grund angegeben";
    const results: { userId: string; success: boolean; error?: string }[] = [];

    for (const userId of body.userIds) {
      try {
        const { data: currentProfile } = await supabaseAdmin
          .from("profiles")
          .select("role, banned_at")
          .eq("id", userId)
          .single();

        if (!currentProfile) {
          results.push({ userId, success: false, error: "Nutzer nicht gefunden." });
          continue;
        }

        if (actorRole === "MODERATOR" && (currentProfile.role === "ADMIN" || currentProfile.role === "MODERATOR")) {
          results.push({ userId, success: false, error: "MODERATOR darf ADMIN/MODERATOR nicht bannen." });
          continue;
        }

        const { error } = await supabaseAdmin
          .from("profiles")
          .update({ banned_at: new Date().toISOString(), ban_reason: reason })
          .eq("id", userId);

        if (error) {
          results.push({ userId, success: false, error: error.message });
          continue;
        }

        await supabaseAdmin.auth.admin.updateUserById(userId, { ban_duration: "876000h" });
        await writeAudit(supabaseAdmin, user.id, "user.ban", "user", userId, { field: "banned_at", from: currentProfile.banned_at, to: "banned", reason });

        results.push({ userId, success: true });
      } catch (e: any) {
        results.push({ userId, success: false, error: e?.message ?? "Unbekannter Fehler" });
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (body.action === "bulk_delete" && Array.isArray(body.userIds) && body.userIds.length > 0) {
    const results: { userId: string; success: boolean; error?: string }[] = [];

    for (const userId of body.userIds) {
      try {
        const { data: targetProfile } = await supabaseAdmin
          .from("profiles")
          .select("role")
          .eq("id", userId)
          .single();

        if (!targetProfile) {
          results.push({ userId, success: false, error: "Nutzer nicht gefunden." });
          continue;
        }

        if (actorRole === "MODERATOR" && (targetProfile.role === "ADMIN" || targetProfile.role === "MODERATOR")) {
          results.push({ userId, success: false, error: "MODERATOR darf ADMIN/MODERATOR nicht löschen." });
          continue;
        }

        const { error } = await supabaseAdmin
          .from("profiles")
          .update({ deleted_at: new Date().toISOString() })
          .eq("id", userId);

        if (error) {
          results.push({ userId, success: false, error: error.message });
          continue;
        }

        await writeAudit(supabaseAdmin, user.id, "user.delete", "user", userId, {});

        results.push({ userId, success: true });
      } catch (e: any) {
        results.push({ userId, success: false, error: e?.message ?? "Unbekannter Fehler" });
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
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

    const { data: targetUser } = await supabaseAdmin.auth.admin.getUserById(body.id);
    const targetEmail = targetUser?.user?.email ?? "";

    const smtpConfigured = !!(import.meta.env.SMTP_HOST || import.meta.env.RESEND_API_KEY || import.meta.env.SENDGRID_API_KEY);

    let emailSent = false;
    let emailError: string | null = null;

    if (smtpConfigured && import.meta.env.RESEND_API_KEY) {
      try {
        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${import.meta.env.RESEND_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: import.meta.env.EMAIL_FROM || "noreply@carp24.de",
            to: targetEmail,
            subject: "Ihr neues Passwort – Carp24 Fangbuch",
            html: `<p>Ihr Passwort wurde zurückgesetzt.</p><p><b>Neues Passwort:</b> <code>${newPassword}</code></p><p>Bitte ändern Sie das Passwort nach dem Login.</p>`,
          }),
        });
        emailSent = res.ok;
        if (!res.ok) emailError = `Resend API ${res.status}`;
      } catch (e: any) {
        emailError = e?.message ?? "Unbekannter Fehler";
      }
    }

    await writeAudit(supabaseAdmin, user.id, "user.reset_password", "user", body.id, { email_sent: emailSent, email_error: emailError });

    if (emailSent) {
      return new Response(JSON.stringify({ success: true, message: `Neues Passwort wurde an ${targetEmail} gesendet.` }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      success: true,
      message: "Passwort wurde zurückgesetzt. Bitte kontaktieren Sie den Support, um das neue Passwort zu erhalten.",
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ error: "Unbekannte Aktion." }), {
    status: 400,
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
  const { supabaseAdmin, user, actorRole } = auth;
  let body: { id?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Input-Validierung
  if (!body.id || !/^[0-9a-f-]{36}$/.test(body.id)) {
    return new Response(JSON.stringify({ error: "Ungültige User-ID." }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (body.role && !["USER", "MODERATOR", "ADMIN"].includes(body.role)) {
    return new Response(JSON.stringify({ error: "Ungültige Rolle." }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (body.ban_reason) {
    body.ban_reason = escHtml(String(body.ban_reason).slice(0, 500));
  }

  if (!body.id) {
    return new Response(JSON.stringify({ error: "ID erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: targetProfile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", body.id)
    .single();

  if (!targetProfile) {
    return new Response(JSON.stringify({ error: "Nutzer nicht gefunden." }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (actorRole === "MODERATOR" && (targetProfile.role === "ADMIN" || targetProfile.role === "MODERATOR")) {
    return new Response(JSON.stringify({ error: "MODERATOR darf ADMIN/MODERATOR nicht löschen." }), {
      status: 403,
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

  await writeAudit(supabaseAdmin, user.id, "user.delete", "user", body.id, {});

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};