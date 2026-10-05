#!/usr/bin/env python3
"""Warm test daemon of a bench, inside its runner: N persistent workers keep a browser (and its contexts, so the static
files stay cached), the logged-in back-office session and the front-office theme baseline alive, and run pytest node
ids in-process on demand. A suite pays only for its tests: no Python start, no browser launch, no login per suite.

    python /bench/server/runnerd.py serve <workers>     start the daemon (socket /e2e/artifacts/.runnerd.sock)
    python /bench/server/runnerd.py ping                print the daemon's code key (exit 1 when none answers)
    python /bench/server/runnerd.py reset               forget the sessions and contexts (new site, restarted JVM)
    python /bench/server/runnerd.py login               every worker logs in now, in the background (returns at once)
    python /bench/server/runnerd.py flush               close the kept browser contexts (a static file changed)
    python /bench/server/runnerd.py discover            the discovery crawl on the workers (fast_discover.py)
    python /bench/server/runnerd.py suite <name> <junit> [--serial] [pytest args]
                                                        one suite: collected once, split across the workers by the
                                                        known duration of each test (all on one worker, in order, with
                                                        --serial), one JUnit file, pytest's failure report and summary

Node ids are relative to rootdir /bench (tests/test_x.py::test_y), results go where the bench's conftest writes them
(artifacts/results/gwN.jsonl, PYTEST_XDIST_WORKER), and the exit code is pytest's (5: nothing collected).
"""
import faulthandler
import glob
import hashlib
import json
import multiprocessing as mp
import os
import queue
import re
import signal
import socket
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

SOCK = "/e2e/artifacts/.runnerd.sock"
WARM = ("browser", "bo_state", "fo_theme_baseline")
PYTEST = ["-p", "no:cacheprovider", "-p", "no:xdist", "--rootdir=/bench"]
DURATIONS_FILE = "/e2e/artifacts/.durations.json"
DURATIONS = {}
PROCS = []
CODE = ""


def code(count):
    """Key of the running code: the bench version, this file, the worker count and the scope of the tests."""
    return hashlib.sha1((os.environ.get("LPE2E_VERSION", "") + str(count) + os.environ.get("E2E_SCOPE", "")).encode()
                        + open(__file__, "rb").read()).hexdigest()[:12]


class KeptContext:
    """A pooled browser context handed to a test: closing it cleans it and gives it back to the pool."""

    def __init__(self, ctx, pool):
        """Wrap a real context and the free list it returns to."""
        self._ctx, self._pool = ctx, pool

    def __getattr__(self, name):
        """Everything but close is the real context's."""
        return getattr(self._ctx, name)

    def close(self, **kwargs):
        """Empty the context (local storage, pages, routes, cookies, permissions) and return it to the pool."""
        try:
            for page in self._ctx.pages:
                try:
                    page.evaluate("() => { try { localStorage.clear(); } catch (e) {} }")
                except Exception:  # noqa: BLE001 - a crashed or blank page holds nothing to clear
                    pass
                page.close()
            self._ctx.unroute_all(behavior="ignoreErrors")
            self._ctx.clear_cookies()
            self._ctx.clear_permissions()
            self._pool.append(self._ctx)
        except Exception:  # noqa: BLE001 - a context the test closed itself is dropped
            pass


class KeptBrowser:
    """The worker's browser with its contexts kept between tests: a new context with the same options reuses a
    cleaned one, so the static files stay in its memory cache. Flushed whenever the bench site changes."""

    def __init__(self, browser, pools):
        """Wrap the real browser and the pools of free contexts, by options."""
        self._browser, self._pools = browser, pools

    def __getattr__(self, name):
        """Everything but new_context is the real browser's."""
        return getattr(self._browser, name)

    def new_context(self, **opts):
        """A clean context with these options, the storage state's cookies loaded."""
        state = opts.pop("storage_state", None)
        pool = self._pools.setdefault(json.dumps(opts, sort_keys=True, default=str), [])
        ctx = pool.pop() if pool else self._browser.new_context(**opts)
        ctx.set_default_timeout(30000)
        ctx.set_default_navigation_timeout(30000)
        if state:
            data = json.load(open(state)) if isinstance(state, (str, os.PathLike)) else state
            if data.get("cookies"):
                ctx.add_cookies(data["cookies"])
        return KeptContext(ctx, pool)


def flush_contexts(cache):
    """Close every pooled context, so the next tests load the static files afresh."""
    pools = cache.get("pools", {})
    for pool in pools.values():
        for ctx in pool:
            try:
                ctx.close()
            except Exception:  # noqa: BLE001 - already gone
                pass
    pools.clear()


class WarmPlugin:
    """Serves the session fixtures from objects kept across pytest runs, and measures each test."""

    def __init__(self, cache):
        """Keep a reference to the worker's cache of fixture values."""
        self.cache = cache
        self.durations = {}

    def pytest_runtest_logreport(self, report):
        """Add up each test's setup, call and teardown time."""
        self.durations[report.nodeid] = self.durations.get(report.nodeid, 0) + report.duration

    def pytest_fixture_setup(self, fixturedef, request):
        """Return a cached value for the warm fixtures, computing it once with the bench's own fixture."""
        name = fixturedef.argname
        if name not in WARM:
            return None
        if name == "browser":
            value = KeptBrowser(self.cache["browser"], self.cache.setdefault("pools", {}))
        elif name in self.cache:
            value = self.cache[name]
        else:
            kwargs = {a: request.getfixturevalue(a) for a in fixturedef.argnames}
            value = fixturedef.func(**kwargs)
            self.cache[name] = value
        fixturedef.cached_result = (value, fixturedef.cache_key(request), None)
        return value

    pytest_fixture_setup.tryfirst = True


def drop_dead_session(cache, lutece):
    """Forget the cached back-office session when its file is gone (a new run clears artifacts/state) or the server no
    longer knows it (expired, or the JVM restarted), so the bench's own fixture logs in again."""
    state = cache.get("bo_state")
    if not state:
        return
    if isinstance(state, (str, os.PathLike)) and not os.path.exists(state):
        cache.pop("bo_state", None)
        return
    ctx = cache["browser"].new_context(storage_state=state)
    try:
        page = ctx.new_page()
        resp = page.goto(lutece.url("jsp/admin/AdminMenu.jsp"), wait_until="commit")
        alive = resp is not None and resp.status < 400 and "AdminLogin" not in page.url
    except Exception:  # noqa: BLE001 - an unreachable server is reported by the tests themselves
        alive = False
    finally:
        ctx.close()
    if not alive:
        cache.pop("bo_state", None)


def worker(index, jobs, results):
    """Own one browser for life and run every job sent to this worker."""
    os.chdir("/e2e")
    os.environ["PYTEST_XDIST_WORKER"] = "gw%d" % index
    sys.path[:0] = ["/bench/tests", "/bench/tools"]
    import pytest
    from playwright.sync_api import sync_playwright
    import lutece
    pw = sync_playwright().start()
    cache = {"browser": pw.chromium.launch(headless=True, args=lutece.chromium_args())}
    results.put(("ready", index))
    while True:
        job = jobs.get()
        if job is None:
            break
        if isinstance(job, dict) and job.get("op") == "login":
            t = time.time()
            try:
                login(cache, index)
            except Exception as e:  # noqa: BLE001 - the tests' own fixture logs in again and reports the failure
                cache.pop("bo_state", None)
                print("runnerd: gw%d login failed: %r" % (index, e), flush=True)
            cache["login_s"] = round(time.time() - t, 2)
            if job.get("ack"):
                results.put(("logged", index, cache["login_s"], round(time.time() - job.get("sent", t), 2)))
            continue
        if job == "reset":
            flush_contexts(cache)
            cache = {"browser": cache["browser"]}
            continue
        if job == "flush":
            flush_contexts(cache)
            continue
        if isinstance(job, dict) and job.get("op") == "visit":
            try:
                results.put(("visited", index, visit(cache, job)))
            except Exception as e:  # noqa: BLE001 - a dead worker would hang the daemon
                cache.pop("visit-" + job["mode"], None)
                results.put(("visited", index, [({"url": it[0], "from": it[1], "status": 0, "error": ("worker: %s" % e)[:120]}, [], [], None)
                                                for it in job["items"]]))
            continue
        for mod in [m for m in sys.modules if m.startswith(("test_", "conftest")) or m == "lutece"]:
            del sys.modules[mod]
        start = time.time()
        import lutece
        drop_dead_session(cache, lutece)
        out = "/e2e/artifacts/.runnerd-%s-gw%d.log" % (job["suite"], index)
        junit = "/e2e/artifacts/.runnerd-%s-gw%d.xml" % (job["suite"], index)
        args = job["ids"] + job["args"] + PYTEST + ["--junitxml=" + junit, "-o", "console_output_style=classic"]
        rc = 3
        plugin = WarmPlugin(cache)
        with open(out, "w") as fh:
            saved = os.dup(1), os.dup(2)
            os.dup2(fh.fileno(), 1)
            os.dup2(fh.fileno(), 2)
            try:
                rc = pytest.main(args, plugins=[plugin])
            except BaseException as e:  # noqa: BLE001 - report, never die
                print("runnerd: pytest crashed: %r" % e)
            finally:
                sys.stdout.flush()
                os.dup2(saved[0], 1)
                os.dup2(saved[1], 2)
        results.put(("done", index, int(rc), round(time.time() - start, 2), out, junit, plugin.durations))


def login(cache, index):
    """This worker's back-office session, made once per application start (a reset forgets it): the crawl page logs
    in unless the server still knows its session, posting the login form without following its redirect (the admin
    home, the heaviest page, is not rendered four times on a cold server), and its storage state becomes the session
    the tests' bo fixture would have made. The front-office crawl page is opened at the same time."""
    import lutece
    page = cache.get("visit-bo")
    if page and cache.get("logged_in"):
        return
    alive = False
    if page:
        try:
            resp = page.goto(lutece.url("jsp/admin/AdminMenu.jsp"), wait_until="commit")
            alive = resp is not None and resp.status < 400 and "AdminLogin" not in page.url
        except Exception:  # noqa: BLE001 - a page whose context is gone is replaced
            page = None
    if page is None:
        page = cache["browser"].new_context(viewport={"width": 1440, "height": 1000}, locale="fr-FR").new_page()
        page.set_default_timeout(20000)
        lutece.observe(page)
        cache["visit-bo"] = page
    if not alive:
        page.goto(lutece.url("jsp/admin/AdminLogin.jsp"), wait_until="domcontentloaded")
        token = page.eval_on_selector('input[name="token"]', "e => e.value") if page.locator('input[name="token"]').count() else ""
        resp = page.context.request.post(lutece.url("jsp/admin/DoAdminLogin.jsp"), max_redirects=0,
                                         form={"access_code": lutece.ADMIN[0], "password": lutece.ADMIN[1], "token": token})
        target = resp.headers.get("location", "")
        assert resp.status in (302, 303) and target and not re.search(r"AdminLogin|AdminMessage", target), \
            "login refused: %s %s" % (resp.status, target)
    path = "/tmp/lpe2e-bo-gw%d.json" % index
    page.context.storage_state(path=path)
    cache["bo_state"] = path
    cache["logged_in"] = True
    if "visit-fo" not in cache:
        fo = cache["browser"].new_context(viewport={"width": 1440, "height": 1000}, locale="fr-FR").new_page()
        fo.set_default_timeout(20000)
        lutece.observe(fo)
        cache["visit-fo"] = fo


def visit(cache, job):
    """Fetch discovery urls with this worker's browser: a logged-in page for the back office (logging in once per
    run), a session-less page for the front office; both pages are kept for the next wave."""
    sys.path.insert(0, "/bench/server")
    import fast_discover
    import lutece
    key = "visit-" + job["mode"]
    if key not in cache:
        login(cache, int(os.environ["PYTEST_XDIST_WORKER"][2:]))
    fast_discover._local.page = cache[key]
    fn = fast_discover.visit_bo if job["mode"] == "bo" else fast_discover.visit_fo
    return [fn(tuple(item)) for item in job["items"]]


class WorkerPool:
    """Ordered map over the warm workers, for the discovery crawl."""

    def __init__(self, jobs, results, mode):
        """Bind the worker queues and the crawl mode (bo or fo)."""
        self.jobs, self.results, self.mode = jobs, results, mode

    def map(self, fn, items):
        """Split the wave across the workers and return the results in the wave's order."""
        n = len(self.jobs)
        shares = [items[i::n] for i in range(n)]
        busy = [i for i, share in enumerate(shares) if share]
        for i in busy:
            self.jobs[i].put({"op": "visit", "mode": self.mode, "items": shares[i]})
        got = {}
        for _ in busy:
            _, index, res = get(self.results)
            got[index] = res
        out = [None] * len(items)
        for i in busy:
            out[i::n] = got[i]
        return out


def get(results):
    """Next worker message; fails fast when a worker died instead of waiting forever."""
    while True:
        try:
            return results.get(timeout=1)
        except queue.Empty:
            dead = [p.pid for p in PROCS if not p.is_alive()]
            if dead:
                raise RuntimeError("worker(s) died: %s" % dead)


def balance(ids, count):
    """Split node ids so the workers finish together: longest known tests first, each to the least loaded worker,
    then each share back in collection order."""
    known = sorted(DURATIONS.values())
    default = known[len(known) // 2] if known else 1.0
    loads, shares = [0.0] * count, [[] for _ in range(count)]
    for i in sorted(range(len(ids)), key=lambda i: -DURATIONS.get(ids[i], default)):
        w = loads.index(min(loads))
        loads[w] += DURATIONS.get(ids[i], default)
        shares[w].append(i)
    return [[ids[i] for i in sorted(share)] for share in shares]


COLLECTED = {}


class Collector:
    """Keeps the node ids of a collection."""

    def __init__(self):
        """Nothing collected yet."""
        self.ids = []

    def pytest_collection_finish(self, session):
        """Record every selected item."""
        self.ids = [item.nodeid for item in session.items]


def inputs_key():
    """Size and time of everything a collection reads: the project's configuration (outside artifacts/) and the
    inventory and discovery the suites are parametrised from. The bench code is in the daemon's code key."""
    key = []
    for root, dirs, files in os.walk("/e2e"):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("artifacts", "__pycache__")]
        for f in files:
            st = os.stat(os.path.join(root, f))
            key.append((root, f, st.st_size, st.st_mtime_ns))
    for f in ("inventory.json", "discovered.json"):
        try:
            st = os.stat("/e2e/artifacts/" + f)
            key.append((f, st.st_size, st.st_mtime_ns))
        except OSError:
            pass
    return tuple(sorted(key))


def collect(args):
    """The node ids pytest selects for these arguments (paths, -m, -k), read in this process without running
    anything, and kept while what the collection reads is unchanged."""
    key = (tuple(args), inputs_key())
    if key in COLLECTED:
        return COLLECTED[key]
    import pytest
    for mod in [m for m in sys.modules if m.startswith(("test_", "conftest")) or m == "lutece"]:
        del sys.modules[mod]
    sys.path[:0] = [p for p in ("/bench/tests", "/bench/tools") if p not in sys.path]
    plugin = Collector()
    with open("/e2e/artifacts/.runnerd-collect.log", "w") as fh:
        saved = os.dup(1), os.dup(2)
        os.dup2(fh.fileno(), 1)
        os.dup2(fh.fileno(), 2)
        try:
            rc = pytest.main(["--collect-only", "-q"] + PYTEST + args, plugins=[plugin])
        finally:
            sys.stdout.flush()
            os.dup2(saved[0], 1)
            os.dup2(saved[1], 2)
    if not plugin.ids and rc not in (0, 5):
        raise RuntimeError("collection failed:\n" + open("/e2e/artifacts/.runnerd-collect.log", errors="replace").read()[-2000:])
    COLLECTED[key] = plugin.ids
    return plugin.ids


def merge_junit(parts, target):
    """One JUnit file of the suite from the workers' files: their test cases under one test suite, counters summed."""
    suite = None
    for p in parts:
        if not os.path.exists(p):
            continue
        root = ET.parse(p).getroot()
        ts = root if root.tag == "testsuite" else root.find("testsuite")
        if suite is None:
            suite = ts
            continue
        for k in ("tests", "errors", "failures", "skipped"):
            suite.set(k, str(int(suite.get(k, 0)) + int(ts.get(k, 0))))
        suite.set("time", "%.3f" % (float(suite.get("time", 0)) + float(ts.get("time", 0))))
        for tc in ts.findall("testcase"):
            suite.append(tc)
    if suite is None:
        suite = ET.Element("testsuite", name="pytest", tests="0", errors="0", failures="0", skipped="0", time="0")
    root = ET.Element("testsuites")
    root.append(suite)
    ET.ElementTree(root).write(target, encoding="utf-8", xml_declaration=True)
    return suite


def report(logs, suite, seconds):
    """pytest's failure sections of every worker, then one summary line in pytest's words."""
    sections = []
    for p in logs:
        text = open(p, errors="replace").read()
        m = re.search(r"^=+ (FAILURES|ERRORS) =+$.*?(?=^=+ (short test summary info|warnings summary|\d+ \w+.* in [\d.]+s) )",
                      text, re.S | re.M)
        if m:
            sections.append(m.group(0).rstrip())
        m = re.search(r"^=+ short test summary info =+$(.*?)(?=^=+ )", text, re.S | re.M)
        if m:
            sections.append(m.group(1).strip())
        for line in text.splitlines():
            if line.startswith(("runnerd:", "ERROR: ", "INTERNALERROR")):
                sections.append(line)
    n = {k: int(suite.get(k, 0)) for k in ("tests", "failures", "errors", "skipped")}
    passed = n["tests"] - n["failures"] - n["errors"] - n["skipped"]
    words = [w for w in ("%d failed" % n["failures"] if n["failures"] else "", "%d passed" % passed if passed else "",
                         "%d skipped" % n["skipped"] if n["skipped"] else "", "%d error" % n["errors"] if n["errors"] else "") if w]
    return "\n".join(sections + ["%s in %.2fs" % (", ".join(words) or "no tests ran", seconds)])


def handle(conn, jobs, results, count):
    """Answer one request."""
    req = json.loads(conn.makefile().readline())
    op = req.get("op")
    if op == "ping":
        conn.sendall((json.dumps({"code": CODE}) + "\n").encode())
        return
    if op in ("reset", "flush"):
        for q in jobs:
            q.put(op)
        conn.sendall(b'{"ok": true}\n')
        return
    if op == "login":
        for q in jobs:
            q.put({"op": "login"})
        conn.sendall(b'{"ok": true}\n')
        return
    if op == "discover":
        t0 = time.time()
        for q in jobs:
            q.put({"op": "login", "ack": True, "sent": time.time()})
        acks = [get(results) for _ in jobs]
        t_login = time.time() - t0
        sys.path[:0] = ["/bench/tests", "/bench/tools", "/bench/server"]
        for mod in [m for m in sys.modules if m in ("lutece", "discover", "fast_discover")]:
            del sys.modules[mod]
        import fast_discover
        res = fast_discover.discover(WorkerPool(jobs, results, "bo"), WorkerPool(jobs, results, "fo"))
        res["timing"]["login_wait_s"] = round(t_login, 2)
        res["timing"]["login_s"] = [a[2] for a in acks]
        conn.sendall((json.dumps({"rc": 0, "out": "%s (%.1fs, %d workers; %s)" % (json.dumps(res["stats"]), time.time() - t0, count,
                                                                                 json.dumps(res["timing"]))}) + "\n").encode())
        return
    t0 = time.time()
    name, junit, args = req["suite"], req["junit"], req["args"]
    for old in glob.glob("/e2e/artifacts/.runnerd-%s-gw*" % name):
        os.unlink(old)
    ids = collect(args)
    if not ids:
        merge_junit([], junit)
        conn.sendall((json.dumps({"rc": 5, "out": "no tests ran in %.2fs" % (time.time() - t0)}) + "\n").encode())
        return
    opts = [a for a in args if not a.startswith("/bench/")]
    ids = ["/bench/" + i for i in ids]
    shares = [ids] if req.get("serial") else balance(ids, count)
    busy = 0
    for i, share in enumerate(shares):
        if share:
            jobs[i].put({"suite": name, "ids": share, "args": opts + ["--suite", name]})
            busy += 1
    done = [get(results) for _ in range(busy)]
    for d in done:
        DURATIONS.update({"/bench/" + k: v for k, v in d[6].items()})
    tmp = DURATIONS_FILE + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(DURATIONS, fh)
    os.replace(tmp, DURATIONS_FILE)
    suite = merge_junit([d[5] for d in done], junit)
    rc = max(d[2] for d in done)
    conn.sendall((json.dumps({"rc": rc, "out": report([d[4] for d in done], suite, time.time() - t0)}) + "\n").encode())


def serve(count):
    """Start the workers and answer requests on the unix socket. SIGUSR1 dumps every stack to the daemon log."""
    global CODE
    CODE = code(count)
    faulthandler.register(signal.SIGUSR1, all_threads=True)
    mp.set_start_method("fork")
    try:
        with open(DURATIONS_FILE) as fh:
            DURATIONS.update(json.load(fh))
    except (OSError, ValueError):
        pass
    jobs = [mp.Queue() for _ in range(count)]
    results = mp.Queue()
    procs = [mp.Process(target=worker, args=(i, jobs[i], results), daemon=True) for i in range(count)]
    for p in procs:
        p.start()
    PROCS.extend(procs)
    for _ in procs:
        get(results)
    if os.path.exists(SOCK):
        os.unlink(SOCK)
    srv = socket.socket(socket.AF_UNIX)
    srv.bind(SOCK)
    srv.listen(4)
    print("runnerd: %d warm workers" % count, flush=True)
    while True:
        conn, _ = srv.accept()
        try:
            handle(conn, jobs, results, count)
        except Exception as e:  # noqa: BLE001 - answer the client, keep serving
            try:
                conn.sendall((json.dumps({"rc": 3, "out": "runnerd: %s" % e}) + "\n").encode())
            except OSError:
                pass
        finally:
            conn.close()


def request(payload):
    """Send one request to the daemon and return its reply."""
    c = socket.socket(socket.AF_UNIX)
    c.connect(SOCK)
    c.sendall((json.dumps(payload) + "\n").encode())
    return json.loads(c.makefile().readline())


def main():
    """Entry point."""
    op = sys.argv[1] if len(sys.argv) > 1 else ""
    if op == "serve":
        serve(int(sys.argv[2]))
    elif op == "ping":
        try:
            print(request({"op": "ping"})["code"])
        except OSError:
            sys.exit(1)
    elif op in ("reset", "flush", "login"):
        request({"op": op})
    elif op == "discover":
        r = request({"op": "discover"})
        print(r["out"], flush=True)
        sys.exit(r["rc"])
    elif op == "suite":
        serial = "--serial" in sys.argv
        rest = [a for a in sys.argv[4:] if a != "--serial"]
        r = request({"op": "suite", "suite": sys.argv[2], "junit": sys.argv[3], "serial": serial, "args": rest})
        print(r["out"], flush=True)
        sys.exit(r["rc"])
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
