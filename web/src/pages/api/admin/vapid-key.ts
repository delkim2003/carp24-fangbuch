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
  const envPublicKey = import.meta.env.VAPID_PUBLIC_KEY;
  const envPrivateKey = import.meta.env.VAPID_PRIVATE_KEY;
  const envSubject = import.meta.env.VAPID_SUBJECT;

  let dbConfig: { public_key?: string; private_key?: string; subject?: string } | null = null;
  const { data } = await supabaseAdmin
    .from("app_settings")
    .select("value")
    .eq("key", "vapid_key")
    .single();

  if (data?.value?.public_key || data?.value?.private_key) {
    dbConfig = data.value;
  }

  const envConfigured = !!(envPublicKey && envPrivateKey);
  const dbConfigured = !!(dbConfig?.public_key && dbConfig?.private_key);
  const configured = envConfigured || dbConfigured;

  return new Response(
    JSON.stringify({
      configured,
      source: envConfigured ? "env" : dbConfigured ? "db" : null,
      has_public_key: !!(envPublicKey || dbConfig?.public_key),
      has_private_key: !!(envPrivateKey || dbConfig?.private_key),
      masked_public_key: envPublicKey
        ? envPublicKey.slice(0, 12) + "…"
        : dbConfig?.public_key
          ? dbConfig.public_key.slice(0, 12) + "…"
          : null,
      masked_private_key: envPrivateKey
        ? envPrivateKey.slice(0, 6) + "…"
        : dbConfig?.private_key
          ? dbConfig.private_key.slice(0, 6) + "…"
          : null,
      subject: envSubject || dbConfig?.subject || null,
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
  let body: { public_key?: string; private_key?: string; subject?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const publicKey = body.public_key?.trim() ?? "";
  const privateKey = body.private_key?.trim() ?? "";
  const subject = body.subject?.trim() ?? "";

  // If all values are empty, delete the stored config
  if (!publicKey && !privateKey && !subject) {
    const { error: delError } = await supabaseAdmin
      .from("app_settings")
      .delete()
      .eq("key", "vapid_key");

    if (delError) {
      return new Response(JSON.stringify({ error: delError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    await supabaseAdmin.from("admin_audit_log").insert({
      actor_id: user.id,
      action: "vapid_key.delete",
      target_type: "settings",
      target_id: "vapid_key",
      details: {},
    });

    return new Response(JSON.stringify({ ok: true, configured: false }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Build the value object — only store non-empty values
  const value: Record<string, string> = {};
  if (publicKey) value.public_key = publicKey;
  if (privateKey) value.private_key = privateKey;
  if (subject) value.subject = subject;

  const { error } = await supabaseAdmin
    .from("app_settings")
    .upsert(
      {
        key: "vapid_key",
        value,
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
    action: "vapid_key.update",
    target_type: "settings",
    target_id: "vapid_key",
    details: { has_public_key: !!publicKey, has_private_key: !!privateKey, has_subject: !!subject },
  });

  return new Response(JSON.stringify({ ok: true, configured: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};