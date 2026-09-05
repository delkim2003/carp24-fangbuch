let cache: { value: { enabled: boolean; message: string }; ts: number } | null = null;
const TTL = 5000;

export async function getMaintenance(supabase: any): Promise<{ enabled: boolean; message: string }> {
  if (cache && Date.now() - cache.ts < TTL) return cache.value;
  const { data } = await supabase.from("app_settings").select("value").eq("key", "maintenance").single();
  const v = data?.value ?? { enabled: false, message: "" };
  cache = { value: v, ts: Date.now() };
  return v;
}

export async function getVapidKeys(supabase?: any): Promise<{ publicKey: string; privateKey: string; subject: string }> {
  const envPublic = import.meta.env.VAPID_PUBLIC_KEY;
  const envPrivate = import.meta.env.VAPID_PRIVATE_KEY;
  const envSubject = import.meta.env.VAPID_SUBJECT;

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
