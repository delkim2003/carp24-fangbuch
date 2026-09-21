import { getSupabaseUrl, getSupabaseAnonKey, getSupabaseServiceKey } from "../../../lib/config";
import { createClient } from "@supabase/supabase-js";
import { csrfGuard } from "./_csrf";

export const prerender = false;

async function guard(locals: App.Locals) {
  const user = locals.user;
  if (!user) return { error: "Nicht angemeldet.", status: 401 };

  const role = locals.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") return { error: "Keine Berechtigung.", status: 403 };

  const supabaseAdmin = createClient(
    getSupabaseUrl(),
    getSupabaseServiceKey()
  );

  return { supabaseAdmin, user };
}

export const GET = async ({ locals }: { locals: App.Locals }) => {
  const g = await guard(locals);
  if ("error" in g) {
    return new Response(JSON.stringify({ error: g.error }), {
      status: g.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { supabaseAdmin } = g;

  const { data, error } = await supabaseAdmin
    .from("app_settings")
    .select("value")
    .eq("key", "maintenance")
    .single();

  if (error) {
    console.error("[admin]", error);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const value = data?.value ?? { enabled: false, message: "" };
  return new Response(JSON.stringify(value), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export const PATCH = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;
  const g = await guard(locals);
  if ("error" in g) {
    return new Response(JSON.stringify({ error: g.error }), {
      status: g.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { supabaseAdmin, user } = g;
  let body: { enabled?: boolean; message?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (typeof body.enabled !== "boolean") {
    return new Response(JSON.stringify({ error: "enabled (boolean) erforderlich." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const value = { enabled: body.enabled, message: body.message ?? "" };

  const { error } = await supabaseAdmin
    .from("app_settings")
    .upsert({ key: "maintenance", value, updated_at: new Date().toISOString() }, { onConflict: "key" });

  if (error) {
    console.error("[admin]", error);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  await supabaseAdmin.from("admin_audit_log").insert({
    actor_id: user.id,
    action: "settings.maintenance",
    target_type: "settings",
    target_id: "maintenance",
    details: { enabled: body.enabled },
  });

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
