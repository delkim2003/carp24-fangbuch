import { getSupabaseUrl, getSupabaseAnonKey, getSupabaseServiceKey } from "../../../lib/config";
import { createClient } from "@supabase/supabase-js";
import { checkRateLimit } from "../../../lib/rate-limit";

export const prerender = false;

export async function POST({ request, locals }: { request: Request; locals: App.Locals }) {
  // Rate-Limit: 3 Löschversuche pro User pro Stunde
  const userId = locals.user?.id || "anonymous";
  const rl = checkRateLimit(`delete:${userId}`, 3, 3_600_000);
  if (rl) return rl;
  let user = locals.user;
  if (!user) {
    const authHeader = request.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.slice(7);
      const { createClient } = await import('@supabase/supabase-js');
      const supabaseAdmin = createClient(getSupabaseUrl(), getSupabaseServiceKey());
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

  let body: any;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.user_id || body.user_id !== user.id) {
    return new Response(JSON.stringify({ error: "Nicht autorisiert." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseAdmin = createClient(
    getSupabaseUrl(),
    getSupabaseServiceKey()
  );

  const { error } = await supabaseAdmin
    .from("profiles")
    .update({ deleted_at: new Date().toISOString() })
    .eq("id", user.id);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // GoTrue-User löschen (Art. 17 DSGVO)
  const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(user.id);
  if (authError) {
    console.error('GoTrue deleteUser failed:', authError.message);
    // Soft-Delete wurde bereits durchgeführt — nicht rollbacken
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
