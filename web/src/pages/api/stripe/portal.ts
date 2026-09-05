import Stripe from "stripe";

export const prerender = false;

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const secretKey = import.meta.env.STRIPE_SECRET_KEY;
  if (!secretKey) {
    return new Response(JSON.stringify({ error: "Stripe ist noch nicht konfiguriert." }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  let user = locals.user;

  if (!user) {
    const authHeader = request.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { createClient } = await import('@supabase/supabase-js');
      const supabaseAdmin = createClient(import.meta.env.PUBLIC_SUPABASE_URL, import.meta.env.SUPABASE_SERVICE_ROLE_KEY);
      const { data: { user: tokenUser } } = await supabaseAdmin.auth.getUser(token);
      if (tokenUser) user = tokenUser;
    }
  }

  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseAdmin = createClient(import.meta.env.PUBLIC_SUPABASE_URL, import.meta.env.SUPABASE_SERVICE_ROLE_KEY);

  const { data: subscription } = await supabaseAdmin
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