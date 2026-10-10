# Verify-Scripte (Carp24)

Ende-zu-Ende-Tests gegen laufende App + Supabase-DB. Alle Scripte legen Test-User/Items an und **räumen am Ende selbst auf** (X1-Cleanup-Check).

## Nutzung

```bash
# lokal (DEV) oder via ssh auf dem Hetzner (LIVE):
python3 tests/verify/msgcenter.py    # Nachrichtenzentrale, 28 Checks
python3 tests/verify/p4-e2e.py       # Premium/Abos, 13 Checks
python3 tests/verify/imap.py         # Mailversand, 10 Checks
```

Pfade im Script an die Umgebung anpassen (sed oder direkt):
- `REPO` → Repo-Root (lokal `/mnt/projekte/carp24-fangbuch`, Hetzner `/opt/carp24` mit Symlink `web → src`)
- `SU` (Supabase-REST) → **die App-DB**, also `http://127.0.0.1:8055` (Hetzner) — NICHT den Hermes-Host-Teststack (`100.93.250.103:8055`), sonst „Invalid login credentials"
- `BASE` → `https://carp24.org` (LIVE) bzw. `http://localhost:8094` (DEV-Container)
- `.env` lesen aus `/opt/carp24/.env` (Hetzner) — braucht `SUPABASE_SERVICE_ROLE_KEY`

## Harte Lektionen (bitte beachten)

1. **Beiden Test-Usern ein Abo geben** (`subscriptions` INSERT via service_role): die Marktplatz-RLS ist Premium-gegated (Policy `is_user_premium()`). Nur User A mit Abo → Checks laufen mit User B → 403-Falle.
2. **Migrations nur via `supabase_admin`** (`docker exec -i supabase-db psql -U supabase_admin < migration.sql`) — `postgres` ist kein Owner der Funktionen und darf sie nicht ersetzen.
3. DEV-App (`carp24-dev` :8094) und LIVE (`carp24-app` :4321) liegen beide auf dem Hetzner und nutzen **dieselbe DB**. Tests schreiben echte Daten — Cleanup ist Pflicht.
4. `subscriptions` hat UNIQUE pro user_id — doppelter INSERT schlägt fehl (2. Zeile ignorieren).
5. Quotes in ssh-heredoc: `chr()`-Tricks oder scp-roundtrip, keine global replaces (zerstört f-strings in den Scripten).

## Stand

10.10.2026 — msgcenter 28/28 grün gegen LIVE (nach Premium-Migration `20261010140000`).
