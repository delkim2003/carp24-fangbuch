import { getSupabaseUrl, getSupabaseAnonKey } from "../../../lib/config";
import type { APIRoute } from "astro";
import { checkRateLimit } from "../../../lib/rate-limit";
import { createServerClient, parseCookieHeader } from "@supabase/ssr";

export const prerender = false;

export const POST: APIRoute = async ({ request, cookies }) => {
  try {
    // Rate-Limit: 5 Versuche pro IP pro 60s
    const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
    const rateLimitResponse = checkRateLimit(`login:${ip}`, 5, 60_000);
    if (rateLimitResponse) return rateLimitResponse;

    const { email, password, captchaToken } = await request.json();

    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: "E-Mail und Passwort sind erforderlich." }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createServerClient(
      getSupabaseUrl(),
      getSupabaseAnonKey(),
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

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        user: { id: data.user.id, email: data.user.email },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (e: any) {
    return new Response(
      JSON.stringify({ error: e.message || "Interner Fehler" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
};
