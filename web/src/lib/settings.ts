let cache: { value: { enabled: boolean; message: string }; ts: number } | null = null;
const TTL = 5000;

export async function getMaintenance(supabase: any): Promise<{ enabled: boolean; message: string }> {
  if (cache && Date.now() - cache.ts < TTL) return cache.value;
  const { data } = await supabase.from("app_settings").select("value").eq("key", "maintenance").single();
  const v = data?.value ?? { enabled: false, message: "" };
  cache = { value: v, ts: Date.now() };
  return v;
}
