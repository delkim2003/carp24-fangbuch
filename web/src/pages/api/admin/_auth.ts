import { createClient } from "@supabase/supabase-js";
import { checkRateLimit } from "../../../lib/rate-limit";

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
  // Rate-Limit: 30 Requests pro User pro Minute
  const userId = locals.user?.id || "anonymous";
  const rl = checkRateLimit(`admin:${userId}`, 30, 60_000);
  if (rl) return { error: "Zu viele Admin-Anfragen.", status: 429 };

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
