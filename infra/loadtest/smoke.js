// carp24 Load-Smoke (P0.8) — k6-Skript
// Ziel: Architektur-Validierung auf Dev-Server (11 Container).
// Vorsichtige Last: 20 VUs, 3 Min — Dev-Hardware, kein Prod-Benchmark.
// API: Kong http://100.93.250.103:8055, anon-Key aus Env (K6_ANON_KEY).

import http from 'k6/http';
import { check, sleep } from 'k6';

const ANON_KEY = __ENV.ANON_KEY || 'missing';
const BASE = 'http://100.93.250.103:8055/rest/v1';

export const options = {
  vus: 20,
  duration: '3m',
  thresholds: {
    http_req_failed: ['rate<0.01'],      // max 1% Fehler
    http_req_duration: ['p(95)<800'],    // 95% unter 800ms
  },
};

const HEADERS = {
  'apikey': ANON_KEY,
  'Authorization': `Bearer ${ANON_KEY}`,
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

// User-Modell: Angler browst Fangbuch
export default function () {
  // 1) Öffentliche Posts (Feed) — am häufigsten
  const posts = http.get(`${BASE}/posts?select=id,text,status&status=eq.VISIBLE&limit=20`, { headers: HEADERS });
  check(posts, { 'posts 200': (r) => r.status === 200 });

  // 2) Öffentliche Forum-Topics
  const topics = http.get(`${BASE}/forum_topics?select=id,title,status&status=eq.VISIBLE&limit=20`, { headers: HEADERS });
  check(topics, { 'topics 200': (r) => r.status === 200 });

  // 3) Marktplatz (öffentliche Inserate)
  const listings = http.get(`${BASE}/marketplace_listings?select=id,title,price&limit=20`, { headers: HEADERS });
  check(listings, { 'listings 200': (r) => r.status === 200 });

  // 4) Forum-Posts eines Topics
  const forum = http.get(`${BASE}/forum_posts?select=id,body,status&status=eq.VISIBLE&limit=20`, { headers: HEADERS });
  check(forum, { 'forum 200': (r) => r.status === 200 });

  sleep(1); // realistischer Leseabstand
}
