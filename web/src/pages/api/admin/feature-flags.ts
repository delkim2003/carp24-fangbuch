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