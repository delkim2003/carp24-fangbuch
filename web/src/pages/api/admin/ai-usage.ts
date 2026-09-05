import { createClient } from "@supabase/supabase-js";

export const prerender = false;

export const GET = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  let user = locals.user;
  if (!user) {
    const authHeader = request.headers.get("authorization");
    if (authHeader && authHeader.startsWith("Bearer ")) {
      const token = authHeader.slice(7);
      const supabaseAdmin = createClient(import.meta.env.PUBLIC_SUPABASE_URL, import.meta.env.SUPABASE_SERVICE_ROLE_KEY);
      const { data: { user: tokenUser } } = await supabaseAdmin.auth.getUser(token);
      if (tokenUser) user = tokenUser;
    }
  }
  if (!user) return new Response(JSON.stringify({ error: "Nicht angemeldet." }), { status: 401 });

  const supabaseAdmin = createClient(import.meta.env.PUBLIC_SUPABASE_URL, import.meta.env.SUPABASE_SERVICE_ROLE_KEY);
  const { data: profile } = await supabaseAdmin.from("profiles").select("role").eq("id", user.id).single();
  if (profile?.role !== "ADMIN") return new Response(JSON.stringify({ error: "Nur für Admins." }), { status: 403 });

  // Get all users with their monthly AI usage
  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const monthStartStr = monthStart.toISOString().slice(0, 10);

  const { data: usage } = await supabaseAdmin
    .from("ai_usage")
    .select("user_id, count, request_date")
    .gte("request_date", monthStartStr);

  // Aggregate by user
  const userUsage: Record<string, number> = {};
  if (usage) {
    for (const row of usage) {
      userUsage[row.user_id] = (userUsage[row.user_id] || 0) + row.count;
    }
  }

  // Get user emails
  const userIds = Object.keys(userUsage);
  const userEmails: Record<string, string> = {};
  if (userIds.length > 0) {
    const { data: profiles } = await supabaseAdmin
      .from("profiles")
      .select("id, email")
      .in("id", userIds);
    if (profiles) {
      for (const p of profiles) userEmails[p.id] = p.email || "unbekannt";
    }
  }

  const result = Object.entries(userUsage).map(([uid, count]) => ({
    user_id: uid,
    email: userEmails[uid] || "unbekannt",
    count,
  })).sort((a, b) => b.count - a.count);

  return new Response(JSON.stringify({ users: result }), { status: 200, headers: { "Content-Type": "application/json" } });
};

export const DELETE = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  let user = locals.user;
  if (!user) {
    const authHeader = request.headers.get("authorization");
    if (authHeader && authHeader.startsWith("Bearer ")) {
      const token = authHeader.slice(7);
      const supabaseAdmin = createClient(import.meta.env.PUBLIC_SUPABASE_URL, import.meta.env.SUPABASE_SERVICE_ROLE_KEY);
      const { data: { user: tokenUser } } = await supabaseAdmin.auth.getUser(token);
      if (tokenUser) user = tokenUser;
    }
  }
  if (!user) return new Response(JSON.stringify({ error: "Nicht angemeldet." }), { status: 401 });

  const supabaseAdmin = createClient(import.meta.env.PUBLIC_SUPABASE_URL, import.meta.env.SUPABASE_SERVICE_ROLE_KEY);
  const { data: profile } = await supabaseAdmin.from("profiles").select("role").eq("id", user.id).single();
  if (profile?.role !== "ADMIN") return new Response(JSON.stringify({ error: "Nur für Admins." }), { status: 403 });

  let body: { email?: string };
  try { body = await request.json(); } catch { return new Response(JSON.stringify({ error: "Ungültig." }), { status: 400 }); }

  const email = body.email?.trim();
  if (!email) return new Response(JSON.stringify({ error: "E-Mail erforderlich." }), { status: 400 });

  // Find user by email
  const { data: targetProfile } = await supabaseAdmin.from("profiles").select("id").eq("email", email).single();
  if (!targetProfile) return new Response(JSON.stringify({ error: "Nutzer nicht gefunden." }), { status: 404 });

  // Delete usage for this month
  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const monthStartStr = monthStart.toISOString().slice(0, 10);

  const { error } = await supabaseAdmin
    .from("ai_usage")
    .delete()
    .eq("user_id", targetProfile.id)
    .gte("request_date", monthStartStr);

  if (error) return new Response(JSON.stringify({ error: "Fehler beim Reset." }), { status: 500 });

  return new Response(JSON.stringify({ ok: true, message: `KI-Nutzung für ${email} zurückgesetzt.` }), { status: 200, headers: { "Content-Type": "application/json" } });
};
