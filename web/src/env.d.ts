import '@supabase/supabase-js';

declare namespace App {
  interface Locals {
    user: import('@supabase/supabase-js').User | null;
    session: import('@supabase/supabase-js').Session | null;
  }
}

export {};