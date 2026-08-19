#!/usr/bin/env python3
# carp24 Stitch-Master: 6 Desktop-Screens sequenziell generieren + downloaden (direkter API-Weg)
# Methode: stitch-mcp-usage skill, scripts/stitch-direct.sh (19.08.2026)
import json, os, subprocess, sys, time, re

PROJECT_ID = "18051329713568778931"
DESIGN_SYSTEM = "assets/9ae0bc7fe13b44e49da8fbee7c9a32be"
QUOTA = "api-project-1005187117241"
PROFILE_HOME = "/home/philipp/.hermes/profiles/agentur-berater/home"
GCLOUD = PROFILE_HOME + "/.stitch-mcp/google-cloud-sdk/bin/gcloud"
OUT_DIR = "/mnt/projekte/carp24-fangbuch/design/screens"

SCREENS = [x for x in [

    {
        "name": "catch-form",
        "title": "Catch Form",
        "prompt": (
            "Create the CATCH FORM screen for carp24, a premium fishing logbook app. "
            "Desktop view. Warm sand background #E8E0C8, khaki #CCCA9B, olive green accents #6C7A57, "
            "water blue #7B9496, dark moss text #1A1F16. Editorial, minimalist, lots of whitespace. "
            "Source Serif 4 headlines, Source Sans 3 body, JetBrains Mono uppercase labels with letter spacing. "
            "Screen: header with logo and nav, then a clean two-column catch entry form: "
            "left column date, water name, species select; right column weight in kg, length in cm, air and water temperature; "
            "full-width photo upload area with dashed border, notes textarea, catch and release toggle, "
            "prominent olive save button. Nothing else."
        ),
    },
    {
        "name": "catch-list",
        "title": "Catch List",
        "prompt": (
            "Create the CATCH LIST screen for carp24, a premium fishing logbook app. "
            "Desktop view. Warm sand background #E8E0C8, khaki #CCCA9B, olive green accents #6C7A57, "
            "water blue #7B9496, dark moss text #1A1F16. Editorial, minimalist, lots of whitespace. "
            "Source Serif 4 headlines, Source Sans 3 body, JetBrains Mono uppercase labels. "
            "Screen: header with logo and nav, page title CATCHES with total count, "
            "filter bar with search input, species filter, water filter, sort by date or weight, "
            "then a list of catch rows with thumbnail photo, species, weight in kg, date, water name; "
            "a quick add button. Nothing else."
        ),
    },
    {
        "name": "catch-detail",
        "title": "Catch Detail",
        "prompt": (
            "Create the CATCH DETAIL screen for carp24, a premium fishing logbook app. "
            "Desktop view. Warm sand background #E8E0C8, khaki #CCCA9B, olive green accents #6C7A57, "
            "water blue #7B9496, dark moss text #1A1F16. Editorial, minimalist, lots of whitespace. "
            "Source Serif 4 headlines, Source Sans 3 body, JetBrains Mono uppercase labels. "
            "Screen: header with logo and nav, large catch photo as hero, species name as headline, "
            "metadata row with weight, length, date, water, air and water temperature, "
            "catch and release badge, personal notes section, edit and delete buttons, share button. "
            "Sidebar with small stats. Nothing else."
        ),
    },
    {
        "name": "dashboard",
        "title": "Dashboard",
        "prompt": (
            "Create the DASHBOARD screen for carp24, a premium fishing logbook app. "
            "Desktop view. Warm sand background #E8E0C8, khaki #CCCA9B, olive green accents #6C7A57, "
            "water blue #7B9496, dark moss text #1A1F16. Editorial, minimalist, lots of whitespace. "
            "Source Serif 4 headlines, Source Sans 3 body, JetBrains Mono uppercase labels. "
            "Screen: header with logo and nav, greeting headline, four stat cards with total catches, "
            "biggest carp, catches this year, active waters, a bar chart of catches per month, "
            "recent catches list with thumbnails, prominent quick add catch button. Nothing else."
        ),
    },
    {
        "name": "profile",
        "title": "Profile",
        "prompt": (
            "Create the PROFILE screen for carp24, a premium fishing logbook app. "
            "Desktop view. Warm sand background #E8E0C8, khaki #CCCA9B, olive green accents #6C7A57, "
            "water blue #7B9496, dark moss text #1A1F16. Editorial, minimalist, lots of whitespace. "
            "Source Serif 4 headlines, Source Sans 3 body, JetBrains Mono uppercase labels. "
            "Screen: header with logo and nav, user avatar, name, member since, stat row with catches and best weight, "
            "settings sections for units kg or lbs, language, notification preferences, "
            "subscription status card, logout button. Nothing else."
        ),
    },
    {
        "name": "paywall",
        "title": "Paywall",
        "prompt": (
            "Create the UPGRADE PAYWALL screen for carp24, a premium fishing logbook app. "
            "Desktop view. Warm sand background #E8E0C8, khaki #CCCA9B, olive green accents #6C7A57, "
            "water blue #7B9496, dark moss text #1A1F16. Editorial, minimalist, lots of whitespace. "
            "Source Serif 4 headlines, Source Sans 3 body, JetBrains Mono uppercase labels. "
            "Screen: header with logo and nav, headline UPGRADE TO PREMIUM, "
            "two pricing cards FREE and PREMIUM side by side with feature lists, PREMIUM card highlighted in olive, "
            "monthly and yearly toggle, prominent upgrade button, small note about one-time purchase. Nothing else."
        ),
    },
] if x["name"] in ("profile", "paywall")]

def get_token():
    env = dict(os.environ); env["HOME"] = PROFILE_HOME
    out = subprocess.run([GCLOUD, "auth", "application-default", "print-access-token"],
                         capture_output=True, text=True, env=env)
    token = out.stdout.strip().splitlines()[-1] if out.stdout.strip() else ""
    if not token:
        raise SystemExit("Kein ADC-Token")
    return token

def generate(token, prompt):
    args = {
        "projectId": PROJECT_ID,
        "prompt": prompt,
        "deviceType": "DESKTOP",
        "modelId": "GEMINI_3_PRO",
        "designSystem": DESIGN_SYSTEM,
    }
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                          "params": {"name": "generate_screen_from_text", "arguments": args}})
    r = subprocess.run(["curl", "-s", "-X", "POST", "https://stitch.googleapis.com/mcp",
                        "-H", f"Authorization: Bearer {token}",
                        "-H", "Content-Type: application/json",
                        "-H", f"X-Goog-User-Project: {QUOTA}",
                        "-d", payload], capture_output=True, text=True, timeout=180)
    try:
        d = json.loads(r.stdout)
    except Exception:
        return None, r.stdout[:300]
    if "error" in d:
        return None, json.dumps(d["error"])[:500]
    try:
        text = d["result"]["content"][0]["text"]
        resp = json.loads(text)
    except Exception:
        return None, r.stdout[:500]
    return resp, None

def extract_and_download(resp, out_dir, name):
    found = False
    for c in resp.get("outputComponents", []):
        for s in (c.get("design") or {}).get("screens") or []:
            found = True
            title = s.get("title") or name
            w, h = s.get("width"), s.get("height")
            dev = s.get("deviceType")
            print(f"  SCREEN: {title} | {w}x{h} | {dev}")
            shot = s.get("screenshot", {}); html = s.get("htmlCode", {})
            if shot.get("downloadUrl"):
                subprocess.run(["curl", "-sL", "-o", f"{out_dir}/{name}.png", shot["downloadUrl"]], timeout=120)
                print(f"  PNG -> {out_dir}/{name}.png")
            if html.get("downloadUrl"):
                subprocess.run(["curl", "-sL", "-o", f"{out_dir}/{name}.html", html["downloadUrl"]], timeout=120)
                print(f"  HTML -> {out_dir}/{name}.html")
            # sessionId / screenId für Log
            sid = resp.get("sessionId", "?")
            print(f"  sessionId={sid}")
            return True
    return False

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    token = get_token()
    print(f"Token OK ({len(token)} Zeichen)\n")
    ok, fail = [], []
    for sc in SCREENS:
        name, prompt = sc["name"], sc["prompt"]
        print(f"=== [{name}] {sc['title']} ===")
        resp, err = None, None
        for attempt in range(1, 4):
            print(f"  Versuch {attempt}/3 ...")
            resp, err = generate(token, prompt)
            if err:
                print(f"  API-Fehler: {err[:200]}")
                time.sleep(8); continue
            if extract_and_download(resp, OUT_DIR, name):
                ok.append(name); break
            print("  Kein Screen in Antwort, rohes Text-Fragment:")
            try:
                print(" ", json.dumps(resp)[:400])
            except Exception:
                print(" ", str(resp)[:400])
            time.sleep(8)
        else:
            fail.append(name)
            print(f"  FEHLGESCHLAGEN: {name}")
        print()
    print("=== ERGEBNIS ===")
    print("OK:", ", ".join(ok) if ok else "-")
    print("FAIL:", ", ".join(fail) if fail else "-")
    # Verifikation: Dateien
    for name in ok:
        for ext in ("png", "html"):
            p = f"{OUT_DIR}/{name}.{ext}"
            if os.path.exists(p):
                sz = os.path.getsize(p)
                print(f"  {name}.{ext}: {sz} B")
    sys.exit(1 if fail else 0)

if __name__ == "__main__":
    main()
