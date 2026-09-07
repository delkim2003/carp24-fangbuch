import { getAdminClient } from "./_auth";
import { csrfGuard } from "./_csrf";

export const prerender = false;

export const GET = async ({ locals }: { locals: App.Locals }) => {
  const auth = await getAdminClient(locals);
  if ("error" in auth) {
    return new Response(JSON.stringify({ error: auth.error }), {
      status: auth.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { supabaseAdmin } = auth;

  // Check env first, then DB
  const envKey = import.meta.env.OPENROUTER_API_KEY;

  let dbKey: string | null = null;
  const { data } = await supabaseAdmin
    .from("app_settings")
    .select("value")
    .eq("key", "openrouter_key")
    .single();

  if (data?.value?.key) {
    dbKey = data.value.key;
  }

  const configured = !!(envKey || dbKey);

  // Never return the actual key — just whether it's set
  return new Response(
    JSON.stringify({
      configured,
      source: envKey ? "env" : dbKey ? "db" : null,
      masked_key: envKey
        ? envKey.slice(0, 8) + "…"
        : dbKey
          ? dbKey.slice(0, 8) + "…"
          : null,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
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
  let body: { key?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const apiKey = body.key?.trim() ?? "";

  if (!apiKey) {
    // Allow empty key to clear the stored value
    const { error: delError } = await supabaseAdmin
      .from("app_settings")
      .delete()
      .eq("key", "openrouter_key");

    if (delError) {
      return new Response(JSON.stringify({ error: delError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    await supabaseAdmin.from("admin_audit_log").insert({
      actor_id: user.id,
      action: "openrouter_key.delete",
      target_type: "settings",
      target_id: "openrouter_key",
      details: {},
    });

    return new Response(JSON.stringify({ ok: true, configured: false }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!apiKey.startsWith("sk-or-")) {
    return new Response(
      JSON.stringify({ error: "Ungültiges Format: OpenRouter-Keys beginnen mit 'sk-or-'." }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  const { error } = await supabaseAdmin
    .from("app_settings")
    .upsert(
      {
        key: "openrouter_key",
        value: { key: apiKey },
        updated_at: new Date().toISOString(),
      },
      { onConflict: "key" }
    );

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  await supabaseAdmin.from("admin_audit_log").insert({
    actor_id: user.id,
    action: "openrouter_key.update",
    target_type: "settings",
    target_id: "openrouter_key",
    details: { configured: true },
  });

  return new Response(JSON.stringify({ ok: true, configured: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};