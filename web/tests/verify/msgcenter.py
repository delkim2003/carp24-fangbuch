#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""c24-msgcenter-verify (09.10.2026): Minerva-One-Command QA fuer 343 (0a35d9e) + P2.3 (d7cabe5).
Matrix: A1-A3 marktplatz.astro Badges/Owner-Buttons | B1-B4 contact.ts | C1-C3 RLS | D1 is:inline-Hygiene.
Read-only ausser Testdaten. Cleanup automatisch (finally). Ausgabe: NUR Status/IDs, KEINE Creds."""
import json, re, subprocess, sys, time, urllib.request, urllib.error, uuid as U
from http.cookiejar import CookieJar

REPO = "/opt/carp24"
MARKTPLATZ = REPO + "/web/src/pages/marktplatz.astro"
CONTACT = REPO + "/web/src/pages/api/marketplace/contact.ts"
ENVF = REPO + "/web/.env"
R = []

def check(cid, desc, ok, ev):
    ev = str(ev)[:160].replace("\n", " ")
    R.append({"id": cid, "ok": bool(ok), "detail": ev})
    print(("\u2705 VERIFIZIERT" if ok else "\u274c FEHLER") + f" [{cid}] {desc} (Beweis: {ev})")

def psql(sql, timeout=30):
    p = subprocess.run(["docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres",
                        "-v", "ON_ERROR_STOP=1", "-c", sql], capture_output=True, text=True, timeout=timeout)
    return p.returncode, (p.stdout + p.stderr)

def http(method, url, body=None, headers=None, opener=None, timeout=15):
    hdrs = {"Content-Type": "application/json"}
    hdrs.update(headers or {})
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    op = opener or urllib.request.build_opener()
    try:
        r = op.open(req, timeout=timeout)
        return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:
        return 0, f"{type(e).__name__}: {e}"

itemA = itemB = itemC = uidA = uidB = None
opA = opB = None
BASE = SU = None
page_html = ""

try:
    # ── 0. ENV + QUELLEN (ohne Server lauffaehig) ───────────────────────────
    envd = {}
    for line in open(ENVF, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            envd[k.strip()] = v.strip()
    SRV = envd.get("SUPABASE_SERVICE_ROLE_KEY", "")
    check("S1", "Service-Key aus web/.env geladen (len/prefix only)", len(SRV) > 50, f"len={len(SRV)} prefix={SRV[:4]}")

    src = open(MARKTPLATZ, encoding="utf-8").read()
    ctsrc = open(CONTACT, encoding="utf-8").read()
    check("A0", "343-Query: eigene Items .in(status,[sold,pending,rejected])",
          '.in("status", ["sold", "pending", "rejected"])' in src, "grep in marktplatz.astro")
    check("B3", "Mailversand in try/catch (Mailfehler schluckt Request nie)",
          bool(re.search(r"try \{[\s\S]{0,1600}sendMail[\s\S]{0,400}\} catch", ctsrc)) and "console.error" in ctsrc,
          "Regex try..sendMail..catch + console.error in contact.ts")

    m = re.search(r"<script is:inline[\s\S]*?</script>", src)
    region = m.group(0) if m else ""
    ts = re.findall(r":\s*(?:string|number|boolean|any)\b", region)
    check("D1-1", "is:inline ohne TS-Annotationen", len(ts) == 0 and len(region) > 500, f"hits={ts[:3]} region={len(region)}B")
    check("D1-2", "is:inline ohne \\u00-Escapes (Umlauten raw)", region.count("\\u00") == 0, f"count={region.count(chr(92) + 'u00')}")

    # ── 1. SERVER-DETECT ────────────────────────────────────────────────────
    for cand in ("https://carp24.org", "http://localhost:4321"):
        st, _b = http("POST", cand + "/api/auth/login", {})
        if st >= 200:
            BASE = cand
            break
    for cand in (envd.get("PUBLIC_SUPABASE_URL", ""), "http://localhost:8055", "http://127.0.0.1:8055"):
        if not cand:
            continue
        st, _b = http("GET", cand.rstrip("/") + "/auth/v1/health", headers={"apikey": SRV})
        if st > 0:
            SU = cand.rstrip("/")
            break
    check("S2", "DEV-Server + Supabase REST erreichbar (Auto-Detect)", bool(BASE and SU), f"BASE={BASE} SU={SU}")
    if not (BASE and SU):
        raise SystemExit(1)

    REST = SU + "/rest/v1"
    AUTH = SU + "/auth/v1"
    adm = {"apikey": SRV, "Authorization": "Bearer " + SRV}
    ts_ = int(time.time())

    # ── 2. TESTDATEN ────────────────────────────────────────────────────────
    def admin_create(tag):
        email = f"qa-msgc-{ts_}-{tag}@carp24.dev"
        pw = f"Qa-Msgc-{ts_}-{tag}-Aa1"
        st, body = http("POST", AUTH + "/admin/users", {"email": email, "password": pw, "email_confirm": True}, adm)
        uid = re.search(r'"id":"([0-9a-f-]{36})"', body)
        return (uid.group(1) if uid else None), email, pw, st

    def item_create(uid, status, title):
        st, body = http("POST", REST + "/marketplace_items",
                        {"user_id": uid, "title": title, "price": 1, "category": "Ruten", "status": status},
                        {**adm, "Prefer": "return=representation"})
        iid = re.search(r'"id":"([0-9a-f-]{36})"', body)
        return (iid.group(1) if iid else None), st

    def set_status(iid, status):
        return http("PATCH", REST + f"/marketplace_items?id=eq.{iid}", {"status": status},
                    {**adm, "Prefer": "return=minimal"})

    def login(email, pw):
        jar = CookieJar()
        op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        st = 0
        body = ""
        for _attempt in range(4):
            st, body = http("POST", BASE + "/api/auth/login", {"email": email, "password": pw}, opener=op)
            if st != 429:
                break
            time.sleep(30)
        return op, st, len(jar)

    def page(op):
        st, body = http("GET", BASE + "/marktplatz", opener=op)
        return st, body.replace('\\"', '"')

    uidA, emailA, pwA, stA = admin_create("a")
    uidB, emailB, pwB, stB = admin_create("b")
    check("S3", "Test-User A+B via Admin-API", bool(uidA and uidB), f"A={uidA} B={uidB} http={stA}/{stB}")
    if not (uidA and uidB):
        raise SystemExit(1)
    # Gate: Seite zeigt Daten nur bei session && isPaid (isPro || ADMIN, marktplatz.astro Z.41-48) -> User A heben
    st, body = http("PATCH", REST + f"/profiles?id=eq.{uidA}", {"is_pro": True, "role": "ADMIN"},
                    {**adm, "Prefer": "return=minimal"})
    rc, out = psql(f"SELECT is_pro, role FROM profiles WHERE id='{uidA}';")
    _o, _s, _j = login(emailA, pwA)
    _rq = urllib.request.Request(SU + '/rest/v1/rpc/is_user_premium', method='POST')
    _rq.add_header('apikey', ANON_KEY if 'ANON_KEY' in dir() else SRV)
    _rq.add_header('Authorization', 'Bearer ' + SRV)
    _rq.add_header('Content-Type', 'application/json')
    try:
        _r = urllib.request.urlopen(_rq, b'{}'); print('RPC-ADMIN-SICHT:', _r.read().decode()[:40])
    except Exception as _e: print('RPC-ERR', _e)
    check("S5", "User A Premium-Gate gesetzt (is_pro=t / role=ADMIN)", st in (200, 204) and "t" in out and "ADMIN" in out,
          f"PATCH {st} select: {out.strip().replace(chr(10), ' ')[:80]}")
    st_abo, b_abo = http('POST', SU + '/rest/v1/subscriptions', {'user_id': uidA, 'tier': 'premium', 'status': 'ACTIVE'}, {'apikey': SRV, 'Authorization': 'Bearer ' + SRV, 'Content-Type': 'application/json'})
    print('ABO-DEBUG:', st_abo, b_abo[:120])
    st_aboB, b_aboB = http('POST', SU + '/rest/v1/subscriptions', {'user_id': uidB, 'tier': 'premium', 'status': 'ACTIVE'}, {'apikey': SRV, 'Authorization': 'Bearer ' + SRV, 'Content-Type': 'application/json'})
    print('ABO-DEBUG-B:', st_aboB)
    _s2, _b2 = http('GET', SU + '/rest/v1/subscriptions?user_id=eq.' + uidA + '&select=tier,plan,status,active_until', None, {'apikey': SRV, 'Authorization': 'Bearer ' + SRV})
    print('ABO-ZEILE:', _b2[:150])
    print(chr(65)+chr(66)+chr(79), st_abo if chr(115)+chr(116)+chr(95)+chr(97)+chr(98)+chr(111) in dir() else chr(63))
    itemA, s1 = item_create(uidA, "pending", "QA Msgcenter A")
    itemB, s2 = item_create(uidB, "active", "QA Msgcenter B-eigen")
    itemC, s3 = item_create(uidA, "pending", "QA Msgcenter C-pending")
    check("S4", "Test-Items angelegt (A=pending, B=active, C=pending)", bool(itemA and itemB and itemC),
          f"A={itemA} B={itemB} C={itemC} http={s1}/{s2}/{s3}")

    # ── 3. A-BLOCK: marktplatz.astro Badges/Owner-Buttons (343-E2E) ─────────
    opA, stL, njar = login(emailA, pwA)
    st, page_html = page(opA)
    h = page_html
    check("A1", "eigenes pending Item sichtbar + Badge IN PRÜFUNG (343-Fix E2E)",
          (itemA in h) and ('"status":"pending"' in h) and ("IN PRÜFUNG" in h) and st == 200,
          f"GET /marktplatz {st}; uuid in HTML={'itemA-in' if itemA in h else 'FEHLT'}; 'IN PRÜFUNG'={'ja' if 'IN PRÜFUNG' in h else 'nein'}")
    set_status(itemA, "rejected")
    st, h = page(opA)
    check("A2-1", "rejected -> Badge ABGELEHNT (Status-Wechsel sichtbar)",
          (itemA in h) and ('"status":"rejected"' in h) and ("ABGELEHNT" in h),
          f"GET {st}; status:rejected={'ja' if chr(34) + 'status' + chr(34) + ':' + chr(34) + 'rejected' in h.replace(chr(32),'') else 'nein'}; 'ABGELEHNT'={'ja' if 'ABGELEHNT' in h else 'nein'}")
    set_status(itemA, "sold")
    st, h = page(opA)
    check("A2-2", "sold -> Badge VERKAUFT (Status-Wechsel sichtbar)",
          (itemA in h) and ('"status":"sold"' in h) and ("VERKAUFT" in h),
          f"GET {st}; 'VERKAUFT'={'ja' if 'VERKAUFT' in h else 'nein'}")
    check("A3", "Owner-Buttons nur bei isOwner && status===active (Guard + LÖSCHEN)",
          ("isOwner && item.status === 'active'" in h) and ("LÖSCHEN" in h),
          "Guard-String + Button-Label im served HTML")
    set_status(itemA, "active")

    # ── 4. B-BLOCK: contact.ts ──────────────────────────────────────────────
    st, body = http("POST", BASE + "/api/marketplace/contact", {"item_id": itemA, "message": "QA ohne Login"})
    check("B1", "POST /contact ohne Session -> 401", st == 401 and "Nicht angemeldet" in body, f"http={st} body={body[:60]}")

    opB, stLB, njarB = login(emailB, pwB)
    H = {"Content-Type": "application/json"}
    cases = [
        ("B4-1", "ungueltige item_id -> 400", {"item_id": "not-a-uuid", "message": "QA Test"}, 400),
        ("B4-2", "message < 3 Zeichen -> 400", {"item_id": itemA, "message": "x"}, 400),
        ("B4-3", "eigene Anzeige kontaktieren -> 400", {"item_id": itemB, "message": "QA Test"}, 400),
        ("B4-4", "Item nicht active (pending) -> abgelehnt (SOLL 09.10.: 404 via RLS-Blindheit akzeptiert, 403 moeglich)", {"item_id": itemC, "message": "QA Test"}, (403, 404)),
        ("B4-5", "unbekannte UUID -> 404", {"item_id": str(U.uuid4()), "message": "QA Test"}, 404),
    ]
    for cid, desc, payload, want in cases:
        st, body = http("POST", BASE + "/api/marketplace/contact", payload, opener=opB)
        ok = st in want if isinstance(want, (tuple, list)) else st == want
        check(cid, desc, ok, f"http={st} (erwartet {want}) body={body[:60]}")

    st, body = http("POST", BASE + "/api/marketplace/contact", {"item_id": itemA, "message": "QA Msgcenter Verify E2E"}, opener=opB)
    check("B2-1", "POST /contact mit Session -> 201 {ok:true}", st == 201 and '"ok":true' in body.replace(" ", ""), f"http={st} body={body[:60]}")
    rc, out = psql(f"SELECT count(*) FROM marketplace_messages WHERE listing_id='{itemA}' AND from_user='{uidB}' AND to_user='{uidA}';")
    d22 = [l.strip() for l in out.splitlines() if l.strip().isdigit()]
    check("B2-2", "marketplace_messages-Zeile (listing/from/to) via SQL", rc == 0 and d22 and d22[-1] == "1",
          out.strip().replace("\n", " ")[:120])
    rc, out = psql(f"SELECT count(*) FROM marketplace_contacts WHERE item_id='{itemA}';")
    d23 = [l.strip() for l in out.splitlines() if l.strip().isdigit()]
    check("B2-3", "KEIN marketplace_contacts-Insert (0 Zeilen)", d23 and d23[-1] == "0", out.strip().replace("\n", " ")[:120])
    rc, out = psql(f"SELECT count(*) FROM marketplace_messages WHERE listing_id='{itemC}';")
    d46 = [l.strip() for l in out.splitlines() if l.strip().isdigit()]
    check("B4-6", "KEIN Insert fuer abgelehntes/pending Item C", d46 and d46[-1] == "0", out.strip().replace("\n", " ")[:120])

    # ── 5. C-BLOCK: RLS-Proofs ──────────────────────────────────────────────
    neg = (f"BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims TO '{{\"sub\":\"{uidB}\"}}'; "
           f"INSERT INTO marketplace_messages (listing_id, from_user, to_user, message) VALUES ('{itemA}','{uidA}','{uidB}','rls-neg'); ROLLBACK;")
    rc, out = psql(neg)
    check("C1", "RLS: INSERT fremder from_user -> verweigert", rc != 0 and "row-level security" in out, out.strip()[-120:])
    pos = (f"BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims TO '{{\"sub\":\"{uidB}\"}}'; "
           f"INSERT INTO marketplace_messages (listing_id, from_user, to_user, message) VALUES ('{itemA}','{uidB}','{uidA}','rls-pos'); ROLLBACK;")
    rc, out = psql(pos)
    check("C2", "RLS: INSERT eigener from_user -> erlaubt (ROLLBACK)", rc == 0 and "INSERT 0 1" in out, out.strip()[-120:])
    uidC = str(U.uuid4())
    for cid, sub, want in (("C3-1", uidC, "0"), ("C3-2", uidB, "1")):
        rc, out = psql(f"BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims TO '{{\"sub\":\"{sub}\"}}'; "
                       f"SELECT count(*) FROM marketplace_messages WHERE listing_id='{itemA}'; ROLLBACK;")
        rows = [l.strip() for l in out.splitlines() if l.strip().isdigit()]
        check(cid, f"RLS: Thread-Sichtbarkeit sub={sub[:8]} -> {want} Zeile(n)", rows and rows[-1] == want, out.strip().replace("\n", " ")[:120])

finally:
    # ── CLEANUP (DSGVO): messages -> items -> profiles -> users ─────────────
    del_m = del_i = 0
    for iid in (itemA, itemB, itemC):
        if iid:
            psql(f"DELETE FROM marketplace_messages WHERE listing_id='{iid}';")
    rc, out = psql("DELETE FROM marketplace_messages WHERE message LIKE 'QA Msgcenter Verify%' OR message LIKE 'rls-%';")
    if itemA or itemB or itemC:
        ids = ",".join(f"'{i}'" for i in (itemA, itemB, itemC) if i)
        rc, out = psql(f"DELETE FROM marketplace_items WHERE id IN ({ids});"); del_i = out.count("DELETE")
    if uidA or uidB:
        uids = ",".join(f"'{u}'" for u in (uidA, uidB) if u)
        psql(f"DELETE FROM profiles WHERE id IN ({uids});")
        psql(f"DELETE FROM auth.users WHERE id IN ({uids});")
    rc, out = psql("SELECT (SELECT count(*) FROM marketplace_items WHERE title LIKE 'QA Msgcenter%') + "
                   "(SELECT count(*) FROM marketplace_messages WHERE message LIKE 'QA Msgcenter Verify%');")
    rows = [l.strip() for l in out.splitlines() if l.strip().isdigit()]
    check("X1", "CLEANUP: 0 Rest-Zeilen (Items+Messages der Tests)", rows and rows[-1] == "0", f"reste={rows[-1] if rows else '?'}")

n_ok = sum(1 for x in R if x["ok"])
n_all = len(R)
urteil = "GRUEN" if n_ok == n_all else "ROT"
print(json.dumps({"urteil": urteil, "checks": R}, ensure_ascii=False))
print(f"ALLE CHECKS GRUEN ({n_ok}/{n_all})" if urteil == "GRUEN" else f"NICHT GRUEN: {n_all - n_ok}/{n_all} fehlgeschlagen")
sys.exit(0 if urteil == "GRUEN" else 1)
