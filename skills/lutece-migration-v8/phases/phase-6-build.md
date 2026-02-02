# Phase 6: Build, Verification & Final Review

---

## Step 1 — Full verification sweep

Run the complete verification script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/verify-migration.sh"
```

**ALL checks must PASS** (WARN is acceptable but should be fixed if possible).

If any FAIL → go back to the relevant phase and fix the issue. Do NOT proceed to build with FAIL checks.

---

## Step 2 — First build (skip tests)

```bash
mvn clean install -Dmaven.test.skip=true
```

### Build-fix loop protocol

If BUILD FAILURE:
1. Read the **first** error message from the Maven output
2. Identify the root cause (missing import, wrong type, missing method, etc.)
3. Fix in the source file
4. Re-run `mvn clean install -Dmaven.test.skip=true`
5. If new errors → repeat from 1
6. **Maximum 5 iterations** — if still failing after 5 attempts, report to user with the remaining errors and ask for guidance

Common build errors after migration:
- Missing import → add the correct Jakarta/CDI import
- Cannot find symbol → class API changed in v8, check `~/.lutece-references/`
- Incompatible types → v8 changed return types or method signatures
- `final` keyword on CDI-managed class → remove `final`
- Ambiguous CDI beans → add `@Named` qualifier or fix Producer

---

## Step 3 — Full build (with tests)

```bash
mvn clean install
```

If TEST FAILURE:
1. Read the test failure output
2. Common causes:
   - JUnit 4 annotations not migrated → Phase 5 patterns
   - CDI context not available in tests → add `library-lutece-unit-testing` dependency
   - Mock class names changed → `MokeHttpServletRequest` → `MockHttpServletRequest`
   - Assertion parameter order → JUnit 5 puts message last
3. Fix test issues and re-run
4. **Maximum 5 iterations** — report to user if still failing

---

## Step 4 — V8 compliance review

Launch the **lutece-v8-reviewer** agent:

> Delegate to the `lutece-v8-reviewer` agent to review the project for v8 compliance.

### Handling reviewer results

1. **FAIL items** → You MUST fix every FAIL item. These are migration errors that will cause runtime problems.
2. **WARN items** → You MUST attempt to fix every WARN item. Only skip a WARN fix if it is technically impossible or would break existing functionality — document why in the phase report.
3. After fixing FAIL and WARN items, re-run:
   ```bash
   mvn clean install
   ```
4. If new issues appear after fixes, re-launch the reviewer agent and repeat until clean.
5. **Do NOT mark this phase as completed until:**
   - All FAIL items are resolved
   - All fixable WARN items are addressed
   - `mvn clean install` passes (BUILD SUCCESS)

---

## Step 5 — Final verification

Run one last time:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/verify-migration.sh"
```

This is the final gate. All checks must be clean.

---

## Phase Report

After this phase completes, output the final migration report:

```
## Migration Complete
- Project: [artifactId]
- Version: [old] → [new]
- Parent: [old] → 8.0.0-SNAPSHOT
- Java files migrated: [N]
- Templates migrated: [N]
- JSP files migrated: [N]
- Tests migrated: [N]
- Build: SUCCESS
- Reviewer: PASS (N checks, 0 FAIL, 0 WARN)
- Verification: ALL PASS
```
