# Lutece e2e bench — design decisions

One command, `lpe2e`, on the configuration a project keeps in `e2e/`: a machine-wide e2e server, an inventory of
**every** screen and action, warm tests, a hot loop, a report a human and an agent both read in a few hundred tokens.
Read before changing the bench.

## The shared server

| Part | What it does |
|---|---|
| Machine state `~/.lutecepowers-e2e` | the bench code (`lpe2e` copies it when it changed: a stable path the containers mount), one MariaDB (`tmpfs`) and one Mailpit on the `lpe2e` network, the generic Liberty image, the assembled sites, the Python dependencies of the tests |
| Site cache (`sites/<key>`) | the assembled site of a composition, keyed by the generated site pom and `plugins.dat` (the snapshot builds of every Lutece artefact are written into the pom: a new publication changes the key); a bench site is hard links to it plus the artefact's own jar and webapp zip (`server.py put` unlinks before writing: never through a link) |
| Latest versions (`tools/latest-lutece.py`) | every Lutece artefact of the site is the highest snapshot whose pom has `lutece-global-pom` 8.x as parent (the repository's `<latest>` is the last *deployed*, a v7 maintenance snapshot can be it) |
| Generic Liberty image | the site mounted at `/site`, its `server.xml` / `jvm.options` / `server.env` next to it; a shell loop restarts the JVM after `server stop`, the container and the network namespace stay |
| Runner | Playwright container, owner of the bench's network namespace and host port, `--init` (its PID 1 reaps the orphans); the application joins its namespace and is reached as `localhost:9090` |
| Warm test daemon (`server/runnerd.py`) | N workers keep Chromium, the browser contexts (static files cached; a context is cleaned and reused, all are flushed when a static file changes), the back-office session and the front-office theme baseline; after each job a context a test left open goes back to the pool, a reset closes the crawl pages, and a browser holding more than 24 contexts is replaced, so the runner's memory and processes stay flat from one run to the next; a suite is collected in the daemon (cached while its inputs are unchanged) and split by the measured duration of each test; the JUnit files of the workers are merged per suite |
| Early login | the workers log in while the host takes the inventory (after the seed: post-init makes the admin usable), posting the login form without following its redirect; that session is the one the tests' `bo` fixture would have made |
| Parallel discovery (`server/fast_discover.py`) | the crawl of `tools/discover.py`, wave by wave on the workers, results pushed back in the serial order: the same `discovered.json` |
| JVM | C1 only (`-XX:TieredStopAtLevel=1`): a bench JVM lives minutes |
| Liberty workarea | kept per bench: the JSP compiled by one run serve the next |
| FreeMarker | `templateUpdateDelay` long, the cache emptied (`reset_caches.sh`, the core's cache screen) after a template change: a delay of 0 makes Liberty scan every jar of the war at each render |
| Hot loop (`lpe2e watch`) | web file → in the site at once; method body → compiled (`javax.tools`, the project's Maven classpath, sources and `~/.m2` mounted at their own paths) and redefined through one JDWP connection, the classes kept in `WEB-INF/classes`; anything else → jar rebuilt, JVM restarted; then the tests related to the change (JSP screens, front-office application ids), then every suite |
| Hot loop proof (`lpe2e selftest`) | baseline verdict; a template bug (an open `<#if`) then a Java bug (a throw at the start of the display method) injected through `watch`'s apply path right after a render, each required red, reverted and required green against the baseline failures; sources restored byte for byte, the classes the loop kept for them removed (beside the jar they make a CDI bean ambiguous at the next start) |

Not used: a persistent workarea for the start (the time is class loading and JIT), AppCDS (fails under Liberty's
class loaders), `-XX:-BytecodeVerificationRemote` (no gain), InstantOn (needs IBM Semeru), Leyden's AOT cache (not in
JDK 21).

## What is kept, and why

| Part | Choice | Reason |
|---|---|---|
| Browser driver | **Playwright Python 1.62** (`sync_api`) + pytest 9 + pytest-xdist | Process-level parallelism, native JUnit XML for Jenkins. The tests are parametrised by JSON: the language matters little, the stability of the runner matters. |
| Runner | Official image `mcr.microsoft.com/playwright/python:v1.62.0-noble`, pinned | No dependency on the Jenkins agent. |
| Environment | **One e2e server per machine** (`server/server.py`): plain `docker run`, no Compose | A bench is a database, a runner and an application on shared infrastructure; Testcontainers targets per-test isolation (Java integration), out of scope here. |
| Application server | **Open Liberty 26.0.0.9 on Temurin 21 (HotSpot)**, Maven Central zip | The ICR images are OpenJ9 only; OpenJ9 0.61 **crashes** (assertion `VMAccess.cpp:133`) under JFR sampling and refuses `dumponexit`. HotSpot gives full JFR, live `jcmd JFR.dump`, `jfr view`. The JIT difference is accepted: the bottlenecks (SQL, N+1, locks) are the same. |
| Database | **MariaDB 11.8** in memory (`tmpfs`) + `performance_schema` | Native digests (top statements by total time, rows read, no index), no external tool. `pt-query-digest`/PMM rejected: one more image for the same information. |
| Schema | plugin-liquibase at first boot, as in v8 production | Generic for any plugin or site: each jar brings its SQL; no script collected by hand. |
| Synthetic volume | Plain SQL, MariaDB **SEQUENCE** engine (`seq_1_to_N`) | 100,000 users in a few seconds server-side, idempotent, no external generator (Datafaker, Misata…: a dependency and slowness for no gain on reference tables). |
| Server timings | **Liberty access log** (`%D` µs per request) + `/metrics` (mpMetrics / monitor-1.0: JDBC pool, servlets, GC) | Server-side measure without application instrumentation; p50/p95 per path derived by `tools/metrics.py`. |
| JVM profile | **JFR** on demand (`E2E_JFR=1`, `settings=profile`), dumped live, summarised by `jfr view hot-methods / allocation-by-class / gc-pauses / contention-by-site` | Compact text an agent reads. Off by default: it costs CPU over the whole run. |
| Screen fingerprint | **Aria snapshot** (YAML of the accessibility tree) + JPEG capture | The structural diff is textual, stable across machines, and costs a few lines; pixels are for humans, not for assertions. |
| Browser console | `console` (error/warning), `pageerror`, `requestfailed`, responses ≥ 400 on every page | "Console 100 % clean" is an assertion, not an option. |
| Report | `summary.md` (compact) + `report.html` (gallery) + `junit-*.xml` | The markdown is what the agent reads; JUnit is what Jenkins reads; the HTML is what the project manager looks at. |

## What is rejected, and why

- **Playwright Agents (planner / generator / healer), Playwright MCP**: LLM test generation from VS Code. High token cost, non-deterministic, the opposite of the goal (tests derived from the inventory by script). The skill generates the structure, the agent writes only YAML.
- **Allure** (2 Java / 3 Node): Allure 3 needs Node + `allure` in the agents' PATH; Allure 2 is a Java "global tool". The Jenkins JUnit plugin reads `junit-*.xml` with nothing to install, HTML Publisher shows `report.html`. Allure brings history and trends: add it only when a project asks (`allure-pytest` writes `allure-results`, one option of the suites).
- **Grafana otel-lgtm / Prometheus**: great for interactive exploration, useless for a bench that must produce a text report and shut down.
- **Pixel captures as an oracle**: dependent on fonts, antialiasing, OS; guaranteed false positives in CI.
- **Testcontainers**: per-test isolation, Java, not an e2e stack.
- **ICR OpenJ9 images** for the bench: see above (JFR). They remain the reference for production.
- **A single PDF report of everything**: `report.html` with `content-visibility:auto` is enough; a PDF can be derived by Chromium if a project requires one.

## `lpe2e` flow

```
build      floor check → site pom (latest Lutece 8 snapshots) → cached site, or assembled once → bench site (links + jar)
up         shared server → fresh database → runner + test daemon → application (watch-boot: READY / FAIL / HANG) → seed → early login
inventory  inventory.py (SQL rights, plugin.xml, JSP, @Controller/@View/@Action, templates)
discover   authenticated crawl on the warm workers: GET links from the menu and the entry points (never Do*/action=)
test       harness → screens → fo → scenarios → forms on the warm daemon; /metrics before/after
perf       [JFR] → access log → SQL digests → perf.json
report     summary.md + report.html + results.json
down       the bench's containers and database (the shared server stays)
```

## Harness invariants

What the scripts enforce, and no change may loosen:

1. **Positive oracle** (`lutece.classify`): a screen passes only when the DOM carries the admin menu bar
   (`#main-menu`) with no error wording; any other page is classified (`confirmation`, `error`, `auth`, `login`,
   `error-page`, `fo`, `fragment`, `http-NNN`) and the expected kind is explicit per screen type. The absence of an
   error marker is never a success: "please authenticate" and "Internal error" render in HTTP 200.
2. **Oracle self-tests** (`tests/test_harness.py`) run first; when they fail no other suite runs and `lpe2e` ends
   with code 3.
3. **Visible classification**: the report counts the page kinds of the *passed* tests (`auth ×40` stands out).
4. **Duplicate-content alarm**: different urls passing with the same page text are flagged.
5. **Session guard**: a screen classified `auth` triggers a new login and a second try; the public screens
   (AdminForgot*, AdminFormContact, AdminResetPassword) run in an anonymous context because they invalidate the session.
6. **No no-op**: `fill_form`, `submit`, `click`, `fill` fail on a missing element and resolve the element through
   the Playwright locator (never `document.querySelector` with `:has()` / `:text-is()`).
7. **Coverage per inventory element** (`tools/coverage.py`): each screen or action is reached, excluded with a
   written reason (`scenarios/coverage-exclusions.yaml`), or listed "to cover". Proven ≠ reached: only the pages a
   passing oracle covered are proven (`record.proven`); the rest is listed debt, never subtracted.
8. **Server cause per failure** (`tools/causes.py`): exceptions of `messages.log` correlated by time window and
   confirmed by the name of the JSP or bean.
9. **Bare vs parametrised**: a screen called without its parameters may answer a Lutece message, never an internal
   error; the report separates the two populations.
10. **A mutation without a state oracle** in the next three steps makes the scenario invalid (a red test naming the
    step). State oracles: `sql`, `expect_dom`, `mail`, `fake_log`, `http`, `download`; `expect_text`, `expect_message`,
    `expect_kind`, `expect_html` read the screen, not the state: weak, never enough alone after a mutation.
    `expect_text` on a url or a JSP name is refused; `sql_exec` is refused between a mutation and its state oracle.
11. **Negative and rights scenarios are mandatory**: access refusal, CSRF without token, duplicates, empty mandatory
    fields (`submit_novalidate` bypasses HTML5 to reach the server-side check).
12. **Three failure populations**: functional (parametrised screen, scenario, form), front (JS, console) and
    robustness (screen called without parameters). Console cleanliness is judged by the screens suite, once per screen.
13. **Discovery**: depth 8, 25 variants per screen (path + `view`), forms collected at every depth, GET forms followed.
14. **Bench invariants**: the fuzzer never touches the bench accounts (`PROTECTED_SCREEN`, `protected`) nor deletes a seeded row (`SEED_ID`); after the
    tests the bench checks that the admin account still exists, otherwise code 4 and an alert at the top of the report.
15. **Isolation of parallel scenarios**: anything that changes a shared form (attributes, parameters) picks neutral
    values or goes `serial`.
16. **A finding must survive a clean database**: the reference seed is replayed before every `test`, and a finding
    on seeded data is kept only after checking the data is there.
17. **A skip proves nothing**: a suite that had something to prove and whose every test is skipped fails the run
    (code 8); the summary marks it. Exception: an exclusion written and justified in the bench (`screens.yaml` key
    `skip`, or a scenario's `versions`) stays green, with its reason in the summary.
18. **The report says what was tested** (`artifacts/fingerprint.json`): source commit, source key, image digests. The
    exit codes tell the causes apart: 1 stack, 2 usage, 3 oracle, 4 invariant (the admin account altered, or a
    security key switched off in `conf/override` and not named in `E2E_ALLOW_SECURITY_OFF`), 5 server errors,
    6 smoke, 7 review, 8 suite skipped, 9 an action of the artefact proven by no scenario, 10 lutece-core below the
    supported Lutece 8 level, 11 the database upgrade of `upgrade` failed (the v7 preparation or the takeover).

## Traps (kept in the skill)

- OpenJ9: `dumponexit` invalid; the dump happens at JVM stop; VM assertion under sampling → HotSpot.
- The Liberty `dataSource` is resolved **before** the application starts: the MariaDB driver is in the generic image (`shared/resources/jdbc`).
- Bind mount `/logs`: `chmod 777` before `up`, and the application runs with the host uid so logs and access log stay readable.
- A JVM option Liberty refuses makes the image's loop restart it forever: the console never goes quiet. `watch-boot.sh` fails on `Could not create the Java Virtual Machine` at once instead of waiting for silence.
- `javax.tools` does not expand a classpath wildcard (`lib/*`): the launcher does. The hot compiler takes the explicit Maven classpath.
- A class redefined through JDWP lives in memory only: the hot loop also writes it into the bench site's `WEB-INF/classes`, otherwise a JVM restart brings the jar's version back.
- `pkill -f <pattern>` matches the command that runs it: stop a job by its pid.
- `form.action` is not a string when a field is named `action`: read `getAttribute('action')`.
- `plugins.dat.tpl` placed in `webapp/` ends up in the war: keep templates outside the copied tree.
- `AdminLogin.jsp` answers before the end of the Lutece init when Liquibase fails: read the console (`watch-boot.sh` stops on `Migration failed for changeset`), not only the login page.
- The core sends a CSP with `upgrade-insecure-requests`: on an origin that is not "potentially trustworthy" (anything but localhost/https) Chromium rewrites every sub-resource to https. The application joins the runner's network namespace and the browsers talk to `http://localhost:9090`, a trusted origin, exactly as from the workstation. Never reach it by a container name ending in `.app` either: a TLD of Chromium's preloaded HSTS list.
- The public "forgotten login" form invalidates the session: session-less screens run in an anonymous context, otherwise the rest of the worker's suite falls back to `AdminMessage.jsp`.
- `DoCreateWorkgroup` assigns the creator to the group: removal is refused until the creator is unassigned (realistic scenario: refusal expected, then unassignment, then removal).
- Never pass a Playwright selector (`:has()`, `:text-is()`) to `document.querySelector` inside an `evaluate`: it throws, a broad `except` swallows it, and the submission becomes a silent no-op. Resolve the element through `locator(...).evaluate(...)`, and catch only the navigation timeout.
- `expect_message`: the theme exposes only the card colour (`bg-danger`/`bg-warning`); a confirmation is recognised by its two forms (validate / cancel).

### Traps of plugin benches
- A plugin assembled on the v8 side but absent from the v7 site of `upgrade`, or present but with no version recorded
  by the v7 start (its SQL not managed by Liquibase), arrives on a database where its tables already exist: it is
  installed as new, its creation and init scripts run over the existing rows (a duplicate key stops the start) and its
  upgrades never run. Both sites list the same plugins; `components-without-version.txt` names the others.
- The v7 core reads its `.properties` through MicroProfile Config, so the environment reaches them; a literal in a
  Spring context reaches nothing. `harness/v7-overlay/` is laid over the assembled v7 webapp for those literals, to
  point it at the stand-ins.
- Proving a plugin fixed locally: `mvn install` in its clone, then `E2E_MVN_OFFLINE=1` so the v8 site takes the local
  repository rather than the newer remote snapshot. Offline must not reach the v7 site, which downloads its own
  artefacts; check afterwards that the change is in the war, otherwise the run proved the old build.
- A v7 pom often declares its dependencies as open ranges whose top has moved: the v7 site no longer compiles.
  `E2E_V7_DEP_PINS` freezes those versions in the disposable worktree, as a one-value range (a plain version loses
  against a range).
- A bench's host port is recorded in its state (`benches/<name>/port`), chosen once among the free ones.
- A plugin bench also scans the site's exploded webapp: every element carries `origin`, otherwise the core's reds
  drown the plugin's in the report.
- TinyMCE copies the editor content into the textarea at submit: a DOM `fill` on the hidden textarea is overwritten.
  The `fill` step feeds the editor too.
- A plugin's sample data (`init_db_<p>_data_sample.sql`) is consumed by the fuzzer from the first run: scenarios never
  rely on it, they read `seed-<plugin>.sql`.
- Without an SMTP sink, `MailService.sendMailHtml` throws `MailConnectException` (localhost:25) and the business flow
  that calls it before writing to the database fails: Mailpit in the stack, addressed by environment variables
  (MicroProfile Config reads `MAIL_SERVER` for `mail.server`).
- A plugin bench opens only the plugin's screens: `E2E_SCOPE=target` filters discovery and suites on the
  `origin=target` inventory.
- Under pytest-xdist, `pytest_runtest_makereport` fires on every worker and on the controller: without a guard each
  result is written twice (gwN.jsonl + main.jsonl) and the report doubles the counters. Guard: write only on a worker
  (numprocesses set ⇒ require PYTEST_XDIST_WORKER).
