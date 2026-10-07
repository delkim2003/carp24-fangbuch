import { getSupabaseUrl, getSupabaseAnonKey, getSupabaseServiceKey } from "../../../lib/config";
import { createClient } from "@supabase/supabase-js";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";
import { csrfGuard } from "../admin/_csrf";
import { sendReportReceived } from "../../../lib/mail";

export const prerender = false;

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const csrf = csrfGuard(request);
  if (csrf) return csrf;

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

  let body: { reason?: string; reportId?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const reason = typeof body.reason === "string" ? body.reason : "";
  const reportId = typeof body.reportId === "string" ? body.reportId : "";

  const supabaseAdmin = createClient(getSupabaseUrl(), getSupabaseServiceKey());
  try {
    const { data: userData } = await supabaseAdmin.auth.admin.getUserById(user.id);
    const email = userData?.user?.email;
    if (email) {
      const r = await sendReportReceived(email, reason);
      if (reportId) {
        await supabaseAdmin.from("report_mails").insert({
          report_id: reportId,
          kind: "ack",
          status: r.ok ? "sent" : "failed",
          error: r.error,
        });
      }
    }
  } catch (e) {
    const errMsg = String((e as Error).message);
    if (reportId) {
      try {
        await supabaseAdmin.from("report_mails").insert({
          report_id: reportId,
          kind: "ack",
          status: "failed",
          error: errMsg,
        });
      } catch {}
    }
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
