/// <reference path="../.astro/types.d.ts" />
/// <reference types="astro/client" />

declare namespace App {
  interface Locals {
    session: import("@supabase/supabase-js").Session | null;
    role: string;
    isAdmin: boolean;
  }
}
