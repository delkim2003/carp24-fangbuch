import { getSupabaseUrl, getSupabaseServiceKey } from "../../../lib/config";
import { createClient } from "@supabase/supabase-js";
import { sendMail } from "../../../lib/mail";

export const prerender = false;

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const user = locals.user;
  if (!user) {
    return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await request.json();
    const itemId = typeof body?.item_id === "string" ? body.item_id : "";

    const supabaseAdmin = createClient(getSupabaseUrl(), getSupabaseServiceKey());

    const { data: item } = await supabaseAdmin
      .from("marketplace_items")
      .select("id,user_id,title")
      .eq("id", itemId)
      .single();

    if (!item) {
      return new Response(JSON.stringify({ error: "Nicht gefunden" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (item.user_id !== user.id) {
      return new Response(JSON.stringify({ error: "Nicht erlaubt" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: ownerData } = await supabaseAdmin.auth.admin.getUserById(item.user_id);
    const email = ownerData?.user?.email;
    if (email) {
      await sendMail(
        email,
        "Deine Anzeige wird geprüft – carp24 Marktplatz",
        "Guten Tag,\n\n" +
          item.title +
          "\n\nDeine Anzeige ist bei uns eingegangen und wird geprüft (DSGVO/Foto-Check). Du bekommst Bescheid, sobald sie freigegeben oder abgelehnt wurde.\n\n" +
          "Freundliche Grüße\n" +
          "Ihr Carp24-Team",
      );
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[marketplace]", e);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
};
