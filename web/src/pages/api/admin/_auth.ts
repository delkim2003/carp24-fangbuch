import { createClient } from "@supabase/supabase-js";

export type AdminAuth = {
  supabaseAdmin: ReturnType<typeof createClient>;
  user: NonNullable<App.Locals["user"]>;
  actorRole: string;
};

export type AdminAuthError = {
  error: string;
  status: number;
};

export type AdminAuthResult = AdminAuth | AdminAuthError;

/**
 * Authenticate and authorize an admin API request.
 * Returns { supabaseAdmin, user, actorRole } on success.
 * Returns { error, status } on failure.
 */
export async function getAdminClient(
  locals: App.Locals,
): Promise<AdminAuthResult> {
  const user = locals.user;
  if (!user) return { error: "Nicht angemeldet.", status: 401 };

  const supabaseAdmin = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY,
  );

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  const role = profile?.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") {
    return { error: "Keine Berechtigung.", status: 403 };
  }

  return { supabaseAdmin, user, actorRole: role };
}
