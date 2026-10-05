#!/usr/bin/env python3
"""Parallel discovery: the crawl of tools/discover.py (same rules, same output, same order) with each wave of the
queue fetched by the warm workers of runnerd.py, each with its own browser and session; the links found are then
pushed in the order the serial crawl would have pushed them, so the per-screen quota keeps exactly the same urls.
Used by runnerd.py (op discover); standalone in the runner, on threads: python /bench/server/fast_discover.py [threads]"""
import json
import re
import sys
import threading
import time
import pathlib
from concurrent.futures import ThreadPoolExecutor

BENCH = pathlib.Path(__file__).resolve().parents[1]
sys.path[:0] = [str(BENCH / "tests"), str(BENCH / "tools")]
import lutece  # noqa: E402
import discover as serial  # noqa: E402
from playwright.sync_api import sync_playwright  # noqa: E402

THREADS = int(sys.argv[1]) if __name__ == "__main__" and len(sys.argv) > 1 else 6
_local = threading.local()
_pages = []


def page_for(login):
    """The calling thread's page: one browser per thread, logged in once when the crawl needs a session."""
    if not hasattr(_local, "page"):
        _local.pw = sync_playwright().start()
        b = _local.pw.chromium.launch(headless=True, args=lutece.chromium_args())
        _local.page = b.new_context(viewport={"width": 1440, "height": 1000}, locale="fr-FR").new_page()
        _local.page.set_default_timeout(20000)
        lutece.observe(_local.page)
        if login:
            assert lutece.bo_login(_local.page), "login failed"
        _pages.append((_local.pw, b))
    return _local.page


def visit_bo(item):
    """Fetch one back-office url and return its record and the links it offers, as the serial crawl reads them."""
    n, src, depth = item
    page = page_for(True)
    t0 = time.perf_counter()
    try:
        resp = page.goto(lutece.url(n), wait_until="domcontentloaded")
    except Exception as e:  # noqa: BLE001
        return {"url": n, "from": src, "status": 0, "error": str(e)[:120]}, [], [], None
    status = resp.status if resp else 0
    kind = lutece.error_kind(page, status)
    note = None
    if kind == "auth":
        note = {"url": n, "from": src, "status": status, "kind": "auth"}
        lutece.bo_login(page)
        resp = page.goto(lutece.url(n), wait_until="domcontentloaded")
        status = resp.status if resp else 0
        kind = lutece.error_kind(page, status)
    rec = {"url": n, "from": src, "status": status, "kind": kind, "title": page.title()[:80],
           "ms": round((time.perf_counter() - t0) * 1000), "final": lutece.normalize(page.url)}
    if kind:
        return rec, [], [], note
    return rec, lutece.admin_links(page), lutece.get_form_urls(page), note


def visit_fo(item):
    """Fetch one front-office url and return its record and its front-office links."""
    n, src, depth = item
    page = page_for(False)
    t0 = time.perf_counter()
    try:
        resp = page.goto(lutece.url(n), wait_until="domcontentloaded")
    except Exception as e:  # noqa: BLE001
        return {"url": n, "from": src, "status": 0, "error": str(e)[:120]}, [], [], None
    status = resp.status if resp else 0
    kind = lutece.classify(page, status)
    rec = {"url": n, "from": src, "status": status, "kind": kind, "title": page.title()[:80],
           "ms": round((time.perf_counter() - t0) * 1000), "final": lutece.normalize(page.url), "surface": "fo"}
    return rec, lutece.fo_links(page), [], None


WAVES = []


def waves(pool, queue, visit, on_result):
    """Drain the queue wave by wave: fetch a wave in parallel, then hand the results back in queue order. Each wave's
    size and duration go to WAVES."""
    out = []
    while queue and len(out) < serial.MAX_SCREENS:
        t = time.perf_counter()
        wave = queue[:serial.MAX_SCREENS - len(out)]
        del queue[:len(wave)]
        for item, res in zip(wave, pool.map(visit, wave)):
            on_result(item, res, out)
        WAVES.append((len(wave), round(time.perf_counter() - t, 2)))
    return out


def crawl_bo(pool):
    """The back-office crawl of discover.crawl, parallel."""
    seen, queue, forms, skipped, per_path, linked = {}, [], [], [], {}, set()
    in_scope = lutece.scope()

    def push(u, src, depth):
        n = lutece.normalize(u)
        if src != "inventory":
            linked.add(n)
        if not n.startswith("jsp/admin/") or n in seen or not in_scope(n):
            return
        if serial.MUTATING.search(n) or serial.NOISE.search(n):
            skipped.append(n); seen[n] = True
            return
        path = n.split("?")[0] + "|" + (re.search(r"[?&]view=([\w-]*)", n).group(1) if "view=" in n else "")
        if per_path.get(path, 0) >= serial.MAX_PER_PATH:
            seen[n] = True
            return
        per_path[path] = per_path.get(path, 0) + 1
        seen[n] = True
        queue.append((n, src, depth))

    def on_result(item, res, out):
        n, src, depth = item
        rec, links, gets, note = res
        if note:
            note["note"] = "session lost after %s; re-login" % (out[-1]["url"] if out else "?")
            out.append(note)
        out.append(rec)
        for link in links:
            if link.startswith("FORM "):
                forms.append({"screen": n, "action": lutece.normalize(link[5:])})
            elif depth < serial.DEPTH:
                push(link, n, depth + 1)
        for u in gets:
            if depth < serial.DEPTH:
                push(u, n + " [form GET]", depth + 1)

    inv = lutece.load_json("artifacts/inventory.json", {"features": [], "screens": []})
    if in_scope("jsp/admin/AdminMenu.jsp"):
        push("jsp/admin/AdminMenu.jsp", "root", 0)
    for f in inv["features"]:
        if f.get("url"):
            push(f["url"], "feature:" + f["right"], 0)
    for s in inv["screens"]:
        if "?" not in s["url"] and s["kind"] == "jsp" and not s["url"].endswith(("AdminLogin.jsp", "AdminMenu.jsp")):
            push(s["url"], "inventory", 1)
    out = waves(pool, queue, visit_bo, on_result)
    for e in out:
        if e["from"] == "inventory" and e["url"] not in linked:
            e["orphan"] = True
    return {"screens": out, "forms": sorted({(f["screen"], f["action"]) for f in forms}), "skipped": sorted(set(skipped)),
            "stats": {"screens": len(out), "forms": len({f["action"] for f in forms}), "skipped": len(set(skipped))}}


def crawl_fo(pool):
    """The front-office crawl of discover.crawl_fo, parallel."""
    inv = lutece.load_json("artifacts/inventory.json", {"screens": []})
    in_scope = lutece.scope()
    starts = [s["url"] for s in inv.get("screens", []) if s.get("surface") == "fo" and in_scope(s["url"])]
    if not starts:
        return {"screens": [], "forms": [], "skipped": [], "stats": {"screens": 0, "forms": 0, "skipped": 0}}
    app_ids = {re.search(r"page=([\w-]+)", u).group(1) for u in starts if "page=" in u}
    seen, queue, forms, skipped, per_path = {}, [], [], [], {}

    def push(u, src, depth):
        n = lutece.normalize(u)
        if not ("jsp/site/" in n or "Portal.jsp" in n) or n in seen:
            return
        m = re.search(r"[?&]page=([\w-]+)", n)
        if not m or m.group(1) not in app_ids:
            seen[n] = True; return
        if re.search(r"/(Do|do)[A-Z]\w*\.jsp|[?&]action=|logout|deconnexion", n, re.I):
            skipped.append(n); seen[n] = True; return
        path = n.split("?")[0] + "|" + (re.search(r"page=([\w-]+)", n).group(1) if "page=" in n else "")
        if per_path.get(path, 0) >= serial.MAX_PER_PATH:
            seen[n] = True; return
        per_path[path] = per_path.get(path, 0) + 1
        seen[n] = True; queue.append((n, src, depth))

    def on_result(item, res, out):
        n, src, depth = item
        rec, links, _, _ = res
        out.append(rec)
        for link in links:
            if link.startswith("FORM "):
                forms.append({"screen": n, "action": lutece.normalize(link[5:])})
            elif depth < serial.DEPTH:
                push(link, n, depth + 1)

    for u in starts:
        push(u, "inventory", 0)
    out = waves(pool, queue, visit_fo, on_result)
    return {"screens": out, "forms": sorted({(f["screen"], f["action"]) for f in forms}), "skipped": sorted(set(skipped)),
            "stats": {"screens": len(out), "forms": len({f["action"] for f in forms}), "skipped": len(set(skipped))}}


def discover(bo_pool, fo_pool):
    """Run both crawls on the given pools (anything with an ordered map) and write discovered.json; return stats."""
    WAVES.clear()
    t = time.perf_counter()
    res = crawl_bo(bo_pool)
    t_bo, n_bo = time.perf_counter() - t, len(WAVES)
    fo = crawl_fo(fo_pool)
    res["timing"] = {"bo_s": round(t_bo, 2), "fo_s": round(time.perf_counter() - t - t_bo, 2),
                     "bo_waves": WAVES[:n_bo], "fo_waves": WAVES[n_bo:]}
    res["forms"] = [{"screen": s, "action": a} for s, a in res["forms"]]
    res["fo_screens"] = fo["screens"]
    res["fo_forms"] = [{"screen": s, "action": a} for s, a in fo["forms"]]
    res["stats"]["fo_screens"] = fo["stats"]["screens"]
    res["stats"]["fo_forms"] = fo["stats"]["forms"]
    (lutece.ARTIFACTS / "discovered.json").write_text(json.dumps(res, indent=1, ensure_ascii=False))
    return res


def main():
    """Same output file and summary as discover.main, on thread pools."""
    with ThreadPoolExecutor(THREADS) as bo_pool, ThreadPoolExecutor(THREADS) as fo_pool:
        res = discover(bo_pool, fo_pool)
    print(json.dumps(res["stats"]))
    bad = [s for s in res["screens"] if s.get("kind") or s["status"] >= 400]
    for s in bad[:30]:
        print("  KO %s %s %s" % (s["status"], s.get("kind"), s["url"]))


if __name__ == "__main__":
    main()
