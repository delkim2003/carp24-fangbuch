import { createBrowserClient } from '@supabase/ssr';

// Browser-Client: Requests gehen über den Astro-Proxy (/supabase/*)
// um CORS-Probleme mit der internen Supabase-URL zu vermeiden.
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
    storageKey: 'sb-carp24-auth-token', // Explizit gleicher Key für SSR + Client
  },
});

export type { SupabaseClient } from '@supabase/supabase-js';
