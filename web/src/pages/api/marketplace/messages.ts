import { getSupabaseUrl, getSupabaseAnonKey, getSupabaseServiceKey } from "../../../lib/config";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { sendMail } from "../../../lib/mail";

export const prerender = false;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const json = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const getClient = (request: Request) =>
  createServerClient(getSupabaseUrl(), getSupabaseAnonKey(), {
    cookies: {
      getAll() {
        return parseCookieHeader(request.headers.get("Cookie") ?? "");
      },
      setAll() {},
    },
    auth: { storageKey: "sb-carp24-auth-token" },
  });

const photoOf = (photos: unknown): string | null =>
  Array.isArray(photos) && photos.length > 0 ? ((photos[0] as string) ?? null) : null;

export const GET = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const user = locals.user;
  if (!user) {
    return json({ error: "Nicht angemeldet." }, 401);
  }

  const supabase = getClient(request);
  const url = new URL(request.url);
  const mode = url.searchParams.get("mode");

  if (mode === "inbox") {
    const { data: messages, error } = await supabase
      .from("marketplace_messages")
      .select("id, listing_id, from_user, to_user, message, created_at, read_at")
      .or(`from_user.eq.${user.id},to_user.eq.${user.id}`)
      .order("created_at", { ascending: true });

    if (error) {
      return json({ error: error.message }, 500);
    }

    const threadMap = new Map<
      string,
      {
        listing_id: string;
        counterpart_id: string;
        last_message: string;
        created_at: string;
        unread_count: number;
      }
    >();

    for (const m of messages ?? []) {
      const counterpart_id = m.from_user === user.id ? m.to_user : m.from_user;
      const key = `${m.listing_id}:${counterpart_id}`;
      const isUnread = m.to_user === user.id && m.read_at == null ? 1 : 0;
      const existing = threadMap.get(key);
      if (!existing) {
        threadMap.set(key, {
          listing_id: m.listing_id,
          counterpart_id,
          last_message: m.message,
          created_at: m.created_at,
          unread_count: isUnread,
        });
      } else {
        if (m.created_at >= existing.created_at) {
          existing.last_message = m.message;
          existing.created_at = m.created_at;
        }
        existing.unread_count += isUnread;
      }
    }

    const threads = Array.from(threadMap.values());
    const listingIds = [...new Set(threads.map((t) => t.listing_id))];
    const counterpartIds = [...new Set(threads.map((t) => t.counterpart_id))];

    const listingMap = new Map<string, any>();
    if (listingIds.length > 0) {
      const { data: items } = await supabase
        .from("marketplace_items")
        .select("id, title, price, photos")
        .in("id", listingIds);
      for (const it of items ?? []) listingMap.set(it.id, it);
    }

    const profileMap = new Map<string, any>();
    if (counterpartIds.length > 0) {
      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, display_name")
        .in("id", counterpartIds);
      for (const p of profiles ?? []) profileMap.set(p.id, p);
    }

    const result = threads
      .map((t) => {
        const item = listingMap.get(t.listing_id);
        const profile = profileMap.get(t.counterpart_id);
        return {
          listing_id: t.listing_id,
          listing: {
            id: t.listing_id,
            title: item?.title ?? null,
            price: item?.price ?? null,
            photo: photoOf(item?.photos),
          },
          counterpart: {
            id: t.counterpart_id,
            display_name: profile?.display_name ?? null,
          },
          last_message: t.last_message,
          created_at: t.created_at,
          unread_count: t.unread_count,
        };
      })
      .sort((a, b) => (a.created_at < b.created_at ? 1 : -1));

    const unread_total = result.reduce((sum, t) => sum + t.unread_count, 0);

    return json({ threads: result, unread_total });
  }

  if (mode != null && mode !== "") {
    return json({ error: "Ungültiger mode." }, 400);
  }

  const listing_id = url.searchParams.get("listing_id");
  const with_user = url.searchParams.get("with_user");

  if (!listing_id || !UUID_RE.test(listing_id) || !with_user || !UUID_RE.test(with_user)) {
    return json({ error: "Ungültige Parameter." }, 400);
  }

  const { data: messages, error } = await supabase
    .from("marketplace_messages")
    .select("id, listing_id, from_user, to_user, message, created_at, read_at")
    .eq("listing_id", listing_id)
    .or(
      `and(from_user.eq.${user.id},to_user.eq.${with_user}),and(from_user.eq.${with_user},to_user.eq.${user.id})`
    )
    .order("created_at", { ascending: true });

  if (error) {
    return json({ error: error.message }, 500);
  }

  const { data: item } = await supabase
    .from("marketplace_items")
    .select("id, title, price, photos")
    .eq("id", listing_id)
    .single();

  const listing = {
    id: listing_id,
    title: item?.title ?? null,
    price: item?.price ?? null,
    photo: photoOf(item?.photos),
  };

  return json({ messages: messages ?? [], listing });
};

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const user = locals.user;
  if (!user) {
    return json({ error: "Nicht angemeldet." }, 401);
  }

  const supabase = getClient(request);
  const url = new URL(request.url);
  const mode = url.searchParams.get("mode");

  let body: any;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Ungültiger Body." }, 400);
  }

  if (mode === "read") {
    const { listing_id, with_user } = body;

    if (!listing_id || !UUID_RE.test(listing_id) || !with_user || !UUID_RE.test(with_user)) {
      return json({ error: "Ungültige Parameter." }, 400);
    }

    const { error } = await supabase
      .from("marketplace_messages")
      .update({ read_at: new Date().toISOString() })
      .eq("to_user", user.id)
      .eq("from_user", with_user)
      .eq("listing_id", listing_id)
      .is("read_at", null);

    if (error) {
      return json({ error: error.message }, 500);
    }

    return json({ ok: true });
  }

  if (mode != null && mode !== "") {
    return json({ error: "Ungültiger mode." }, 400);
  }

  const { listing_id, to_user, message } = body;

  if (!listing_id || typeof listing_id !== "string" || !UUID_RE.test(listing_id)) {
    return json({ error: "Ungültige listing_id." }, 400);
  }

  if (!to_user || typeof to_user !== "string" || !UUID_RE.test(to_user)) {
    return json({ error: "Ungültige to_user." }, 400);
  }

  const text = typeof message === "string" ? message.trim() : "";
  if (text.length < 3 || text.length > 2000) {
    return json({ error: "Nachricht muss zwischen 3 und 2000 Zeichen lang sein." }, 400);
  }

  const { data: item, error: itemError } = await supabase
    .from("marketplace_items")
    .select("user_id, title")
    .eq("id", listing_id)
    .single();

  if (itemError || !item) {
    return json({ error: "Anzeige nicht gefunden." }, 404);
  }

  if (to_user === user.id) {
    return json({ error: "Du kannst dir nicht selbst schreiben." }, 400);
  }

  if (to_user !== item.user_id && item.user_id !== user.id) {
    return json({ error: "Ungültiger Empfänger." }, 400);
  }

  const { error: insertError } = await supabase.from("marketplace_messages").insert({
    listing_id,
    from_user: user.id,
    to_user,
    message: text,
  });

  if (insertError) {
    return json({ error: insertError.message }, 500);
  }

  try {
    const supabaseAdmin = createClient(getSupabaseUrl(), getSupabaseServiceKey());
    const { data: ownerData } = await supabaseAdmin.auth.admin.getUserById(to_user);
    const email = ownerData?.user?.email;
    if (email) {
      const { data: nameRow } = await supabaseAdmin
        .from("profiles")
        .select("display_name")
        .eq("id", to_user)
        .single();
      const displayName =
        nameRow?.display_name ?? ownerData?.user?.user_metadata?.display_name ?? "";
      const origin = url.origin;
      const excerpt = text.length > 200 ? text.slice(0, 200) + "…" : text;
      const mailText =
        `Hallo ${displayName ?? ""},\n\n` +
        `du hast eine neue Nachricht auf carp24:\n\n` +
        `"${excerpt}"\n\n` +
        `Zur Konversation: ${origin}/nachrichten?listing_id=${listing_id}&with_user=${user.id}\n\n` +
        `Freundliche Grüße\nDein Carp24-Team`;
      const result = await sendMail(email, "Neue Nachricht auf carp24", mailText);
      if (!result.ok) {
        console.error("[marketplace/messages] Mailfehler:", result.error);
      }
    }
  } catch (e) {
    console.error("[marketplace/messages] Mailfehler:", e);
  }

  return json({ ok: true }, 201);
};
