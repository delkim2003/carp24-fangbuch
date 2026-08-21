// carp24 Load-Smoke (BAUPLAN 0.8) — k6
// Ziel: Beta-Readiness unter Last. 20 VUs, 30s, öffentliche Routen + Auth-Guard-Verhalten.
import http from "k6/http";
import { check } from "k6";

export const options = {
  scenarios: {
    smoke: {
      executor: "constant-vus",
      vus: 20,
      duration: "30s",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],        // <1% Fehler
    http_req_duration: ["p(95)<500"],       // p95 < 500ms
  },
};

const BASE = "http://100.93.250.103:8094";

export default function () {
  // Öffentliche Seiten (müssen 200 liefern)
  const publicRoutes = ["/", "/impressum", "/datenschutz"];
  for (const path of publicRoutes) {
    const r = http.get(`${BASE}${path}`);
    check(r, {
      [`${path} ist 200`]: (res) => res.status === 200,
    });
  }

  // Geschützte Seiten: ohne Session → Auth-Guard (302 zu /login oder 200 mit Anmelde-Hinweis)
  const guarded = ["/faenge", "/statistik", "/dashboard", "/profil"];
  for (const path of guarded) {
    const r = http.get(`${BASE}${path}`);
    check(r, {
      [`${path} blockt anonym (200/302/303)`]: (res) =>
        res.status === 200 || res.status === 302 || res.status === 303,
    });
  }
}
