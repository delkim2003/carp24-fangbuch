import type { SupabaseClient } from "@supabase/supabase-js";

const MAX_DEDUPE = 20;
const seen = new Set<string>();

function dedupeKey(message: string, url: string): string {
  return `${message}:::${url}`;
}

function wasSeen(message: string, url: string): boolean {
  const key = dedupeKey(message, url);
  if (seen.has(key)) return true;
  if (seen.size >= MAX_DEDUPE) {
    const first = seen.values().next().value;
    if (first) seen.delete(first);
  }
  seen.add(key);
  return false;
}

function send(
  sb: SupabaseClient,
  level: "error" | "warning" | "info",
  message: string,
  stack: string,
  context?: Record<string, unknown>,
): void {
  const url = window.location.pathname;
  const msg = String(message || "").slice(0, 2000);
  if (!msg || wasSeen(msg, url)) return;

  sb.auth
    .getSession()
    .then(({ data }) => {
      if (!data.session) return;
      return sb.from("error_logs").insert({
        level,
        source: "client",
        url,
        message: msg,
        stack: String(stack || "").slice(0, 4000),
        context: context ?? { ua: navigator.userAgent },
      });
    })
    .catch(() => {});
}

export function initErrorTracker(sb: SupabaseClient): () => void {
  function onError(event: ErrorEvent): void {
    send(
      sb,
      "error",
      String(event.message || ""),
      String(event.error?.stack || event.error || ""),
    );
  }

  function onUnhandledRejection(event: PromiseRejectionEvent): void {
    const reason = event.reason;
    send(
      sb,
      "error",
      String(reason?.message || reason || "Unhandled Promise Rejection"),
      String(reason?.stack || ""),
    );
  }

  window.addEventListener("error", onError);
  window.addEventListener("unhandledrejection", onUnhandledRejection);

  return () => {
    window.removeEventListener("error", onError);
    window.removeEventListener("unhandledrejection", onUnhandledRejection);
  };
}

export function logError(
  sb: SupabaseClient,
  message: string,
  opts?: { level?: "error" | "warning" | "info"; stack?: string; context?: Record<string, unknown> },
): void {
  send(sb, opts?.level ?? "error", message, opts?.stack ?? "", opts?.context);
}
