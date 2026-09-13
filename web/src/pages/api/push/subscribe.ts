import { getSupabaseUrl, getSupabaseAnonKey, getSupabaseServiceKey } from "../../../lib/config";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";

export const prerender = false;

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const supabase = createServerClient(
    getSupabaseUrl(),
    getSupabaseAnonKey(),
    {
      cookies: {
        getAll() { return parseCookieHeader(request.headers.get("Cookie") ?? ""); },
        setAll() {},
      },
      auth: { storageKey: "sb-carp24-auth-token" },
    }
  );

  let user = locals.user;

  if (!user) {
    const { data: { user: ssrUser } } = await supabase.auth.getUser();
    if (ssrUser) user = ssrUser;
  }

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const body = await request.json();
  const { endpoint, keys } = body;

  if (!endpoint || !keys?.p256dh || !keys?.auth) {
    return new Response(JSON.stringify({ error: "Ungültige Daten." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error } = await supabase
    .from("push_subscriptions")
    .upsert({ user_id: user.id, endpoint, keys }, { onConflict: "endpoint" });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};