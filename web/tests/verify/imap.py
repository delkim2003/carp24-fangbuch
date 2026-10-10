#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""c24-imap-verify (09.10.2026): P4-IMAP-Beweis fuer P2.3 Contact-Mail.
I1: Mail 'Neue Nachricht auf carp24' erreicht Zoho INBOX | I2: Empfaenger = Owner-Alias | I3: Deep-Link /nachrichten?listing_id= im Body
B2: marketplace_messages-Zeile | X1: Cleanup 0 Rest-Zeilen. Ausgabe: NUR Status/IDs, KEINE Creds."""
import json, re, subprocess, sys, time, imaplib, quopri, urllib.request, urllib.error, uuid as U
from http.cookiejar import CookieJar
from email.header import decode_header
from email import message_from_bytes

REPO = "/mnt/projekte/carp24-fangbuch"
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

uidA = uidB = itemA = None
BASE = SU = None

try:
    envd = {}
    for line in open(ENVF, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            envd[k.strip()] = v.strip()
    SRV = envd.get("SUPABASE_SERVICE_ROLE_KEY", "")
    SMTP_USER = envd.get("SMTP_USER", "")
    SMTP_PASS = envd.get("SMTP_PASS", "")
    check("S1", "Creds geladen (len/prefix only)", len(SRV) > 50 and len(SMTP_USER) > 5 and len(SMTP_PASS) > 5,
          f"srv_len={len(SRV)} smtp_user_len={len(SMTP_USER)} smtp_pass_len={len(SMTP_PASS)}")

    for cand in ("http://localhost:8094", "http://localhost:4321"):
        st, _b = http("POST", cand + "/api/auth/login", {})
        if st >= 200:
            BASE = cand
            break
    for cand in (envd.get("PUBLIC_SUPABASE_URL", ""), "http://localhost:8055", "http://100.93.250.103:8055"):
        if not cand:
            continue
        st, _b = http("GET", cand.rstrip("/") + "/auth/v1/health", headers={"apikey": SRV})
        if st > 0:
            SU = cand.rstrip("/")
            break
    check("S2", "DEV-Server + Supabase REST erreichbar", bool(BASE and SU), f"BASE={BASE} SU={SU}")
    if not (BASE and SU):
        raise SystemExit(1)

    REST = SU + "/rest/v1"
    AUTH = SU + "/auth/v1"
    adm = {"apikey": SRV, "Authorization": "Bearer " + SRV}
    ts_ = int(time.time())
    alias = f"info+qa-msgc-{ts_}@einfach-online.dev"

    st, body = http("POST", AUTH + "/admin/users", {"email": alias, "password": f"Qa-Imap-{ts_}-Aa1", "email_confirm": True}, adm)
    m = re.search(r'"id":"([0-9a-f-]{36})"', body)
    uidA = m.group(1) if m else None
    st2, body2 = http("POST", AUTH + "/admin/users", {"email": f"qa-imap-{ts_}-b@carp24.dev", "password": f"Qa-Imap-{ts_}-Bb1", "email_confirm": True}, adm)
    m2 = re.search(r'"id":"([0-9a-f-]{36})"', body2)
    uidB = m2.group(1) if m2 else None
    check("S3", "User A (Zoho-Alias) + User B via Admin-API", bool(uidA and uidB), f"A={uidA} alias={alias} B={uidB}")

    st, body = http("POST", REST + "/marketplace_items",
                    {"user_id": uidA, "title": "QA IMAP Beweis", "price": 1, "category": "Ruten", "status": "active"},
                    {**adm, "Prefer": "return=representation"})
    m = re.search(r'"id":"([0-9a-f-]{36})"', body)
    itemA = m.group(1) if m else None
    check("S4", "Item (active, Owner=A) angelegt", bool(itemA) and st in (200, 201), f"item={itemA} http={st}")

    jar = CookieJar()
    opB = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    for _attempt in range(4):
        st, body = http("POST", BASE + "/api/auth/login", {"email": f"qa-imap-{ts_}-b@carp24.dev", "password": f"Qa-Imap-{ts_}-Bb1"}, opener=opB)
        if st != 429:
            break
        time.sleep(30)
    st, body = http("POST", BASE + "/api/marketplace/contact",
                    {"item_id": itemA, "message": "IMAP E2E Beweis Nachricht fuer P2.3 Mailversand."}, opener=opB)
    check("B1", "POST /contact als B -> 201 (Mail wird ausgeloest)", st == 201 and '"ok":true' in body.replace(" ", ""), f"http={st} body={body[:60]}")

    rc, out = psql(f"SELECT count(*) FROM marketplace_messages WHERE listing_id='{itemA}' AND from_user='{uidB}' AND to_user='{uidA}';")
    d = [l.strip() for l in out.splitlines() if l.strip().isdigit()]
    check("B2", "marketplace_messages-Zeile via SQL", d and d[-1] == "1", out.strip().replace("\n", " ")[:100])

    # IMAP-Beweis (Pattern Moderations-E2E Schritt 7, 3/3 bewiesen)
    time.sleep(15)
    M = imaplib.IMAP4_SSL("imap.zoho.eu", 993)
    M.login(SMTP_USER, SMTP_PASS)
    M.select("INBOX")
    typ, data = M.search(None, "ALL")
    ids = data[0].split()[-15:]
    hit_subj = hit_to = hit_link = False
    for i in ids:
        typ, msg = M.fetch(i, "(BODY.PEEK[HEADER.FIELDS (TO SUBJECT)])")
        hdr = message_from_bytes(msg[0][1])
        raw = hdr.get("Subject", "")
        parts = decode_header(raw)
        subj = "".join(p.decode("utf-8", "replace") if isinstance(p, bytes) else p for p, _ in parts)
        to = hdr.get("To", "")
        if "Neue Nachricht auf carp24" in subj:
            hit_subj = True
            if alias in to:
                hit_to = True
            typ2, msg2 = M.fetch(i, "(BODY.PEEK[TEXT])")
            body_raw = msg2[0][1] if isinstance(msg2[0][1], bytes) else str(msg2[0][1]).encode("utf-8", "replace")
            body_txt = quopri.decodestring(body_raw).decode("utf-8", "replace")
            if "/nachrichten?listing_id=" in body_txt:
                hit_link = True
    M.logout()
    check("I1", "Mail 'Neue Nachricht auf carp24' im Zoho INBOX", hit_subj, "Subject-Match unter letzten 15 Mails")
    check("I2", "Empfaenger = Owner-Alias", hit_to, f"TO enthaelt {alias}")
    check("I3", "Deep-Link /nachrichten?listing_id= im Mail-Body (P3-Link)", hit_link, "Body-Peek aller Subject-Treffer")

finally:
    for iid in (itemA,):
        if iid:
            psql(f"DELETE FROM marketplace_messages WHERE listing_id='{iid}';")
            psql(f"DELETE FROM marketplace_items WHERE id IN ('{iid}');")
    if uidA or uidB:
        uids = ",".join(f"'{u}'" for u in (uidA, uidB) if u)
        psql(f"DELETE FROM profiles WHERE id IN ({uids});")
        psql(f"DELETE FROM auth.users WHERE id IN ({uids});")
    rc, out = psql("SELECT (SELECT count(*) FROM marketplace_items WHERE title='QA IMAP Beweis') + "
                   "(SELECT count(*) FROM marketplace_messages WHERE message LIKE 'IMAP E2E Beweis%');")
    d = [l.strip() for l in out.splitlines() if l.strip().isdigit()]
    check("X1", "CLEANUP: 0 Rest-Zeilen", d and d[-1] == "0", f"reste={d[-1] if d else '?'}")

n_ok = sum(1 for x in R if x["ok"])
n_all = len(R)
urteil = "GRUEN" if n_ok == n_all else "ROT"
print(json.dumps({"urteil": urteil, "checks": R}, ensure_ascii=False))
print(f"ALLE CHECKS GRUEN ({n_ok}/{n_all})" if urteil == "GRUEN" else f"NICHT GRUEN: {n_all - n_ok}/{n_all} fehlgeschlagen")
sys.exit(0 if urteil == "GRUEN" else 1)
