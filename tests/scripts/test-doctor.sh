#!/usr/bin/env bash
# Checks doctor.sh on stubbed systems: Git Bash, WSL 1 and WSL 2, a project on a Windows drive, Maven 4 and 3.8,
# an old java, and git converting line endings.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
DOCTOR="$HERE/../../tools/doctor.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

# Writes a stub command printing the given text.
stub() { mkdir -p "$T/bin"; printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }

# Runs the doctor with the stubs first on the PATH and prints its output.
run() { PATH="$T/bin:$PATH" bash "$DOCTOR" "$@" 2>&1; }

stub java 'echo "openjdk version \"21.0.5\" 2024-10-15" >&2'
stub mvn 'echo "Apache Maven 3.9.12 (abc)"'
stub uname 'case "$1" in -s) echo Linux ;; -r) echo 6.8.0-generic ;; esac'
OUT=$(run "$T"); RC=$?
check "a Linux machine with the right tools passes the blocking checks" "! printf '%s' \"\$OUT\" | grep -q 'FAIL \[ENV0[1-5]\]'"

stub uname 'case "$1" in -s) echo MINGW64_NT-10.0-19045 ;; -r) echo 3.4.10 ;; esac'
OUT=$(run "$T"); RC=$?
check "Git Bash is refused and the exit code says so" "printf '%s' \"\$OUT\" | grep -q 'FAIL \[ENV01\].*WSL 2' && [ $RC -eq 1 ]"

stub uname 'case "$1" in -s) echo Linux ;; -r) echo 4.4.0-19041-Microsoft ;; esac'
OUT=$(run "$T")
check "WSL 1 is refused" "printf '%s' \"\$OUT\" | grep -q 'FAIL \[ENV01\] WSL 1'"

stub uname 'case "$1" in -s) echo Linux ;; -r) echo 5.15.153.1-microsoft-standard-WSL2 ;; esac'
OUT=$(run "$T")
check "WSL 2 passes" "printf '%s' \"\$OUT\" | grep -q 'PASS \[ENV01\] WSL 2'"

OUT=$(run /mnt/c/Users/someone/project)
check "a project on a Windows drive is refused" "printf '%s' \"\$OUT\" | grep -q 'FAIL \[ENV02\]'"

stub mvn 'echo "Apache Maven 4.0.0-rc-4 (abc)"'
OUT=$(run "$T")
check "Maven 4 is refused" "printf '%s' \"\$OUT\" | grep -q 'FAIL \[ENV05\] Maven 4'"

stub mvn 'echo "Apache Maven 3.8.7"'
OUT=$(run "$T")
check "Maven 3.8 is refused" "printf '%s' \"\$OUT\" | grep -q 'FAIL \[ENV05\] Maven 3.8.7 is too old'"

stub java 'echo "openjdk version \"11.0.22\" 2024-01-16" >&2'
OUT=$(run "$T")
check "java 11 is refused" "printf '%s' \"\$OUT\" | grep -q 'FAIL \[ENV04\] Java 11'"

git init -q "$T/repo" && git -C "$T/repo" config core.autocrlf true
OUT=$(run "$T/repo")
check "core.autocrlf=true is refused" "printf '%s' \"\$OUT\" | grep -q 'FAIL \[ENV03\]'"

[ $fail -eq 0 ] && echo "STATUS: PASSED" || { echo "STATUS: FAILED"; exit 1; }
