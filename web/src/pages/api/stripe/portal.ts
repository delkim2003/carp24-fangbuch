import Stripe from "stripe";
import { createServerClient } from "@supabase/ssr";

export const prerender = false;

export const POST = async ({ request, cookies }) => {
  const secretKey = import.meta.env.STRIPE_SECRET_KEY;
  if (!secretKey) {
    return new Response(JSON.stringify({ error: "Stripe ist noch nicht konfiguriert." }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          const header = request.headers.get("cookie");
          if (!header) return [];
          return header
            .split(";")
            .map((pair) => {
              const idx = pair.indexOf("=");
              if (idx === -1) return null;
              return {
                name: pair.slice(0, idx).trim(),
                value: pair.slice(idx + 1).trim(),
              };
            })
            .filter(Boolean) as { name: string; value: string }[];
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookies.set(name, value, options);
          });
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: subscription } = await supabase
    .from("subscriptions")
    .select("stripe_customer")
    .eq("user_id", user.id)
    .maybeSingle();

  const stripeCustomer = subscription?.stripe_customer;

  if (!stripeCustomer) {
    return new Response(JSON.stringify({ error: "Kein aktives Abo gefunden." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const stripe = new Stripe(secretKey);
  const origin = request.headers.get("origin") || new URL(request.url).origin;

  const session = await stripe.billingPortal.sessions.create({
    customer: stripeCustomer,
    return_url: `${origin}/premium/`,
  });

  return new Response(JSON.stringify({ url: session.url }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};