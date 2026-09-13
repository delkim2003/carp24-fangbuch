/**
 * Shared cookie parsing utility for Supabase SSR
 * Uses parseCookieHeader from @supabase/ssr — handles base64-encoded cookies internally
 */
import { createServerClient, parseCookieHeader } from "@supabase/ssr";

export function parseCookies(request: Request): { name: string; value: string }[] {
  return parseCookieHeader(request.headers.get("Cookie") ?? "");
}

export function createSupabaseServerClient(request: Request, cookies?: any) {
  return createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return parseCookies(request);
        },
        setAll(cookiesToSet: any[]) {
          if (cookies) {
            cookiesToSet.forEach(({ name, value, options }: any) =>
              cookies.set(name, value, options)
            );
          }
        },
      },
      auth: {
        storageKey: 'sb-carp24-auth-token',
      },
      cookieOptions: {
        path: '/',
        sameSite: 'lax',
        secure: request.url.startsWith("https"),
      },
    }
  );
}
