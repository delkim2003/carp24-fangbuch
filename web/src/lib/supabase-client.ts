import { createBrowserClient } from '@supabase/ssr';

const supabaseUrl = typeof window !== 'undefined'
  ? `${window.location.origin}/supabase`
  : (import.meta.env.PUBLIC_SUPABASE_URL as string);

const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY as string;

if (!supabaseAnonKey) {
  throw new Error(
    'Supabase-Credentials fehlen. Bitte PUBLIC_SUPABASE_ANON_KEY in web/.env setzen.'
  );
}

export const supabase = createBrowserClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storageKey: 'sb-carp24-auth-token',
  },
  cookieOptions: {
    path: '/',
    sameSite: 'lax',
    secure: typeof window !== 'undefined' ? window.location.protocol === 'https:' : false,
  },
});

export type { SupabaseClient } from '@supabase/supabase-js';