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

  // FIX 3: Event VOR Verarbeitung speichern
  await supabaseAdmin.from("stripe_events").insert({
    id: event.id,
    type: event.type,
    status: "processing",
  });

  try {
    // Event-Typ verarbeiten
    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      const customerEmail = session.customer_email || session.customer_details?.email;

      if (customerEmail) {
        const { data: userData } = await supabaseAdmin.auth.admin.listUsers();
        const user = userData.users.find((u) => u.email === customerEmail);

        if (user) {
          await supabaseAdmin
            .from("profiles")
            .update({ is_pro: true })
            .eq("id", user.id);

          if (session.subscription) {
            const subscriptionId =
              typeof session.subscription === "string"
                ? session.subscription
                : session.subscription.id;
            const stripeSubscription =
              await stripe.subscriptions.retrieve(subscriptionId);

            await supabaseAdmin.from("subscriptions").upsert(
              {
                user_id: user.id,
                stripe_customer:
                  typeof stripeSubscription.customer === "string"
                    ? stripeSubscription.customer
                    : stripeSubscription.customer.id,
                plan: "PRO",
                status: "ACTIVE",
                active_until: stripeSubscription.current_period_end
                  ? new Date(stripeSubscription.current_period_end * 1000).toISOString()
                  : null,
              },
              { onConflict: "user_id" }
            );
          }
        }
      }
    }

    // FIX 2: Subscription-Kündigung / Status-Änderung → is_pro=false
    if (
      event.type === "customer.subscription.deleted" ||
      event.type === "customer.subscription.updated"
    ) {
      const subscription = event.data.object as Stripe.Subscription;

      const statusMap: Record<string, string> = {
        active: "ACTIVE",
        canceled: "CANCELED",
        past_due: "PAST_DUE",
        unpaid: "CANCELED",
        trialing: "ACTIVE",
        incomplete: "ACTIVE",
        incomplete_expired: "CANCELED",
        paused: "CANCELED",
      };
      const mappedStatus = statusMap[subscription.status] ?? "CANCELED";

      let shouldRevoke = false;
      if (event.type === "customer.subscription.deleted") {
        shouldRevoke = true;
      } else if (event.type === "customer.subscription.updated") {
        const status = subscription.status;
        if (status === "canceled" || status === "past_due" || status === "unpaid") {
          shouldRevoke = true;
        }
      }

      let customerEmail: string | null = null;
      let customerId: string | null = null;

      try {
        if (typeof subscription.customer === "string") {
          customerId = subscription.customer;
          const customer = await stripe.customers.retrieve(subscription.customer);
          if (!("deleted" in customer)) {
            customerEmail = customer.email ?? null;
          }
        } else {
          customerId = subscription.customer.id;
          customerEmail = subscription.customer.email ?? null;
        }
      } catch {
        // Kundenabruf fehlgeschlagen — keine E-Mail verfügbar
      }

      if (customerEmail) {
        const { data: userData } = await supabaseAdmin.auth.admin.listUsers();
        const user = userData.users.find((u) => u.email === customerEmail);

        if (user) {
          if (shouldRevoke) {
            await supabaseAdmin
              .from("profiles")
              .update({ is_pro: false })
              .eq("id", user.id);
          }

          await supabaseAdmin.from("subscriptions").upsert(
            {
              user_id: user.id,
              stripe_customer: customerId,
              status: mappedStatus,
              active_until: subscription.current_period_end
                ? new Date(subscription.current_period_end * 1000).toISOString()
                : null,
            },
            { onConflict: "user_id" }
          );
        }
      }
    }

    // Event als verarbeitet markieren
    await supabaseAdmin
      .from("stripe_events")
      .update({ status: "processed" })
      .eq("id", event.id);
  } catch {
    // Bei Fehler: Event als "error" markieren (kein Doppel-Processing)
    await supabaseAdmin
      .from("stripe_events")
      .update({ status: "error" })
      .eq("id", event.id);

    return new Response(JSON.stringify({ error: "Verarbeitung fehlgeschlagen." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
