import { createServerClient } from "@supabase/ssr";
import { parseCookieHeader } from "@supabase/ssr";

export const prerender = false;

export const GET = async ({ request }: { request: Request }) => {
  const cookieHeader = request.headers.get("cookie") || "";
  const cookies = cookieHeader.split(";").map(c => c.trim()).filter(Boolean);
  const cookieNames = cookies.map(c => c.split("=")[0]);

  console.log("[ADMIN/ME] Cookie header length:", cookieHeader.length);
  console.log("[ADMIN/ME] Cookie names:", cookieNames);
  console.log("[ADMIN/ME] Has sb-carp24-auth-token:", cookieNames.includes("sb-carp24-auth-token"));

  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return parseCookieHeader(request.headers.get("Cookie") ?? "");
        },
        setAll() {},
      },
      auth: {
        storageKey: 'sb-carp24-auth-token',
      },
      cookieOptions: {
        path: '/',
        sameSite: 'lax',
        secure: false,
      },
    }
  );

  const {
    data: { session },
  } = await supabase.auth.getSession();

  console.log("[ADMIN/ME] Session:", session ? "found" : "null");
  if (session) {
    console.log("[ADMIN/ME] User ID:", session.user.id);
  }

  if (!session) {
    return new Response(JSON.stringify({
      error: "Nicht angemeldet.",
      debug: {
        cookieHeaderLength: cookieHeader.length,
        cookieNames: cookieNames,
        hasAuthToken: cookieNames.includes("sb-carp24-auth-token"),
      }
    }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", session.user.id)
    .single();

  const role = profile?.role ?? "USER";
  const isAdmin = role === "ADMIN" || role === "MODERATOR";

  console.log("[ADMIN/ME] Role:", role, "isAdmin:", isAdmin);

  return new Response(JSON.stringify({ isAdmin, role }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};