import { createClient } from "@supabase/supabase-js";
import { csrfGuard } from "./_csrf";

export const prerender = false;

export async function getServerSideProps({ locals }: { locals: App.Locals }) {
  const user = locals.user;
  if (!user) return { props: { error: "Nicht angemeldet.", status: 401 } };

  const supabaseAdmin = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY
  );

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") return { props: { error: "Keine Berechtigung.", status: 403 } };

  return { props: { supabaseAdmin, user } };
}

export const GET = async ({ locals }: { locals: App.Locals }) => {
  const { supabaseAdmin } = await getServerSideProps({ locals });
  if ("error" in supabaseAdmin) {
    return new Response(JSON.stringify({ error: supabaseAdmin.error }), {
      status: supabaseAdmin.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Check env first, then DB
  const envSecretKey = import.meta.env.STRIPE_SECRET_KEY;
  const envWebhookSecret = import.meta.env.STRIPE_WEBHOOK_SECRET;
  const envPriceId = import.meta.env.STRIPE_PRICE_ID;

  let dbConfig: { secret_key?: string; webhook_secret?: string; price_id?: string } | null = null;
  const { data } = await supabaseAdmin
    .from("app_settings")
    .select("value")
    .eq("key", "stripe_key")
    .single();

  if (data?.value?.secret_key || data?.value?.webhook_secret) {
    dbConfig = data.value;
  }

  const envConfigured = !!(envSecretKey && envWebhookSecret);
  const dbConfigured = !!(dbConfig?.secret_key && dbConfig?.webhook_secret);
  const configured = envConfigured || dbConfigured;

  return new Response(
    JSON.stringify({
      configured,
      source: envConfigured ? "env" : dbConfigured ? "db" : null,
      has_secret_key: !!(envSecretKey || dbConfig?.secret_key),
      has_webhook_secret: !!(envWebhookSecret || dbConfig?.webhook_secret),
      has_price_id: !!(envPriceId || dbConfig?.price_id),
      masked_secret_key: envSecretKey
        ? envSecretKey.slice(0, 8) + "…"
        : dbConfig?.secret_key
          ? dbConfig.secret_key.slice(0, 8) + "…"
          : null,
      masked_webhook_secret: envWebhookSecret
        ? envWebhookSecret.slice(0, 8) + "…"
        : dbConfig?.webhook_secret
          ? dbConfig.webhook_secret.slice(0, 8) + "…"
          : null,
      price_id: envPriceId || dbConfig?.price_id || null,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
};

export const PATCH = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;
  const { supabaseAdmin, user } = await getServerSideProps({ locals });
  if ("error" in supabaseAdmin) {
    return new Response(JSON.stringify({ error: supabaseAdmin.error }), {
      status: supabaseAdmin.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  let body: { secret_key?: string; webhook_secret?: string; price_id?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const secretKey = body.secret_key?.trim() ?? "";
  const webhookSecret = body.webhook_secret?.trim() ?? "";
  const priceId = body.price_id?.trim() ?? "";

  // If all values are empty, delete the stored config
  if (!secretKey && !webhookSecret && !priceId) {
    const { error: delError } = await supabaseAdmin
      .from("app_settings")
      .delete()
      .eq("key", "stripe_key");

    if (delError) {
      return new Response(JSON.stringify({ error: delError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    await supabaseAdmin.from("admin_audit_log").insert({
      actor_id: user.id,
      action: "stripe_key.delete",
      target_type: "settings",
      target_id: "stripe_key",
      details: {},
    });

    return new Response(JSON.stringify({ ok: true, configured: false }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Build the value object — only store non-empty values
  const value: Record<string, string> = {};
  if (secretKey) value.secret_key = secretKey;
  if (webhookSecret) value.webhook_secret = webhookSecret;
  if (priceId) value.price_id = priceId;

  const { error } = await supabaseAdmin
    .from("app_settings")
    .upsert(
      {
        key: "stripe_key",
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
    action: "stripe_key.update",
    target_type: "settings",
    target_id: "stripe_key",
    details: { has_secret_key: !!secretKey, has_webhook_secret: !!webhookSecret, has_price_id: !!priceId },
  });

  return new Response(JSON.stringify({ ok: true, configured: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};