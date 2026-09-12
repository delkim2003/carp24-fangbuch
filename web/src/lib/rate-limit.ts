/**
 * In-Memory Rate-Limiter (pro Container-Instanz)
 * Für Produktion: Redis-basierten Limiter verwenden.
 */

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

const store = new Map<string, RateLimitEntry>();

// Cleanup alte Einträge alle 60s
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of store) {
    if (now > entry.resetAt) store.delete(key);
  }
}, 60_000).unref();

/**
 * Prüft Rate-Limit. Gibt null zurück wenn erlaubt, sonst Response mit 429.
 * @param key - Eindeutiger Key (z.B. IP, User-ID, oder Kombination)
 * @param limit - Max Anzahl Requests im Zeitfenster
 * @param windowMs - Zeitfenster in Millisekunden
 */
export function checkRateLimit(
  key: string,
  limit: number,
  windowMs: number
): Response | null {
  const now = Date.now();
  const entry = store.get(key);

  if (!entry || now > entry.resetAt) {
    store.set(key, { count: 1, resetAt: now + windowMs });
    return null;
  }

  entry.count++;

  if (entry.count > limit) {
    const retryAfter = Math.ceil((entry.resetAt - now) / 1000);
    return new Response(
      JSON.stringify({
        error: "Zu viele Anfragen. Bitte warte einen Moment.",
        retryAfter,
      }),
      {
        status: 429,
        headers: {
          "Content-Type": "application/json",
          "Retry-After": String(retryAfter),
        },
      }
    );
  }

  return null;
}
