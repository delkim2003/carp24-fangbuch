import { createClient } from "@supabase/supabase-js";

let cache: { value: { enabled: boolean; message: string }; ts: number } | null = null;
const TTL = 5000;

function getSupabase() {
  return createClient(
    process.env.PUBLIC_SUPABASE_URL || "",
    process.env.PUBLIC_SUPABASE_ANON_KEY || ""
  );
}

export async function getMaintenance(_supabase?: any): Promise<{ enabled: boolean; message: string }> {
  if (cache && Date.now() - cache.ts < TTL) return cache.value;
  const sb = getSupabase();
  const { data } = await sb.from("app_settings").select("value").eq("key", "maintenance").single();
  const v = data?.value ?? { enabled: false, message: "" };
  cache = { value: v, ts: Date.now() };
  return v;
}

export async function getVapidKeys(supabase?: any): Promise<{ publicKey: string; privateKey: string; subject: string }> {
  const envPublic = process.env.VAPID_PUBLIC_KEY;
  const envPrivate = process.env.VAPID_PRIVATE_KEY;
  const envSubject = process.env.VAPID_SUBJECT;

  if (envPublic && envPrivate) {
    return { publicKey: envPublic, privateKey: envPrivate, subject: envSubject || "mailto:info@carp24.at" };
  }

  if (supabase) {
    try {
      const { data } = await supabase.from("app_settings").select("value").eq("key", "vapid_key").single();
      if (data?.value) {
        return {
          publicKey: data.value.public_key || "",
          privateKey: data.value.private_key || "",
          subject: data.value.subject || "mailto:info@carp24.at",
        };
      }
    } catch {}
  }

  return { publicKey: "", privateKey: "", subject: "mailto:info@carp24.at" };
}
