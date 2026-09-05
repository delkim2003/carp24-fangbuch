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

export const GET = async ({ request }: { request: Request }) => {
  const g = await guard(request);
  if ("error" in g) {
    return new Response(JSON.stringify({ error: g.error }), {
      status: g.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { supabaseAdmin } = g;

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