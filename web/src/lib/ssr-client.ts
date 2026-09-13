import { createServerClient } from '@supabase/ssr';
import { createClient } from '@supabase/supabase-js';

export function createSSRClient(astro: { request: Request; cookies: { set: (name: string, value: string, options?: any) => void }; url?: URL }) {
  const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
  const isSecure = true;

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
      sameSite: 'strict',
      secure: isSecure,
    },
  });
}

/**
 * Service-Role Client — Bypasses RLS. NUR für sensible Profil-Queries (is_pro, role).
 * Nicht für allgemeine Queries verwenden!
 * Nutzt SUPABASE_URL (Docker-IP) oder PUBLIC_SUPABASE_URL als Fallback.
 */
export function createServiceClient() {
  const supabaseUrl = import.meta.env.SUPABASE_URL || import.meta.env.PUBLIC_SUPABASE_URL;
  const serviceKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl) throw new Error('SUPABASE_URL and PUBLIC_SUPABASE_URL not set');
  if (!serviceKey) throw new Error('SUPABASE_SERVICE_ROLE_KEY not set');
  return createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}