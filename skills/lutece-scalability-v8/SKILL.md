---
name: lutece-scalability-v8
description: "Make a Lutece v8 plugin horizontally scalable (multi-instance/cluster) and PROVE it. Scans for scalability anti-patterns, applies fixes via Agent Teams, then deploys the plugin in a real 3-instance cluster (Liberty + MariaDB + nginx + Hazelcast) and verifies empirically. Run AFTER the v7→v8 migration."
user-invocable: true
---

# Lutece Scalability v8 — Consolidate & Prove (Agent Teams)

## Purpose

Takes a **v8-compliant** Lutece plugin and makes it **scalable for multi-instance/cluster** deployment, then **proves it empirically** in a real 3-instance cluster.

Unlike migration (largely mechanical), scalability is mostly **semantic** — it needs judgment. So this skill is: **scan (detect) → fix (intelligent teammates + patterns) → PROVE (real cluster test)**. The empirical proof loop is the heart of the skill.

**Prerequisites:** Agent Teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`); Docker + Compose; JDK 21; Maven; access to the Lutece Maven repos (or a populated `~/.m2`).

The 7 scalability axes (observed in core/forms, the architect's work) are documented under `patterns/`. Always read the real references in `~/.lutece-references/` before writing any new pattern.

---

## PHASE A — Scan (Lead executes directly)

### A.0 — Verify v8 compliance (FIRST)
Check that the plugin is **already v8-compliant**:
```bash
mvn -B clean verify -DskipTests
```
If the build **FAILS**, stop. Ask the user: *"The plugin does not build on v8. Please run `lutece-migration-v8-agent-teams` first, then re-run this skill."* — scalability work cannot begin until migration is complete and the code compiles.

If the build **SUCCEEDS**, proceed to A.1.

### A.1 — Scope the analysis (ASK the user)
Scalability defects often live in a plugin's **modules or related plugins**, not the core repo — and the highest-risk one (a reminder/notification **daemon** that would fire once per node) typically sits in a module. But those modules/dependents may be in **separate repositories**, possibly across different hosts/orgs (GitHub `lutece-platform`, `lutece-secteur-public`, an internal GitLab, …). The agent **cannot reliably discover them** and must NOT guess from a naming convention or assume they are local.

So, before scanning, **ask the user**: *"Should the analysis cover only this plugin, or also its modules / related plugins? If so, where are they (local paths, or repos to clone)?"* Then scan **each confirmed target** with `scan-scalability.sh <dir>` and aggregate the results. If the user says "this plugin only", proceed — but state in the final report that modules were out of scope.

### A.1 — Confirm a v8 Lutece plugin
`pom.xml` with `lutece-plugin`/`module`/`library` packaging, already building on v8.

### A.2 — Run the scanner (on EACH target from A.0)
```bash
mkdir -p .scalability
# the plugin itself:
bash ${CLAUDE_PLUGIN_ROOT}/skills/lutece-scalability-v8/scripts/scan-scalability.sh . > .scalability/scan.json
# and one file per additional module/related repo the user confirmed in A.0:
# bash .../scan-scalability.sh <module-dir> > .scalability/scan-<module>.json
```

### A.3 — Show the summary
Read `.scalability/scan.json` and present, per axis, the count + sample files. Flag the **high-risk** axes:
- `1-locks` / `1-id` — contended resource (slot, quota, stock). Highest priority. Pick the primitive by the data model: **counter column → atomic CAS UPDATE** (preferred, lock-free); **`COUNT(*)` → DB distributed lock**. Don't lock by default (`patterns/distributed-lock.md`).
- `3-singleton` / `3-cdi-static` — mutable static state diverging across nodes.
- `2-session` / `2-nonserial` — non-serializable / heavy session state, `Future`/`Timer` in session.
- `2-sessionscoped` — stateful `@SessionScoped`/`@ConversationScoped` beans: whole graph `Serializable` + passivation test, **and** the cluster MUST run Liberty `writeContents="GET_AND_SET_ATTRIBUTES"` — the default does not replicate in-place bean mutations, invisible until a node switch (`patterns/serialization-session.md`).
- `4-cache` — JVM-local cache.
- `5-config` / `6-streams` / `6-threadlocal` — hardcoded config, container streams, thread-locals.

A finding count is a **review pointer**, not an auto-fix list — scalability fixes require judgment.

---

## PHASE B — Plan (Lead executes directly)

Map findings → axes → teammates. Decide how many teammates (1 per non-empty axis group; merge small ones). Write a short plan per teammate listing the files it owns (no overlap — file ownership).

---

## PHASE C — Spawn Teammates

Switch to **Delegate Mode**. From here, orchestrate only — never modify files.

Spawn the teammates whose axes have findings:

| Teammate | Instructions | Axes |
|---|---|---|
| Locks & Concurrency | `teammates/locks-concurrency.md` | `1-locks`, `1-id` |
| CDI scopes & singletons | `teammates/cdi-scopes.md` | `3-singleton`, `3-cdi-static`, `4-cache` |
| Serialization & session | `teammates/serialization-session.md` | `2-session`, `2-nonserial` |
| Config & robustness | `teammates/config-robustness.md` | `5-config`, `6-streams`, `6-threadlocal` |
| Verifier | `teammates/verifier.md` | builds + runs the cluster test |

### Spawn template
```
Read your instruction file at ${CLAUDE_PLUGIN_ROOT}/skills/lutece-scalability-v8/teammates/<file>.md.
Your findings are in .scalability/scan.json (your axes only). Own only your assigned files.
Patterns: ${CLAUDE_PLUGIN_ROOT}/skills/lutece-scalability-v8/patterns/ — load only what you need.
Reference-first: ALWAYS read ~/.lutece-references/ (especially lutece-form-plugin-forms and lutece-core) before writing any pattern.
Run verify-file.sh after each file you change. Never commit.
```

---

## PHASE D — Dependencies

```
CDI scopes & singletons ─┐
Serialization & session ─┤ (run first — locks/config may depend on the new beans)
                         │
   Locks & Concurrency ──┤ (DB lock often uses a CDI-managed LockDAO/Home)
   Config & robustness ──┘
                         │
                         └──→ Verifier: build + cluster test (after ALL fixers complete)
```

---

## PHASE E — Monitor

- Check task progress periodically.
- A teammate stuck > 5 min → ask for status via mailbox.
- A teammate reports a blocker → investigate, advise, or reassign.

---

## PHASE F — Build + Empirical Cluster Test (Verifier)

The Verifier (`teammates/verifier.md`):
1. `mvn -B clean install` (compile, then with tests).
2. Generate the disposable cluster for this plugin:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/skills/lutece-scalability-v8/scripts/gen-test-site.sh \
        --local . --enable <plugin-names> --out e2e/.scalability-test
   ```
3. `( cd e2e/.scalability-test && docker compose up -d )`, wait for the 3 apps ready + dbinit.
4. **READ THE DOCKER LOGS — ESSENTIAL, BEFORE the functional test.** Never trust a green-looking boot; `docker compose logs` and confirm, on every node:
   - the plugin-under-test's **own schema was deployed** — its changesets appear in the logs / `DATABASECHANGELOG`. If absent, look for `LiquibaseRunner files not managed by liquibase are <file>` → that `.sql` is **missing its `-- liquibase formatted sql` header** (see the `sql-liquibase` rule). A plugin whose SQL silently didn't deploy invalidates the whole test.
   - **no startup exception / stack trace / `WELD-` / `SRCFG` / `Failed to serialize`**. In particular Hazelcast forms **two distinct member groups** (HTTP-session vs JCache, different class loaders) — they MUST have different `cluster-name`s, else partition migration fails with `Failed to serialize ...MigrationOperation` (see harness `hazelcast.xml` / `hazelcast-session.xml`).
   - `cluster-verify.sh` health (3 instances, shared DB, single Liquibase migration, both Hazelcast groups formed, session replicated):
   ```bash
   LOCK_TABLE=<plugin>_lock bash ${CLAUDE_PLUGIN_ROOT}/skills/lutece-scalability-v8/scripts/cluster-verify.sh e2e/.scalability-test
   ```
5. **Prove the contended resource FUNCTIONALLY — the heart of the proof.** Cluster health is necessary but NOT sufficient: drive the *real* functional operation **concurrently across the cluster** (through nginx, so requests hit different nodes with replicated sessions) and assert in the DB that the invariant holds — e.g. N concurrent clients book/reserve/consume the same limited resource (capacity M) → **exactly M succeed, never more**, counters never drift. Reuse the plugin's own e2e (e.g. Playwright under the site's `e2e/`) when present; otherwise script the real flow (admin setup + N concurrent front-office/API operations on one resource). Verify against the DB (source of truth), not the UI.
   - **If the flow is a stateful multi-step wizard (`@SessionScoped`), this also proves session replication of the CDI bean** — the single thing `cluster-verify.sh` cannot prove (its admin-auth check is a false-green; see §6/§7). The flow completing end-to-end while its steps are served by *different* nodes (log the upstream per step) IS the proof. If a step returns "session lost" / "form no longer valid" while a different node served the previous step → it's the Liberty `writeContents` default (see `patterns/serialization-session.md`), and the harness e2e gotchas in `harness/README.md` apply (expect_navigation, cookie overlay, domcontentloaded).
6. **FAILOVER proof (resilience — kill a node mid-flow).** Round-robin proves the state *crosses* live nodes; a node-kill proves it *survives the death* of the node that created it (Hazelcast backup promotion) — a distinct axis. For a stateful flow: reach the mid-point (e.g. the recap, state now in session), identify the node that served it (`X-Upstream`), **`docker kill` that node**, then complete the operation → it must finish on a SURVIVOR (nginx skips the dead upstream; retry once, the first request may hit it before nginx marks it down) and the result must be in the DB. The killed node's peers should log only "removing connection to [dead]" warnings, no errors. Restart it afterwards and confirm it rejoins the mesh. (Reference artifact: a plugin-specific `e2e/failover_*.py` driving its real flow.)
7. **READ THE DOCKER LOGS AGAIN — ESSENTIAL, AFTER the test.** Re-`docker compose logs` and confirm the concurrent load produced **no 500 / no exception / no serialization or lock error**. A test that "passed" while the logs were full of errors did not pass.
8. On FAIL, route the fix to the responsible teammate and re-run.
9. Teardown: `docker compose down -v`.

> **Reading the Docker logs before AND after the functional test is a mandatory step, not optional.** Most cluster-only defects (schema not deployed, class-loader serialization, session not replicating, swallowed exceptions) are invisible from HTTP status codes and only show in the logs.

A green run proves: 3 instances serving, shared DB, single Liquibase migration, both Hazelcast groups formed, session replicated across nodes (no sticky) **and surviving a node kill** (failover), and — for a contended resource — that concurrent real operations never exceed capacity (no double-booking / oversell), with clean logs throughout.

---

## PHASE G — Review & Final Gate

1. When build + `cluster-verify.sh` are green, spawn the **v8 reviewer** (`${CLAUDE_PLUGIN_ROOT}/agents/lutece-v8-reviewer.md`) read-only; resolve FAIL items via teammates.
2. Present the summary: scan deltas, build result, `cluster-verify.sh` PASS/FAIL, files modified.
3. Clean up `.scalability/` and the team. **STOP. Never commit** — the user decides.

---

## Strict Rules

1. **Run after migration** — the plugin must already be v8-compliant and compile.
2. **Delegate mode** after Phase B — the Lead orchestrates only.
3. **Reference-first** — copy the real mechanics from `~/.lutece-references/` (forms `LockDAO`/`forms_lucene_lock`, core CDI/serialization), never invent.
4. **File ownership** — one file, one teammate.
5. **Prove, don't assume** — a fix is "done" only when the cluster test is green. Test **with Hazelcast on** (ehcache hides serialization bugs).
6. **No `@Deprecated`** (house rule) — when removing `getInstance()`, delete it and migrate callers; do not leave a deprecated bridge.
7. **NEVER commit.**

---

## Script Locations
All in `${CLAUDE_PLUGIN_ROOT}/skills/lutece-scalability-v8/scripts/`:

| Script | Purpose | Used by |
|--------|---------|---------|
| `scan-scalability.sh` | Scan 7-axis anti-patterns → JSON | Lead (A) |
| `verify-file.sh` | Per-file residual anti-pattern check | Fixer teammates |
| `gen-test-site.sh` | Generate a disposable 3-node Docker cluster for the plugin | Verifier (F) |
| `cluster-verify.sh` | Empirical scalability proofs against the running cluster | Verifier (F) |

## Pattern Locations
All in `${CLAUDE_PLUGIN_ROOT}/skills/lutece-scalability-v8/patterns/`:

| File | Axis |
|------|------|
| `distributed-lock.md` | 1 — concurrency, contended resources, ID generation |
| `cdi-scopes.md` | 3 — static singletons → CDI beans |
| `serialization-session.md` | 2 — Serializable session/cache, session state |
| `cache-distributed.md` | 4 — JSR-107 / Hazelcast distributed cache |
| `config-and-robustness.md` | 5 & 6 — MicroProfile config, streams, thread-locals, determinism |

## Test Harness
`${CLAUDE_PLUGIN_ROOT}/skills/lutece-scalability-v8/harness/` — a proven, parameterized 3-instance cluster (Liberty + MariaDB + nginx + Hazelcast, Liquibase migrator pattern, sessionCache session replication). `gen-test-site.sh` templates it for the plugin under test. See `harness/README.md`.
