import { getSupabaseUrl, getSupabaseAnonKey, getSupabaseServiceKey } from "../../../lib/config";
import { createClient } from "@supabase/supabase-js";
import { csrfGuard } from "./_csrf";

export const prerender = false;

export const GET = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  let user = locals.user;
  if (!user) {
    const authHeader = request.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { createClient } = await import('@supabase/supabase-js');
      const supabaseAdmin = createClient(getSupabaseUrl(), getSupabaseServiceKey());
      const { data: { user: tokenUser } } = await supabaseAdmin.auth.getUser(token);
      if (tokenUser) user = tokenUser;
    }
  }

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseAdmin = createClient(
    getSupabaseUrl(),
    getSupabaseServiceKey()
  );

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") {
    return new Response(JSON.stringify({ error: "Keine Berechtigung." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data, error } = await supabaseAdmin
    .from("feature_flags")
    .select("key, value")
    .order("key");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const flags: Record<string, boolean> = {};
  for (const row of data ?? []) {
    flags[row.key] = row.value;
  }

  return new Response(JSON.stringify(flags), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const PATCH = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  let user = locals.user;
  if (!user) {
    const authHeader = request.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { createClient } = await import('@supabase/supabase-js');
      const supabaseAdmin = createClient(getSupabaseUrl(), getSupabaseServiceKey());
      const { data: { user: tokenUser } } = await supabaseAdmin.auth.getUser(token);
      if (tokenUser) user = tokenUser;
    }
  }

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const csrf = csrfGuard(request);
  if (csrf) return csrf;

  const supabaseAdmin = createClient(
    getSupabaseUrl(),
    getSupabaseServiceKey()
  );

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") {
    return new Response(JSON.stringify({ error: "Keine Berechtigung." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: Record<string, boolean>;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const allowedKeys = ["registration_enabled", "chat_enabled", "marketplace_enabled"];
  const updates: { key: string; value: boolean }[] = [];

  for (const key of allowedKeys) {
    if (typeof body[key] === "boolean") {
      updates.push({ key, value: body[key] });
    }
  }

  if (updates.length === 0) {
    return new Response(JSON.stringify({ error: "Keine gültigen Flags übermittelt." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const now = new Date().toISOString();

  for (const update of updates) {
    const { error } = await supabaseAdmin
      .from("feature_flags")
      .upsert({
        key: update.key,
        value: update.value,
        updated_at: now,
        updated_by: user.id,
      }, { onConflict: "key" });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    await supabaseAdmin.from("admin_audit_log").insert({
      actor_id: user.id,
      action: "feature_flags.update",
      target_type: "feature_flags",
      target_id: update.key,
      details: { value: update.value },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};