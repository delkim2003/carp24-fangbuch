/**
 * Zentrale Konfiguration — nutzt process.env (Runtime) mit Fallback auf import.meta.env (Build-Time).
 * Auf dem Dev-Host: process.env wird via start-dev.sh gesetzt.
 * Im Docker: process.env wird via --env-file gesetzt.
 * Build-Time: import.meta.env wird via .env aufgelöst.
 */
export function getSupabaseUrl(): string {
  return process.env.PUBLIC_SUPABASE_URL || (import.meta.env.PUBLIC_SUPABASE_URL as string) || "";
}

export function getSupabaseAnonKey(): string {
  return process.env.PUBLIC_SUPABASE_ANON_KEY || (import.meta.env.PUBLIC_SUPABASE_ANON_KEY as string) || "";
}

export function getSupabaseServiceKey(): string {
  return process.env.SUPABASE_SERVICE_ROLE_KEY || (import.meta.env.SUPABASE_SERVICE_ROLE_KEY as string) || "";
}

export function getSupabaseInternalUrl(): string {
  return process.env.SUPABASE_URL || process.env.PUBLIC_SUPABASE_URL || (import.meta.env.PUBLIC_SUPABASE_URL as string) || "";
}
