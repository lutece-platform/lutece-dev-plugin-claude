# e2e — configuration of the test bench of @@NAME@@

This folder holds only the bench's configuration and the outputs of its runs; the bench itself is the `lutece-e2e`
skill of lutecepowers, run on the machine's shared e2e server. It is never committed (`.gitignore`).

From the project, with `LPE2E=${LUTECEPOWERS_ROOT}/skills/lutece-e2e/lpe2e`:

```bash
bash $LPE2E               # everything: build if needed, start, inventory, discovery, tests, perf, report, stop
KEEP=1 bash $LPE2E        # same, the bench stays up
bash $LPE2E watch         # the hot loop on a running bench: every change applied and tested in seconds
bash $LPE2E test          # every suite on a running bench
bash $LPE2E report        # rebuilds summary.md / report.html from the artifacts
bash $LPE2E down          # removes the bench's containers and database
bash $LPE2E help          # every command
```

Then read **`artifacts/summary.md`**: inventory coverage (**proven** by a scenario with an oracle / only reached /
excluded with a reason / to cover), visible debt, what the passed tests show (screen kinds), duplicate-content alarm,
failures in three sections (functional, front, robustness) with their server cause, timings, SQL, JFR. Screenshots
and details in `artifacts/report.html`, JUnit in `artifacts/junit-*.xml`.

A failure is a finding about the application until proven otherwise: JSP that do not compile, dead links, JS errors,
screens answering "Internal error", a confirmation form without its CSRF token.

## What is here

| Path | What it is |
|---|---|
| `e2e.conf` | target, bench name, extra plugins (`E2E_PLUGINS`), plugins to enable (`E2E_ENABLE`), scope, pins |
| `scenarios/*.yaml` | the scenarios (one file per feature, plus `<artefact>-negative.yaml`); `screens.yaml` the per-screen rules; `coverage-exclusions.yaml` what the bench cannot reach, with its reason |
| `fixtures/` | files the scenarios upload |
| `harness/db/seed-*.sql` | the bench's own rows (reference data, restricted accounts, volume) |
| `harness/site/webapp/` | files laid over the bench site (a `conf/override` property) |
| `harness/app.env` | environment of the application (MicroProfile Config keys) |
| `harness/server-errors-allow.txt` | server errors expected on this bench, one regex per line, each with its reason |
| `baselines/aria/` | the structural baseline of the screens, seeded by the first run |
| `artifacts/` | the outputs of the last run |
