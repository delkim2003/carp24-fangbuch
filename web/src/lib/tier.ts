/**
 * lib/tier.ts — Premium-Tier-Helper für Carp24
 *
 * SSR: Nutze getTierFromLocals(Astro.locals) — kein Extra-DB-Call.
 * Client: Nutze fetchTier() — holt Tier via /api/user/tier.
 */

export type UserTier = "free" | "pro";

/* ─── SSR: direkt aus Middleware-Locals ─── */

/**
 * Extrahiert das Tier aus den Middleware-Locals.
 * Nutzt das isPro-Flag, das die Middleware einmalig pro Request lädt.
 */
export function getTierFromLocals(locals: { isPro?: boolean }): UserTier {
  return locals.isPro ? "pro" : "free";
}

/* ─── Client: Fetch mit Cache ─── */

let cachedTier: UserTier | null = null;
let fetchPromise: Promise<UserTier> | null = null;

/**
 * Holt das aktuelle Tier des eingeloggten Users via API.
 * Cached das Ergebnis bis invalidateTier() aufgerufen wird.
 */
export async function fetchTier(): Promise<UserTier> {
  if (cachedTier) return cachedTier;
  if (fetchPromise) return fetchPromise;

  fetchPromise = (async () => {
    try {
      const res = await fetch("/api/user/tier", { credentials: "include" });
      if (!res.ok) return "free";
      const data = await res.json();
      cachedTier = data.tier === "pro" ? "pro" : "free";
      return cachedTier;
    } catch {
      return "free";
    } finally {
      fetchPromise = null;
    }
  })();

  return fetchPromise;
}

/**
 * Cache leeren — nach Login/Logout/Upgrade aufrufen.
 */
export function invalidateTier(): void {
  cachedTier = null;
  fetchPromise = null;
}

/* ─── Utility ─── */

/**
 * Prüft ob ein Tier PRO ist.
 */
export function isPro(tier: UserTier): boolean {
  return tier === "pro";
}

/**
 * Prüft ob ein Tier FREE ist.
 */
export function isFree(tier: UserTier): boolean {
  return tier === "free";
}
