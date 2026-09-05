// k6 Smoke Test — Carp24 Fangbuch (Phase 0)
// k6 run tests/k6/smoke.js
// Erwartung: <5% Fehler, p95 < 500ms

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const pageLoad = new Trend('page_load_ms');

const BASE = __ENV.BASE_URL || 'http://100.93.250.103:8094';
const SUPABASE = __ENV.SUPABASE_URL || 'http://100.93.250.103:8055';
const ANON_KEY = __ENV.SUPABASE_ANON_KEY || '';

export const options = {
  vus: 5,
  duration: '30s',
  thresholds: {
    errors: ['rate<0.05'],
    http_req_duration: ['p(95)<500'],
  },
};

export default function () {
  group('Frontend Pages', function () {
    // Homepage
    let res = http.get(`${BASE}/`);
    check(res, {
      'Homepage 200': (r) => r.status === 200,
      'Homepage < 500ms': (r) => r.timings.duration < 500,
    }) || errorRate.add(1);
    pageLoad.add(res.timings.duration);

    sleep(0.5);

    // Login
    res = http.get(`${BASE}/login`);
    check(res, {
      'Login 200': (r) => r.status === 200,
      'Login < 500ms': (r) => r.timings.duration < 500,
    }) || errorRate.add(1);
    pageLoad.add(res.timings.duration);

    sleep(0.5);

    // Dashboard (redirect oder 200)
    res = http.get(`${BASE}/dashboard`, { redirects: 0 });
    check(res, {
      'Dashboard erreichbar': (r) => r.status === 200 || r.status === 302,
    }) || errorRate.add(1);

    sleep(0.5);

    // Impressum (sollte existieren)
    res = http.get(`${BASE}/impressum`);
    check(res, {
      'Impressum erreichbar': (r) => r.status === 200 || r.status === 302,
    }) || errorRate.add(1);

    sleep(0.5);

    // Datenschutz
    res = http.get(`${BASE}/datenschutz`);
    check(res, {
      'Datenschutz erreichbar': (r) => r.status === 200 || r.status === 302,
    }) || errorRate.add(1);
  });

  group('Supabase API', function () {
    const headers = {
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${ANON_KEY}`,
    };

    // Profiles (RLS → [])
    let res = http.get(`${SUPABASE}/rest/v1/profiles?select=id&limit=1`, { headers });
    check(res, {
      'Profiles 200': (r) => r.status === 200,
      'Profiles JSON': (r) => r.headers['Content-Type'] && r.headers['Content-Type'].includes('json'),
    }) || errorRate.add(1);

    // Waters
    res = http.get(`${SUPABASE}/rest/v1/waters?select=id&limit=1`, { headers });
    check(res, {
      'Waters 200': (r) => r.status === 200,
    }) || errorRate.add(1);

    // Catches (RLS → [])
    res = http.get(`${SUPABASE}/rest/v1/catches?select=id&limit=1`, { headers });
    check(res, {
      'Catches 200': (r) => r.status === 200,
    }) || errorRate.add(1);

    // Auth Health
    res = http.get(`${SUPABASE}/auth/v1/health`);
    check(res, {
      'Auth Health erreichbar': (r) => r.status !== 0,
    }) || errorRate.add(1);
  });

  sleep(1);
}
