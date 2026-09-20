import { getSupabaseUrl, getSupabaseAnonKey } from "../../../lib/config";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";

export const prerender = false;

const rateLimitMap = new Map<string, number>();

async function getApiKey(supabase: any): Promise<string | null> {
  const envKey = process.env.OPENROUTER_API_KEY;
  if (envKey) return envKey;
  try {
    const { data } = await supabase
      .from("app_settings")
      .select("value")
      .eq("key", "openrouter_key")
      .single();
    return data?.value?.key || null;
  } catch {
    return null;
  }
}

export const POST = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
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

  const userId = user.id;
  const isPro = (locals as any).isPro ?? false;
  const userRole = (locals as any).role ?? "USER";
  const isAdmin = userRole === "ADMIN" || userRole === "MODERATOR";

  let body: { message?: string; _check?: boolean };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Ungültige Anfrage." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (body._check) {
    if (!isPro) {
      return new Response(JSON.stringify({ remaining: 0 }), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    if (isAdmin) {
      return new Response(JSON.stringify({ remaining: 999 }), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    const { data: monthlyUsage } = await supabase.rpc("get_ai_usage_monthly", { p_user_id: userId });
    const used = monthlyUsage || 0;
    return new Response(JSON.stringify({ remaining: Math.max(0, 50 - used) }), { status: 200, headers: { "Content-Type": "application/json" } });
  }

  if (!isPro) {
    return new Response(
      JSON.stringify({ error: "Nur für Premium-Mitglieder verfügbar. Jetzt upgraden: /premium" }),
      { status: 403, headers: { "Content-Type": "application/json" } }
    );
  }

  let remaining = 999;
  if (!isAdmin) {
    const { data: monthlyUsage } = await supabase.rpc("get_ai_usage_monthly", { p_user_id: userId });
    const used = monthlyUsage || 0;
    remaining = Math.max(0, 50 - used);
    if (used >= 50) {
      return new Response(
        JSON.stringify({ error: "Monatslimit erreicht (50/Monat). Nächster Monat geht es weiter.", remaining: 0 }),
        { status: 429, headers: { "Content-Type": "application/json" } }
      );
    }
  }

  const now = Date.now();
  const lastRequest = rateLimitMap.get(userId);
  if (lastRequest && now - lastRequest < 3_000) {
    return new Response(JSON.stringify({ error: "Bitte kurz warten." }), { status: 429, headers: { "Content-Type": "application/json" } });
  }
  rateLimitMap.set(userId, now);

  const apiKey = await getApiKey(supabase);
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "KI-Assistent ist nicht konfiguriert." }),
      { status: 503, headers: { "Content-Type": "application/json" } }
    );
  }

  const message = body.message?.trim();
  if (!message || message.length > 500) {
    return new Response(JSON.stringify({ error: "Nachricht erforderlich (max. 500 Zeichen)." }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const { data: catches } = await supabase
    .from("catches")
    .select("caught_at, weight_kg, species, water_id, weather_code, temperature_2m, pressure_msl, wind_speed_10m, bait, method, notes")
    .eq("user_id", userId)
    .is("deleted_at", null)
    .order("caught_at", { ascending: false })
    .limit(20);

  let contextStr = "Keine Fänge vorhanden.";
  if (catches && catches.length > 0) {
    contextStr = catches.map((c: any) => {
      const date = c.caught_at ? new Date(c.caught_at).toLocaleDateString("de-DE") : "?";
      const kg = c.weight_kg ? c.weight_kg + " kg" : "?";
      const species = c.species || "unbekannt";
      return date + ", " + kg + ", " + species;
    }).join("\n");
  }

  const systemPrompt = "Du bist der Carp24 Fangbuch-Datenanalyst. Analysiere die Fangdaten und berichte FAKTEN. Nutze NUR die gegebenen Daten. Erfinde nichts. Antworte kurz (max 120 Wörter), sachlich, auf Deutsch.";

  const models = [
    "mistralai/mistral-small-3.2-24b-instruct",
    "mistralai/mistral-nemo",
    "mistralai/mistral-small-2603",
  ];
  const maxRetries = 3;

  try {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      for (const model of models) {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 30_000);
        try {
          const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
            method: "POST",
            headers: { "Content-Type": "application/json", Authorization: "Bearer " + apiKey },
            body: JSON.stringify({ model, messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: "Fang-Kontext:\n" + contextStr + "\n\nFrage: " + message },
            ]}),
            signal: controller.signal,
          });
          clearTimeout(timeout);
          if (res.status === 404) continue;
          if (res.status === 429) { await new Promise(r => setTimeout(r, 2000 * (attempt + 1))); continue; }
          if (!res.ok) {
            const eb = await res.text().catch(() => "");
            return new Response(JSON.stringify({ error: "KI-Dienst nicht erreichbar (" + res.status + ")." }), { status: 502, headers: { "Content-Type": "application/json" } });
          }
          const data = await res.json();
          const answer = data.choices?.[0]?.message?.content || "Keine Antwort erhalten.";
          if (!isAdmin) { supabase.rpc("increment_ai_usage", { p_user_id: userId }).catch(() => {}); remaining = Math.max(0, remaining - 1); }
          return new Response(JSON.stringify({ answer, remaining }), { status: 200, headers: { "Content-Type": "application/json" } });
        } catch (fetchErr: any) {
          clearTimeout(timeout);
          if (fetchErr?.name === "AbortError") return new Response(JSON.stringify({ error: "KI-Dienst antwortet nicht (Timeout)." }), { status: 504, headers: { "Content-Type": "application/json" } });
          continue;
        }
      }
    }
    return new Response(JSON.stringify({ error: "KI-Dienst nicht erreichbar." }), { status: 502, headers: { "Content-Type": "application/json" } });
  } catch {
    return new Response(JSON.stringify({ error: "KI-Dienst nicht erreichbar." }), { status: 502, headers: { "Content-Type": "application/json" } });
  }
};
