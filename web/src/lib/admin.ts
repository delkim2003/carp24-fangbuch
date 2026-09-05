import { createServerClient, parseCookieHeader } from "@supabase/ssr";
import type { AstroGlobal } from "astro";

export async function getSessionAndProfile(Astro: AstroGlobal) {
  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return parseCookieHeader(Astro.request.headers.get("Cookie") ?? "");
        },
        setAll(cs) {
          cs.forEach(({ name, value, options }) => {
            Astro.cookies.set(name, value, options);
          });
        },
      },
      auth: {
        storageKey: 'sb-carp24-auth-token',
      },
      cookieOptions: {
        path: '/',
        sameSite: 'lax',
        secure: true,
      },
    }
  );

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) return { supabase, session: null, profile: null, isAdmin: false };

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, display_name, role, is_pro")
    .eq("id", session.user.id)
    .single();

  const role = profile?.role ?? "USER";
  return {
    supabase,
    session,
    profile,
    isAdmin: role === "ADMIN" || role === "MODERATOR",
  };
}
