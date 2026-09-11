import { createClient } from "@supabase/supabase-js";

export const prerender = false;

/**
 * GET /api/user/tier
 * Returns { tier: "free" | "pro" } for the current user.
 * Uses locals.isPro set by middleware (single DB query per request).
 */
export const GET = async ({ locals }: { locals: App.Locals }) => {
  if (!locals.user) {
    return new Response(JSON.stringify({ tier: "free" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({ tier: locals.isPro ? "pro" : "free" }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "private, no-store",
      },
    }
  );
};
