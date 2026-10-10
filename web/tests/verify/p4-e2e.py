#!/usr/bin/env python3
"""c24-p4-e2e (09.10.2026): P4 E2E Nachrichtenzentrale (P3-Flows) + messages.ts-Mail IMAP.
S1 Creds | S2 User A (Zoho-Alias)+B | S3 Item (active, Owner=A)
P1 Send-POST B->A 201 + DB-Zeile (read_at NULL)
P2 /nachrichten SSR: 200 + Thread-Titel + Postfach-Nav
P3 Thread-URL SSR: 200 + Bubble-Text + 'Nachricht senden' + mode=read
P4 mode=inbox: unread_total=1 + thread unread_count=1
P5 mode=read ok + SQL read_at NOT NULL
P6 mode=inbox: unread_total=0
P7a/b/c IMAP: Subject + TO=Alias + Deep-Link /nachrichten?listing_id= (QP-dekodiert)
X1 CLEANUP: 0 Rest-Zeilen + Test-User geloescht. Ausgabe NUR Status/IDs + JSON, KEINE Creds."""
import json, re, subprocess, sys, time, imaplib, quopri, urllib.request, urllib.error
from http.cookiejar import CookieJar
from email import message_from_bytes

BASE = "http://localhost:8094"
SU = "http://100.93.250.103:8055"
AUTH = SU + "/auth/v1"
REST = SU + "/rest/v1"
TS = int(time.time())
ALIAS = f"info+qa-p4-{TS}@einfach-online.dev"
PW = f"Qa-P4-{TS}-Aa1"
MSG = f"hallo p4e2e-{TS} konversation"
RES = []

def check(cid, desc, ok, detail=""):
    RES.append({"id": cid, "ok": bool(ok), "detail": detail[:220]})
    print(("✅ VERIFIZIERT" if ok else "❌ FEHLER") + f" [{cid}] {desc} (Beweis: {detail[:160]})")

envd = {}
with open("/mnt/projekte/carp24-fangbuch/web/.env") as f:
    for line in f:
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', line.rstrip("\n"))
        if m:
            envd[m.group(1)] = m.group(2).strip().strip('"').strip("'")
SKEY = envd.get("SUPABASE_SERVICE_ROLE_KEY", "")
IMAP_HOST = (envd.get("SMTP_HOST") or "imap.zoho.eu").replace("smtp.", "imap.", 1)
SMTP_USER = envd.get("SMTP_USER", "")
SMTP_PASS = envd.get("SMTP_PASS", "")
adm = {"apikey": SKEY, "Authorization": "Bearer " + SKEY}
check("S1", "Creds geladen (len/prefix only)", len(SKEY) > 40 and len(SMTP_USER) > 5 and len(SMTP_PASS) > 5,
      f"skey_len={len(SKEY)} smtp_user_len={len(SMTP_USER)} imap_host_len={len(IMAP_HOST)}")

def http(method, url, body=None, headers=None, opener=None, timeout=25):
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
        return 0, str(e)

def psql(sql, timeout=30):
    p = subprocess.run(["docker", "exec", "supabase-db", "psql", "-U", "postgres", "-d", "postgres",
                        "-v", "ON_ERROR_STOP=1", "-t", "-A", "-c", sql],
                       capture_output=True, text=True, timeout=timeout)
    return (p.stdout + p.stderr).strip()

def admin_create(email):
    st, body = http("POST", AUTH + "/admin/users", {"email": email, "password": PW, "email_confirm": True}, adm)
    m = re.search(r'"id":"([0-9a-f-]{36})"', body)
    return (m.group(1) if m else None), st

def login(email):
    jar = CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    st = 0
    for _attempt in range(4):
        st, _ = http("POST", BASE + "/api/auth/login", {"email": email, "password": PW}, opener=op)
        if st != 429:
            break
        time.sleep(30)
    return op, st

def imap_scan(alias, needle, tries=6):
    hit_sub = hit_to = hit_link = False
    for _ in range(tries):
        try:
            M = imaplib.IMAP4_SSL(IMAP_HOST, 993)
            M.login(SMTP_USER, SMTP_PASS)
            M.select("INBOX")
            typ, data = M.search(None, "ALL")
            ids = data[0].split()[-15:]
            for i in ids:
                typ2, msg2 = M.fetch(i, "(BODY.PEEK[HEADER])")
                hdr = message_from_bytes(msg2[0][1])
                subj = str(hdr.get("Subject", ""))
                to = str(hdr.get("To", ""))
                if "Neue Nachricht auf carp24" not in subj:
                    continue
                hit_sub = True
                if alias in to:
                    hit_to = True
                typ3, msg3 = M.fetch(i, "(BODY.PEEK[TEXT])")
                raw = msg3[0][1] if isinstance(msg3[0][1], bytes) else str(msg3[0][1]).encode("utf-8", "replace")
                body_txt = quopri.decodestring(raw).decode("utf-8", "replace")
                if needle in body_txt:
                    hit_link = True
            M.logout()
        except Exception:
            pass
        if hit_sub and hit_to and hit_link:
            break
        time.sleep(15)
    return hit_sub, hit_to, hit_link

iid = uidA = uidB = None
try:
    uidA, stA = admin_create(ALIAS)
    uidB, stB = admin_create(f"qa-p4b-{TS}@carp24.dev")
    check("S2", "Test-User A (Zoho-Alias) + B via Admin-API", bool(uidA and uidB),
          f"A={uidA} alias={ALIAS} B={uidB} http={stA}/{stB}")
    if not (uidA and uidB):
        raise SystemExit(1)
    st, body = http("POST", REST + "/marketplace_items",
                    {"user_id": uidA, "title": f"QA P4 {TS}", "price": 1, "category": "Ruten", "status": "active"},
                    {**adm, "Prefer": "return=representation"})
    m = re.search(r'"id":"([0-9a-f-]{36})"', body)
    iid = m.group(1) if m else None
    check("S3", "Item (active, Owner=A) angelegt", bool(iid), f"item={iid} http={st}")

    # ── P1: Send-POST B->A (messages.ts, kein mode) ─────────────────────────
    opB, stL = login(f"qa-p4b-{TS}@carp24.dev")
    st, body = http("POST", BASE + "/api/marketplace/messages",
                    {"listing_id": iid, "to_user": uidA, "message": MSG}, opener=opB)
    rows = psql(f"SELECT count(*) FROM marketplace_messages WHERE listing_id='{iid}' AND from_user='{uidB}' AND to_user='{uidA}' AND read_at IS NULL;")
    check("P1", "Send-POST B->A -> 201 + DB-Zeile (read_at NULL)", st == 201 and rows.startswith("1"),
          f"http={st} body={body[:40]} rows={rows[:20]}")

    # ── P2: /nachrichten SSR als A ──────────────────────────────────────────
    opA, stLA = login(ALIAS)
    st, html = http("GET", BASE + "/nachrichten", opener=opA)
    check("P2", "/nachrichten SSR: 200 + Thread-Titel + Postfach-Nav",
          st == 200 and f"QA P4 {TS}" in html and "Postfach" in html and 'href="/nachrichten"' in html,
          f"http={st} titel={f'QA P4 {TS}' in html} postfach={'Postfach' in html} navlink={'/nachrichten' in html}")

    # ── P3: Thread-URL SSR (Bubbles) ────────────────────────────────────────
    st, html2 = http("GET", BASE + f"/nachrichten?listing_id={iid}&with_user={uidB}", opener=opA)
    check("P3", "Thread-URL SSR: 200 + Bubble-Text + Send-UI + mode=read",
          st == 200 and MSG in html2 and "Nachricht senden" in html2 and "mode=read" in html2,
          f"http={st} bubble={MSG in html2} sendui={'Nachricht senden' in html2} read={'mode=read' in html2}")

    # ── P4: inbox unread=1 ──────────────────────────────────────────────────
    st, body = http("GET", BASE + "/api/marketplace/messages?mode=inbox", opener=opA)
    try:
        d = json.loads(body)
    except Exception:
        d = {}
    ut = d.get("unread_total")
    any_uc = any(t.get("unread_count") == 1 for t in d.get("threads", []))
    check("P4", "mode=inbox: unread_total=1 + thread unread_count=1", ut == 1 and any_uc,
          f"http={st} unread_total={ut} thread_unread1={any_uc}")

    # ── P5: mode=read setzt read_at ─────────────────────────────────────────
    st, body = http("POST", BASE + "/api/marketplace/messages?mode=read",
                    {"listing_id": iid, "with_user": uidB}, opener=opA)
    rr = psql(f"SELECT count(*) FROM marketplace_messages WHERE listing_id='{iid}' AND to_user='{uidA}' AND read_at IS NOT NULL;")
    check("P5", "mode=read ok + SQL read_at NOT NULL", st == 200 and rr.startswith("1"),
          f"http={st} rows_read={rr[:20]}")

    # ── P6: inbox unread=0 ──────────────────────────────────────────────────
    st, body = http("GET", BASE + "/api/marketplace/messages?mode=inbox", opener=opA)
    try:
        d2 = json.loads(body)
    except Exception:
        d2 = {}
    check("P6", "mode=inbox: unread_total=0 nach Read", d2.get("unread_total") == 0,
          f"http={st} unread_total={d2.get('unread_total')}")

    # ── P7: IMAP messages.ts-Mailpfad ───────────────────────────────────────
    hs, ht, hl = imap_scan(ALIAS, "/nachrichten?listing_id=")
    check("P7a", "IMAP: Mail 'Neue Nachricht auf carp24' im INBOX", hs, "Subject-Match unter letzten 15")
    check("P7b", "IMAP: Empfaenger = A-Alias", ht, f"TO enthaelt {ALIAS}")
    check("P7c", "IMAP: Deep-Link /nachrichten?listing_id= (QP-dekodiert)", hl, "Body-Needle nach quopri")
finally:
    # ── X1: CLEANUP ─────────────────────────────────────────────────────────
    if iid:
        psql(f"DELETE FROM marketplace_messages WHERE listing_id='{iid}';")
        psql(f"DELETE FROM marketplace_items WHERE id='{iid}';")
    for u in (uidA, uidB):
        if u:
            http("DELETE", AUTH + f"/admin/users/{u}", None, adm)
    reste = psql(f"SELECT count(*) FROM marketplace_messages WHERE listing_id='{iid}';") if iid else "?"
    resti = psql(f"SELECT count(*) FROM marketplace_items WHERE id='{iid}';") if iid else "?"
    ua = http("GET", AUTH + f"/admin/users/{uidA}", None, adm)[0] if uidA else "?"
    ub = http("GET", AUTH + f"/admin/users/{uidB}", None, adm)[0] if uidB else "?"
    check("X1", "CLEANUP: 0 Rest-Zeilen + Test-User weg", reste.startswith("0") and resti.startswith("0") and ua == 404 and ub == 404,
          f"reste={reste[:10]} resti={resti[:10]} user_http={ua}/{ub}")

ok_n = sum(1 for r in RES if r["ok"])
verdict = "GRUEN" if ok_n == len(RES) else "ROT"
print(json.dumps({"urteil": verdict, "checks": RES}, ensure_ascii=False))
print(f"ALLE CHECKS GRUEN ({ok_n}/{len(RES)})" if verdict == "GRUEN" else f"NICHT GRUEN: {len(RES)-ok_n}/{len(RES)} fehlgeschlagen")
sys.exit(0 if verdict == "GRUEN" else 1)
