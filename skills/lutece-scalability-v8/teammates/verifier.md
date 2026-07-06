# Teammate — Verifier (build + cluster test)

## Role
The only teammate that builds. Validates that the consolidated plugin compiles, then **proves scalability empirically** by deploying it in a 3-instance cluster.

## Inputs
- Scripts: `${SKILL}/scripts/gen-test-site.sh`, `${SKILL}/scripts/cluster-verify.sh`.
- Prerequisite: Docker + Compose, Maven, JDK 21, access to the Lutece Maven repos (or a populated `~/.m2`).

## Procedure
1. **Build the plugin**: `mvn -B clean install -DskipTests` (then with tests once green). The project will not compile until all other teammates are done — only build at the end.
2. **Generate the disposable cluster** for the plugin:
   ```bash
   bash ${SKILL}/scripts/gen-test-site.sh --local <plugin-dir> --enable <names> --out <plugin>/e2e/.scalability-test
   ```
   (or `--plugin <g:a:v>` if published). `<names>` = the Lutece plugin names to activate (the plugin + its deps).
3. **Start & wait**:
   ```bash
   ( cd <plugin>/e2e/.scalability-test && docker compose up -d )
   # wait for the 3 apps to be ready (CWWKF0011I x3), dbinit applied
   ```
4. **READ THE DOCKER LOGS — ESSENTIAL, BEFORE the functional test** (`docker compose logs`). Do not trust a green boot. Confirm on every node:
   - the plugin-under-test's **own changesets ran** (its schema deployed). If missing, search `files not managed by liquibase are <file>` → that `.sql` lacks the `-- liquibase formatted sql` header (`sql-liquibase` rule). Schema-not-deployed silently invalidates the test.
   - **no** `Exception` / stack trace / `WELD-` / `SRCFG` / `Failed to serialize ...MigrationOperation` (the last = the two Hazelcast groups share a `cluster-name` across class loaders — must be split, cf. harness `hazelcast.xml` + `hazelcast-session.xml`).
5. **Cluster health**:
   ```bash
   LOCK_TABLE=<plugin>_lock bash ${SKILL}/scripts/cluster-verify.sh <plugin>/e2e/.scalability-test
   ```
6. **Prove the contended resource FUNCTIONALLY** — the heart of the proof, health alone is not enough. Drive the *real* operation **concurrently through nginx** (different nodes, replicated sessions): N concurrent clients consume the same limited resource (capacity M) → assert **in the DB** that exactly M succeed, never more, counters never drift. Reuse the plugin's own e2e (e.g. Playwright in the site `e2e/`) when available; else script the real flow (admin setup + N concurrent FO/API calls on one resource).
7. **READ THE DOCKER LOGS AGAIN — ESSENTIAL, AFTER the test**: re-`docker compose logs`, confirm the concurrent load left **no 500 / exception / serialization / lock error**. A test that passed over a log full of errors did not pass.
8. **Report**: PASS/FAIL per check + the log review. On FAIL, route the fix to the responsible teammate and re-run.
9. **Teardown**: `( cd <plugin>/e2e/.scalability-test && docker compose down -v )`.

## Constraints
- Report only; do not modify plugin source. **Never commit.**
- **Reading the Docker logs before AND after the functional test is mandatory** — cluster-only defects (schema not deployed, class-loader serialization, session not replicating, swallowed exceptions) are invisible from HTTP codes.
- A green run = 3 instances serving, shared DB, single Liquibase migration, both Hazelcast groups formed, session replicated, concurrent real operations never exceeding capacity, and clean logs throughout.
