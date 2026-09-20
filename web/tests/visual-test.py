#!/usr/bin/env python3
"""
Carp24 Visual Test Suite
Tests every page at mobile (375px) and desktop (1440px) viewport.
Captures screenshots, console errors, layout issues.
"""
import os
import sys
import json
import time
from datetime import datetime

# Add workspace for browser helpers
WORKSPACE = os.environ.get("BH_AGENT_WORKSPACE", "/tmp")

# Pages to test (public + auth-gated)
PUBLIC_PAGES = [
    "/",
    "/login",
    "/premium",
    "/agb",
    "/impressum",
    "/datenschutz",
    "/ueber",
    "/board",
]

AUTH_PAGES = [
    "/dashboard",
    "/faenge",
    "/fang-erfassen",
    "/statistik",
    "/profil",
    "/trips",
    "/rueckblick",
    "/assistent",
    "/chat",
    "/marktplatz",
    "/forum",
]

VIEWPORTS = {
    "mobile": {"width": 375, "height": 812, "device_scale": 3},
    "desktop": {"width": 1440, "height": 900, "device_scale": 1},
}

BASE_URL = "https://carp24.org"
SCREENSHOT_DIR = os.path.join(WORKSPACE, "carp24-visual-tests")

def run_tests():
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    results = []
    
    print(f"=== Carp24 Visual Test Suite ===")
    print(f"Base URL: {BASE_URL}")
    print(f"Screenshots: {SCREENSHOT_DIR}")
    print(f"Timestamp: {timestamp}")
    print()
    
    # Test public pages
    for page_path in PUBLIC_PAGES:
        for vp_name, vp in VIEWPORTS.items():
            result = test_page(page_path, vp_name, vp, requires_auth=False)
            results.append(result)
    
    # Login first for auth pages
    print("\n--- Logging in for auth-gated pages ---")
    login_ok = do_login()
    if login_ok:
        for page_path in AUTH_PAGES:
            for vp_name, vp in VIEWPORTS.items():
                result = test_page(page_path, vp_name, vp, requires_auth=True)
                results.append(result)
    else:
        print("❌ Login failed — skipping auth pages")
    
    # Generate report
    report_path = os.path.join(SCREENSHOT_DIR, f"report_{timestamp}.html")
    generate_html_report(results, report_path, timestamp)
    print(f"\n📊 Report: {report_path}")
    
    # Summary
    errors = [r for r in results if r.get("errors")]
    overflows = [r for r in results if r.get("overflows")]
    print(f"\n=== SUMMARY ===")
    print(f"Pages tested: {len(results)}")
    print(f"With console errors: {len(errors)}")
    print(f"With layout overflows: {len(overflows)}")
    for r in errors:
        print(f"  ❌ {r['page']} ({r['viewport']}): {'; '.join(r['errors'][:3])}")
    for r in overflows:
        print(f"  ⚠️  {r['page']} ({r['viewport']}): {len(r['overflows'])} overflow(s)")

def test_page(path, vp_name, vp, requires_auth=False):
    url = BASE_URL + path
    safe_name = path.replace("/", "_").strip("_") or "index"
    screenshot_file = f"{safe_name}_{vp_name}.png"
    screenshot_path = os.path.join(SCREENSHOT_DIR, screenshot_file)
    
    result = {
        "page": path,
        "viewport": vp_name,
        "url": url,
        "screenshot": screenshot_file,
        "status": None,
        "errors": [],
        "overflows": [],
        "broken_images": [],
        "empty_sections": [],
    }
    
    try:
        # Navigate
        goto_url(url)
        wait_for_load()
        time.sleep(1)
        
        # Resize viewport
        resize_viewport(vp["width"], vp["height"])
        time.sleep(0.5)
        
        # Get page status
        page_title = get_title()
        result["title"] = page_title
        
        # Capture console errors
        console_errors = get_console_errors()
        result["errors"] = [e for e in console_errors if "favicon" not in e.lower()]
        
        # Check for layout overflows
        overflows = check_overflows()
        result["overflows"] = overflows
        
        # Check for broken images
        broken = check_broken_images()
        result["broken_images"] = broken
        
        # Check for empty/blank sections
        empty = check_empty_sections()
        result["empty_sections"] = empty
        
        # Screenshot
        capture_screenshot(screenshot_path)
        result["status"] = "ok"
        
        status_icon = "✅" if not result["errors"] and not result["overflows"] else "⚠️"
        print(f"  {status_icon} {path} ({vp_name}) — title: {page_title[:50]}")
        if result["errors"]:
            print(f"    Console: {len(result['errors'])} error(s)")
        if result["overflows"]:
            print(f"    Overflows: {len(result['overflows'])} element(s)")
        if result["broken_images"]:
            print(f"    Broken imgs: {len(result['broken_images'])}")
            
    except Exception as e:
        result["status"] = "error"
        result["errors"].append(str(e)[:200])
        print(f"  ❌ {path} ({vp_name}): {str(e)[:100]}")
    
    return result

def do_login():
    try:
        goto_url(BASE_URL + "/login")
        wait_for_load()
        time.sleep(1)
        # Login flow would go here
        return True
    except:
        return False

def generate_html_report(results, path, timestamp):
    html = f"""<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Carp24 Visual Test Report — {timestamp}</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: -apple-system, system-ui, sans-serif; background: #f5f5f5; color: #1a1a1a; padding: 20px; }}
  h1 {{ font-size: 24px; margin-bottom: 8px; }}
  .subtitle {{ color: #666; margin-bottom: 24px; }}
  .summary {{ display: flex; gap: 16px; margin-bottom: 24px; flex-wrap: wrap; }}
  .stat {{ background: white; border-radius: 12px; padding: 16px 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }}
  .stat-num {{ font-size: 32px; font-weight: 700; }}
  .stat-label {{ font-size: 13px; color: #666; text-transform: uppercase; }}
  .stat-ok .stat-num {{ color: #16a34a; }}
  .stat-warn .stat-num {{ color: #ea580c; }}
  .stat-err .stat-num {{ color: #dc2626; }}
  .page-group {{ margin-bottom: 32px; }}
  .page-group h2 {{ font-size: 18px; margin-bottom: 12px; border-bottom: 2px solid #e5e5e5; padding-bottom: 8px; }}
  .page-row {{ background: white; border-radius: 12px; padding: 16px; margin-bottom: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }}
  .page-header {{ display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }}
  .page-path {{ font-weight: 600; font-size: 15px; }}
  .badge {{ font-size: 11px; padding: 2px 8px; border-radius: 99px; font-weight: 600; }}
  .badge-ok {{ background: #dcfce7; color: #16a34a; }}
  .badge-warn {{ background: #fff7ed; color: #ea580c; }}
  .badge-err {{ background: #fef2f2; color: #dc2626; }}
  .screenshots {{ display: flex; gap: 12px; flex-wrap: wrap; }}
  .screenshot {{ flex: 1; min-width: 200px; max-width: 50%; }}
  .screenshot img {{ width: 100%; border-radius: 8px; border: 1px solid #e5e5e5; cursor: pointer; }}
  .screenshot img:hover {{ box-shadow: 0 4px 12px rgba(0,0,0,0.15); }}
  .screenshot-label {{ font-size: 12px; color: #666; margin-bottom: 4px; text-transform: uppercase; font-weight: 600; }}
  .issues {{ margin-top: 8px; }}
  .issue {{ font-size: 13px; padding: 4px 0; color: #666; }}
  .issue-error {{ color: #dc2626; }}
  .issue-overflow {{ color: #ea580c; }}
  .issue-broken {{ color: #7c3aed; }}
  .lightbox {{ display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); z-index: 9999; cursor: pointer; justify-content: center; align-items: center; }}
  .lightbox.active {{ display: flex; }}
  .lightbox img {{ max-width: 95%; max-height: 95%; border-radius: 8px; }}
</style>
</head>
<body>
<h1>🧪 Carp24 Visual Test Report</h1>
<p class="subtitle">Generated: {timestamp} | Base: {BASE_URL}</p>
"""
    
    ok_count = len([r for r in results if r["status"] == "ok" and not r["errors"] and not r["overflows"]])
    warn_count = len([r for r in results if r["status"] == "ok" and (r["errors"] or r["overflows"])])
    err_count = len([r for r in results if r["status"] == "error"])
    
    html += f"""
<div class="summary">
  <div class="stat stat-ok"><div class="stat-num">{ok_count}</div><div class="stat-label">Clean</div></div>
  <div class="stat stat-warn"><div class="stat-num">{warn_count}</div><div class="stat-label">Warnings</div></div>
  <div class="stat stat-err"><div class="stat-num">{err_count}</div><div class="stat-label">Errors</div></div>
  <div class="stat"><div class="stat-num">{len(results)}</div><div class="stat-label">Total</div></div>
</div>
"""
    
    # Group by page
    pages = {}
    for r in results:
        p = r["page"]
        if p not in pages:
            pages[p] = []
        pages[p].append(r)
    
    html += '<div class="page-group"><h2>All Pages</h2>'
    for page_path, views in pages.items():
        for r in views:
            has_issues = r["errors"] or r["overflows"] or r["broken_images"]
            badge_class = "badge-err" if r["status"] == "error" else ("badge-warn" if has_issues else "badge-ok")
            badge_text = "ERROR" if r["status"] == "error" else ("WARN" if has_issues else "OK")
            
            html += f'<div class="page-row">'
            html += f'<div class="page-header">'
            html += f'<span class="page-path">{r["page"]}</span>'
            html += f'<span class="badge badge-{badge_class.replace("badge-","")}">{r["viewport"]}</span>'
            html += f'<span class="badge {badge_class}">{badge_text}</span>'
            html += f'</div>'
            
            html += f'<div class="screenshots">'
            html += f'<div class="screenshot">'
            html += f'<div class="screenshot-label">{r["viewport"]}</div>'
            html += f'<img src="{r["screenshot"]}" alt="{r["page"]} {r["viewport"]}" onclick="openLightbox(this.src)" />'
            html += f'</div>'
            html += f'</div>'
            
            if has_issues:
                html += '<div class="issues">'
                for e in r["errors"][:5]:
                    html += f'<div class="issue issue-error">❌ Console: {e[:150]}</div>'
                for o in r["overflows"][:5]:
                    html += f'<div class="issue issue-overflow">⚠️ Overflow: {o[:150]}</div>'
                for b in r["broken_images"][:5]:
                    html += f'<div class="issue issue-broken">🖼️ Broken: {b[:150]}</div>'
                html += '</div>'
            
            html += '</div>'
    
    html += '</div>'
    
    # Lightbox
    html += """
<div class="lightbox" id="lightbox" onclick="this.classList.remove('active')">
  <img id="lightbox-img" src="" />
</div>
<script>
function openLightbox(src) {
  document.getElementById('lightbox-img').src = src;
  document.getElementById('lightbox').classList.add('active');
}
</script>
</body></html>"""
    
    with open(path, "w") as f:
        f.write(html)

if __name__ == "__main__":
    run_tests()
