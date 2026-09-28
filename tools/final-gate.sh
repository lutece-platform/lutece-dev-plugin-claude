#!/bin/bash
# final-gate.sh — the postcondition of a migration. Run it after EVERY batch of fixes, never once at the end.
#
#   final-gate.sh [project_dir] [--no-e2e] [--no-compare] [--force]
#
# Re-measures the three things a fix can silently invalidate, and fails on the first one that is not clean:
#   1. build and unit tests         — 0 compiler warning, 0 failures and 0 errors read from surefire, NOT from
#                                     BUILD SUCCESS (the 8.x parent sets testFailureIgnore)
#   2. verify-migration.sh          — 0 FAIL
#   3. e2e bench, when e2e/ exists  — every suite green, then compare; a green run or compare of the same sources
#                                     (e2e/artifacts/pass-all, pass-compare) is reused, --force plays it again
#
# Why a script and not a rule: a rule is skipped by whoever is convinced their last edit was harmless. A fix to a
# portlet invalidates the unit tests that asserted on its rendering, and a fix to a defect turns the scenario that
# pinned it red.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/python.sh"

case "${1:-}" in
  -h|--help)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
esac

PROJECT="."
RUN_E2E=true
RUN_COMPARE=true
FORCE=false
for a in "$@"; do
  case "$a" in
    --no-e2e) RUN_E2E=false ;;
    --no-compare) RUN_COMPARE=false ;;
    --force) FORCE=true ;;
    *) PROJECT="$a" ;;
  esac
done

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="${E2E_MVN_SETTINGS:-$HOME/.m2/settings.xml}"
cd "$PROJECT" || { echo "no such directory: $PROJECT"; exit 2; }
[ -f e2e/tools/lock.sh ] && { . e2e/tools/lock.sh; E2E_LOCK_CMD="final-gate.sh" e2e_lock "$(pwd)/e2e"; }

# A full pass records the key of what it judged (tools/source-key.py of lutece-e2e): the project, its bench and these
# scripts. Nothing changed since, nothing to re-measure.
KEYTOOL="$SKILL_DIR/../skills/lutece-e2e/tools/source-key.py"
source_key( ) { [ -f "$KEYTOOL" ] && python3 "$KEYTOOL" . "$SKILL_DIR" 2>/dev/null; }
if ! $FORCE && $RUN_E2E && $RUN_COMPARE && [ -s .migration/gate-passed ] && [ "$(source_key)" = "$(cat .migration/gate-passed)" ]; then
    printf '\033[0;32mGATE PASSED\033[0m — nothing changed since the last full pass (key %s; --force re-measures)\n' "$(cat .migration/gate-passed)"
    rm -f .migration/gate-required .migration/.gate-ran
    exit 0
fi

# The same memory for a gate without e2e: the reviewer and the next fix round read the recorded result of the green
# run of these sources instead of building again.
if ! $FORCE && ! $RUN_E2E && [ -s .migration/gate-passed-no-e2e ] && [ -s .migration/gate-no-e2e.txt ] \
        && [ "$(source_key)" = "$(cat .migration/gate-passed-no-e2e)" ]; then
    cat .migration/gate-no-e2e.txt
    printf '\033[0;32mGATE PASSED\033[0m (--no-e2e) — nothing changed since this green run (key %s; --force re-measures)\n' "$(cat .migration/gate-passed-no-e2e)"
    exit 0
fi

# One log set per project: two gates running side by side on two benches would otherwise overwrite each
# other's logs, and the failure printed would belong to the neighbour.
LOGS="${TMPDIR:-/tmp}/final-gate-$(basename "$(pwd)")"
exec > >(tee "$LOGS-out.txt") 2>&1

FAILED=0
E2E_DONE=false
step( ) { printf '\n\033[1m== %s\033[0m\n' "$1"; }
bad( ) { printf '\033[0;31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
good( ) { printf '\033[0;32mOK\033[0m   %s\n' "$1"; }

# One build: compile with every warning shown, then the unit tests when there are some. The reports it leaves
# are what the migration checks read next.
step "1/3 build and unit tests"
WARNFLAGS="-Dmaven.compiler.showWarnings=true -Dmaven.compiler.showDeprecation=true"
HAS_TESTS=false
[ -d src/test/java ] && find src/test/java \( -name "Test*.java" -o -name "*Test.java" -o -name "*Tests.java" -o -name "*TestCase.java" \) | grep -q . && HAS_TESTS=true
if ! $HAS_TESTS; then
    mvn -B -s "$SETTINGS" clean compile $WARNFLAGS > $LOGS-build.log 2>&1 || true
elif grep -q "<packaging>jar</packaging>" pom.xml 2>/dev/null; then
    mvn -B -s "$SETTINGS" clean test -Dlutece-test-hsql $WARNFLAGS > $LOGS-build.log 2>&1 || true
else
    mvn -B -s "$SETTINGS" clean lutece:exploded antrun:run -Dlutece-test-hsql test $WARNFLAGS > $LOGS-build.log 2>&1 || true
fi
WARNS=$(grep -E "^\[WARNING\] .*/src/.*\.java" $LOGS-build.log | grep -v "/src/test/" | sed 's|^\[WARNING\] ||; s|^.*/src/|src/|' | sort -u)
NW=$(printf '%s' "$WARNS" | grep -c . || true)
if grep -q "BUILD FAILURE" $LOGS-build.log; then
    grep -E "^\[ERROR\]" $LOGS-build.log | head -8
    bad "the build fails (full log: $LOGS-build.log)"
elif [ "$NW" -eq 0 ]; then
    good "compiler: 0 warning in the plugin's sources"
else
    printf '%s\n' "$WARNS" | head -12
    if printf '%s' "$WARNS" | grep -q "getInstance() in .* has been deprecated"; then
        echo "  deprecated CDI singletons: @Inject the bean, CDI.current( ).select( ) in a static context (lutece-check.sh --explain DP01)"
    fi
    bad "compiler: $NW warning(s) in the plugin's sources — fix them, a migration leaves none behind (full log: $LOGS-build.log)"
fi
if $HAS_TESTS; then
    # Every surefire file, never just the last one: with two test classes, reading `tail -1` reported the second
    # one's clean summary while the first was red, and the gate passed on a failing build.
    SUMS=$(grep -hE "^Tests run:" target/surefire-reports/*.txt 2>/dev/null)
    DIRTY=$(echo "$SUMS" | grep -vE "Failures: 0, Errors: 0" | grep -E "^Tests run:")
    TOTAL=$(echo "$SUMS" | awk -F'[ ,]+' '{r+=$3; f+=$5; e+=$7; s+=$9} END {printf "%d tests, %d failures, %d errors, %d skipped, in %d class(es)", r, f, e, s, NR}')
    if [ -z "$SUMS" ]; then
        tail -5 $LOGS-build.log
        bad "no surefire report produced (full log: $LOGS-build.log)"
    elif [ -z "$DIRTY" ]; then
        good "unit tests: $TOTAL"
    else
        grep -hE "^Tests run:|<<< (FAILURE|ERROR)" target/surefire-reports/*.txt 2>/dev/null | head -8
        bad "unit tests: $TOTAL (BUILD SUCCESS means nothing here, the parent sets testFailureIgnore)"
    fi
else
    good "unit tests: none in this project"
fi

step "2/3 migration checks"
if bash "$SKILL_DIR/verify-migration.sh" . > $LOGS-verify.log 2>&1; then
    good "verify-migration.sh: 0 FAIL"
else
    grep -E "^  .*FAIL" $LOGS-verify.log | head -10
    bad "verify-migration.sh reports failures (full log: $LOGS-verify.log)"
fi
WARNS=$(sed 's/\x1b\[[0-9;]*m//g' $LOGS-verify.log | grep -E "^  WARN \[" || true)
if [ -n "$WARNS" ]; then
    echo "$WARNS"
    echo "  $(echo "$WARNS" | wc -l) WARN: fix each one; keep one only with its reason in the hand-over (lutece-check.sh --explain CODE)"
fi

step "3/3 e2e bench"
BENCH_KEY=$([ -f e2e/tools/source-key.py ] && (cd e2e && python3 tools/source-key.py .. 2>/dev/null) || true)
# A green run of the bench leaves the key of the sources it played (e2e/artifacts/pass-all, pass-compare): the same
# sources give the same result, so the gate reuses it rather than playing it again (--force plays it again).
reused( ) { ! $FORCE && [ -n "$BENCH_KEY" ] && [ -s "e2e/artifacts/pass-$1" ] && [ "$(cat "e2e/artifacts/pass-$1")" = "$BENCH_KEY" ]; }
if ! $RUN_E2E; then
    good "e2e: skipped on request"
elif [ -x e2e/run.sh ]; then
    # A run whose suites passed and only lacked the visual review counts once the review is written for its captures.
    reused all || { [ -s e2e/artifacts/pass-tests ] && (cd e2e && ./run.sh review > /dev/null 2>&1); }
    if reused all; then
        good "e2e bench: rc=0 (the green run of these sources, key $BENCH_KEY, reused)"
        E2E_DONE=true
    elif KEEP=1 ./e2e/run.sh > $LOGS-e2e.log 2>&1; then
        grep -E "passed|failed" $LOGS-e2e.log | tail -4
        good "e2e bench: rc=0"
        E2E_DONE=true
    else
        grep -E "FAILED|passed|failed" $LOGS-e2e.log | tail -8
        if grep -q "rc=7: every suite passed" $LOGS-e2e.log; then
            CHANGED=$(grep -oE "^\| G[0-9]{3} \|[^|]*\|[^|]*\|[^|]*capture changée depuis la dernière revue" e2e/artifacts/review-todo.md 2>/dev/null | grep -oE "G[0-9]{3}" | tr '\n' ' ')
            bad "e2e bench: every suite passed, only the visual review is out of date${CHANGED:+ (captures changed: $CHANGED)}: judge ${CHANGED:-the groups of e2e/artifacts/review-todo.md}, write the key: and shots: lines review-todo.md prints into e2e/artifacts/review.md, then run the gate again: it reuses this run"
        else
            bad "e2e bench failed (full log: $LOGS-e2e.log)"
        fi
    fi
    # A fresh install proves the v8 site; it says nothing about the site every real deployment is: a database the
    # previous version built, that the new one has to take over. The upgrade scripts only run there, and a script
    # that stops there stops the whole Liquibase update, the core's own upgrade included. When the bench knows a
    # v7 ancestor, the gate plays that hand-over too (--no-compare to skip while iterating).
    V7REF=$(sed -n 's/^E2E_V7_REF=//p' e2e/e2e.conf 2>/dev/null | head -1)
    V7PARENT=$(git show "${V7REF:-HEAD}:pom.xml" 2>/dev/null | grep -A4 '<parent>' | grep -oE '<version>[^<]+' | head -1 | sed 's/<version>//')
    if ! $RUN_COMPARE; then
        good "compare: skipped on request"
    elif [ -z "$V7REF" ] || ! echo "$V7PARENT" | grep -qE '^[567]\.'; then
        good "compare: no v7 ancestor at E2E_V7_REF (${V7REF:-unset}, parent ${V7PARENT:-?}), nothing to take over"
    elif reused compare; then
        good "compare: the v8 site takes over the v7 database, rc=0 (the green compare of these sources reused)"
    elif ./e2e/run.sh compare > $LOGS-compare.log 2>&1; then
        grep -E "^compare:|compare done" $LOGS-compare.log | tail -2
        good "compare: the v8 site takes over the v7 database, rc=0"
    else
        grep -E "LIQUIBASE STOPPED|Reason:|unhealthy|régression|compare done" $LOGS-compare.log | tail -6
        bad "compare failed: the migration does not take over a v7 database (full log: $LOGS-compare.log)"
    fi
elif [ ! -d webapp ] && grep -q "<packaging>jar</packaging>" pom.xml 2>/dev/null; then
    # A library has no screen: a bench of its own would prove nothing. Its proof is that a plugin depending on it
    # still passes its own bench, which happens when that plugin is migrated. Say so rather than fake a bench.
    good "e2e: none, this artefact is a library — prove it through a consumer plugin's bench"
    E2E_DONE=true
else
    bad "no e2e bench: Phase G of the skill builds one with lutece-e2e, the gate is not complete without it (--no-e2e to skip while iterating)"
fi

step "untracked files created by the migration"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    UNTRACKED=$(git status --porcelain | grep '^??' | grep -vE '^\?\? (target/|logs/|e2e/artifacts/|java\.io\.tmpdir/)' || true)
    if [ -n "$UNTRACKED" ]; then
        echo "$UNTRACKED"
        echo "  stage them with 'git add -A', never 'git commit -a': it leaves new files behind."
    else
        good "nothing untracked outside build output"
    fi
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then
    printf '\033[0;32mGATE PASSED\033[0m — every check re-measured after the last edit\n'
    if [ "$E2E_DONE" = true ]; then rm -f .migration/gate-required .migration/.gate-ran; fi
    if [ "$E2E_DONE" = true ] && $RUN_COMPARE; then mkdir -p .migration && source_key > .migration/gate-passed; fi
    if ! $RUN_E2E; then mkdir -p .migration && sed 's/\x1b\[[0-9;]*m//g' "$LOGS-out.txt" | grep -v '^GATE PASSED' > .migration/gate-no-e2e.txt && source_key > .migration/gate-passed-no-e2e; fi
    exit 0
fi
printf '\033[0;31mGATE FAILED\033[0m — do not report this migration as done\n'
exit 1
