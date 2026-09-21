import { getSupabaseUrl, getSupabaseAnonKey, getSupabaseServiceKey } from "../../../lib/config";
import { createClient } from "@supabase/supabase-js";

export const prerender = false;

async function guard(locals: App.Locals) {
  const user = locals.user;
  if (!user) return { error: "Nicht angemeldet.", status: 401 };

  const role = locals.role ?? "USER";
  if (role !== "ADMIN" && role !== "MODERATOR") return { error: "Keine Berechtigung.", status: 403 };

  const supabaseAdmin = createClient(
    getSupabaseUrl(),
    getSupabaseServiceKey()
  );

  return { supabaseAdmin, user };
}

function buildQuery(query: any, filters: { action?: string; dateFrom?: string; dateTo?: string }) {
  const { action, dateFrom, dateTo } = filters;
  if (action) query = query.eq("action", action);
  if (dateFrom) query = query.gte("created_at", dateFrom);
  if (dateTo) query = query.lte("created_at", dateTo);
  return query;
}

export const GET = async ({ request, locals }: { request: Request; locals: App.Locals }) => {
  const g = await guard(locals);
  if ("error" in g) {
    return new Response(JSON.stringify({ error: g.error }), {
      status: g.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { supabaseAdmin } = g;
  const url = new URL(request.url);
  const limit = Math.min(parseInt(url.searchParams.get("limit") || "100", 10), 500);
  const page = Math.max(parseInt(url.searchParams.get("page") || "1", 10), 1);

  const action = url.searchParams.get("action") || undefined;
  const dateFrom = url.searchParams.get("date_from") || undefined;
  const dateTo = url.searchParams.get("date_to") || undefined;

  const from = (page - 1) * limit;
  const to = from + limit - 1;

  // Count total rows first (with filters)
  let countQuery = supabaseAdmin
    .from("admin_audit_log")
    .select("*", { count: "exact", head: true });
  countQuery = buildQuery(countQuery, { action, dateFrom, dateTo });

  const { count: total, error: countError } = await countQuery;

  if (countError) {
    return new Response(JSON.stringify({ error: countError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Fetch paginated data (with filters)
  let dataQuery = supabaseAdmin
    .from("admin_audit_log")
    .select("id, actor_id, action, target_type, target_id, details, created_at")
    .order("created_at", { ascending: false });

  dataQuery = buildQuery(dataQuery, { action, dateFrom, dateTo });
  dataQuery = dataQuery.range(from, to);

  const { data: logs, error } = await dataQuery;

  if (error) {
    console.error("[admin]", error);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const totalPages = Math.ceil((total ?? 0) / limit);

  const actorIds = [...new Set((logs ?? []).map((l: any) => l.actor_id).filter(Boolean))];
  let actorMap = new Map<string, string>();
  if (actorIds.length > 0) {
    const { data: actors } = await supabaseAdmin
      .from("profiles")
      .select("id, display_name")
      .in("id", actorIds);
    actorMap = new Map((actors ?? []).map((a: any) => [a.id, a.display_name]));
  }

  const enriched = (logs ?? []).map((l: any) => ({
    ...l,
    actor_name: actorMap.get(l.actor_id) ?? "Unbekannt",
  }));

  return new Response(JSON.stringify({ logs: enriched, pagination: { page, limit, total: total ?? 0, totalPages } }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};