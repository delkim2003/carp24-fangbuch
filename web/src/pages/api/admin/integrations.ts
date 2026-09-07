import { getAdminClient } from "./_auth";

export const prerender = false;

let openrouter: boolean | null = null;

export const GET = async ({ locals }: { locals: App.Locals }) => {
  const auth = await getAdminClient(locals);
  if ("error" in auth) {
    return new Response(JSON.stringify({ error: auth.error }), {
      status: auth.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { supabaseAdmin } = auth;

  if (!openrouter) {
    try {
      const { data } = await supabaseAdmin
        .from("app_settings")
        .select("value")
        .eq("key", "openrouter_key")
        .single();
      openrouter = !!(data?.value?.key);
    } catch {
      openrouter = false;
    }
  }

  return new Response(
    JSON.stringify({
      stripe_keys: !!(import.meta.env.STRIPE_SECRET_KEY && import.meta.env.STRIPE_WEBHOOK_SECRET),
      openrouter,
      vapid: !!(import.meta.env.VAPID_PUBLIC_KEY && import.meta.env.VAPID_PRIVATE_KEY),
      service_role: !!import.meta.env.SUPABASE_SERVICE_ROLE_KEY,
      smtp: true,
      realtime: !!import.meta.env.PUBLIC_SUPABASE_URL,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
};