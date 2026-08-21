import { createServerClient } from "@supabase/ssr";
import type { AstroGlobal } from "astro";

export async function getSessionAndProfile(Astro: AstroGlobal) {
  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          const h = Astro.request.headers.get("cookie");
          if (!h) return [];
          return h
            .split(";")
            .map((p) => {
              const i = p.indexOf("=");
              if (i === -1) return null;
              return { name: p.slice(0, i).trim(), value: p.slice(i + 1).trim() };
            })
            .filter(Boolean) as { name: string; value: string }[];
        },
        setAll(cs) {
          cs.forEach(({ name, value, options }) => {
            Astro.cookies.set(name, value, options);
          });
        },
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
