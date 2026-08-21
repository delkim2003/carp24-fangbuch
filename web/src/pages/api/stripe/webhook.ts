import Stripe from "stripe";
import { createClient } from "@supabase/supabase-js";

export const prerender = false;

export const POST = async ({ request }) => {
  const secretKey = import.meta.env.STRIPE_SECRET_KEY;
  const webhookSecret = import.meta.env.STRIPE_WEBHOOK_SECRET;

  if (!secretKey || !webhookSecret) {
    return new Response(JSON.stringify({ error: "Stripe ist noch nicht konfiguriert." }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  const payload = await request.text();
  const sig = request.headers.get("stripe-signature");

  if (!sig) {
    return new Response(JSON.stringify({ error: "Fehlende Stripe-Signatur." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const stripe = new Stripe(secretKey);

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(payload, sig, webhookSecret);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unbekannter Fehler";
    return new Response(JSON.stringify({ error: `Webhook-Signatur ungültig: ${message}` }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseAdmin = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY
  );

  // Idempotenz: Prüfe ob Event bereits verarbeitet wurde
  const { data: existing } = await supabaseAdmin
    .from("stripe_events")
    .select("id")
    .eq("id", event.id)
    .single();

  if (existing) {
    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Event-Typ verarbeiten
  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;
    const customerEmail = session.customer_email || session.customer_details?.email;

    if (customerEmail) {
      // User-ID über E-Mail aus auth.users ermitteln
      const { data: userData } = await supabaseAdmin.auth.admin.listUsers();
      const user = userData.users.find((u) => u.email === customerEmail);

      if (user) {
        await supabaseAdmin
          .from("profiles")
          .update({ is_pro: true })
          .eq("id", user.id);
      }
    }
  }

  // TODO: customer.subscription.deleted → is_pro=false (Kündigung) — implementieren wenn Abo-Produkt final

  // Event speichern (Idempotenz)
  await supabaseAdmin.from("stripe_events").insert({
    id: event.id,
    type: event.type,
    status: "received",
  });

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
