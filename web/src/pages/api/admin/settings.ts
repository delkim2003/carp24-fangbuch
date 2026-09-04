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
        secure: false,
      },
    },
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

  const { data, error } = await supabaseAdmin
    .from("app_settings")
    .select("value")
    .eq("key", "maintenance")
    .single();

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
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
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  await supabaseAdmin.from("admin_audit_log").insert({
    actor_id: session.user.id,
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
