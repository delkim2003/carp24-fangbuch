import { createServerClient } from '@supabase/ssr';

/**
 * Erstellt einen Supabase-Server-Client mit korrektem Cookie-Name.
 * Der storageKey MUSS mit dem Browser-Client (supabase-client.ts) übereinstimmen,
 * sonst findet der SSR die Session-Cookies nicht.
 *
 * Usage: const supabase = createSSRClient(Astro);
 */
export function createSSRClient(astro: { request: Request; cookies: { set: (name: string, value: string, options?: any) => void } }) {
  const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

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
  });
}
