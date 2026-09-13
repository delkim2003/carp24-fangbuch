import { createSSRClient, createServiceClient } from "./ssr-client";
import type { AstroGlobal } from "astro";

export async function getSessionAndProfile(Astro: AstroGlobal) {
  const supabase = createSSRClient(Astro);

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return { supabase, session: null, profile: null, isAdmin: false };

  const { data: { session } } = await supabase.auth.getSession();

  // Service-Role Client für role/is_pro (nach Migration 0052 nicht mehr via anon-key lesbar)
  const adminSb = createServiceClient();
  const { data: profile } = await adminSb
    .from("profiles")
    .select("id, display_name, role, is_pro")
    .eq("id", user.id)
    .single();

  const role = profile?.role ?? "USER";
  return {
    supabase,
    session,
    profile,
    isAdmin: role === "ADMIN" || role === "MODERATOR",
  };
}
