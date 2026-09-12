import { createSSRClient } from "./ssr-client";
import type { AstroGlobal } from "astro";

export async function getSessionAndProfile(Astro: AstroGlobal) {
  const supabase = createSSRClient(Astro);

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return { supabase, session: null, profile: null, isAdmin: false };

  const { data: { session } } = await supabase.auth.getSession();

  const { data: profile } = await supabase
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
