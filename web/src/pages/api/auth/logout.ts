import type { APIRoute } from "astro";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";

export const prerender = false;

export const POST: APIRoute = async ({ request, cookies }) => {
  try {
  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return parseCookieHeader(request.headers.get("Cookie") ?? "");
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookies.set(name, value, {
              ...options,
              path: "/",
              sameSite: 'strict',
              secure: request.headers.get("x-forwarded-proto") === "https" || request.url.startsWith("https"),
            });
          });
        },
      },
      auth: {
        storageKey: "sb-carp24-auth-token",
      },
    }
  );

  await supabase.auth.signOut();

  return new Response(
    JSON.stringify({ success: true }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
  } catch (e: any) {
    return new Response(
      JSON.stringify({ error: e.message || "Logout failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
};
