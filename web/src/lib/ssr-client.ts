import { createServerClient } from '@supabase/ssr';

export function createSSRClient(astro: { request: Request; cookies: { set: (name: string, value: string, options?: any) => void }; url?: URL }) {
  const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
  const isSecure = astro.url?.protocol === 'https:' ?? false;

  return createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        const header = astro.request.headers.get('cookie');
        if (!header) return [];
        return header
          .split(';')
          .map((pair) => {
            const idx = pair.indexOf('=');
            if (idx === -1) return null;
            return {
              name: pair.slice(0, idx).trim(),
              value: pair.slice(idx + 1).trim(),
            };
          })
          .filter(Boolean) as { name: string; value: string }[];
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options }) => {
          astro.cookies.set(name, value, options);
        });
      },
    },
    auth: {
      storageKey: 'sb-carp24-auth-token',
    },
    cookieOptions: {
      path: '/',
      sameSite: 'lax',
      secure: isSecure,
    },
  });
}