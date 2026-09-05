import { createServerClient } from "@supabase/ssr";

export const prerender = false;

export const POST = async ({ request, cookies }: { request: Request; cookies: any }) => {
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
          cookiesToSet.forEach(({ name, value, options }: any) => {
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

  let body: any;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültiger Body." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { item_id, message } = body;

  if (
    !item_id ||
    typeof item_id !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item_id)
  ) {
    return new Response(JSON.stringify({ error: "Ungültige item_id." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!message || typeof message !== "string" || message.length < 3 || message.length > 2000) {
    return new Response(JSON.stringify({ error: "Nachricht muss zwischen 3 und 2000 Zeichen lang sein." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: item, error: itemError } = await supabase
    .from("marketplace_items")
    .select("user_id")
    .eq("id", item_id)
    .single();

  if (itemError || !item) {
    return new Response(JSON.stringify({ error: "Anzeige nicht gefunden." }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (item.user_id === user.id) {
    return new Response(
      JSON.stringify({ error: "Du kannst nicht deine eigene Anzeige kontaktieren." }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  const { error: insertError } = await supabase.from("marketplace_contacts").insert({
    item_id,
    from_user: user.id,
    to_user: item.user_id,
    message,
  });

  if (insertError) {
    return new Response(JSON.stringify({ error: insertError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 201,
    headers: { "Content-Type": "application/json" },
  });
};
