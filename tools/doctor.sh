#!/usr/bin/env bash
# doctor.sh — checks that the machine runs lutecepowers the supported way, and says how to fix what does not.
# Usage: doctor.sh [project_dir]
#
# Linux, or Windows through WSL 2, the project in the Linux file system, git keeping the line endings, the Linux
# java (17+) and Maven (3.9, not 4), Python 3.9+, and what the e2e bench needs (Docker, PyYAML, node).
# Prints one line per check, `  PASS|WARN|FAIL [ENVnn] ...`. Exit 0 = no FAIL, 1 = at least one FAIL.
set -uo pipefail

DIR="${1:-$PWD}"
case "${1:-}" in -h|--help) sed -n '2,7p' "$0"; exit 0 ;; esac
NPASS=0; NWARN=0; NFAIL=0

# Prints one verdict line and counts it.
report() {
    case "$1" in PASS) NPASS=$((NPASS+1)) ;; WARN) NWARN=$((NWARN+1)) ;; FAIL) NFAIL=$((NFAIL+1)) ;; esac
    printf '  %s [%s] %s\n' "$1" "$2" "$3"
}

# Tells whether a path sits on a Windows drive mounted by WSL.
on_windows_drive() {
    case "$1" in /mnt/[a-zA-Z]/*|/mnt/[a-zA-Z]) return 0 ;; *) return 1 ;; esac
}

# ENV01: Linux or WSL 2; Git Bash, MSYS, Cygwin and WSL 1 are refused.
check_system() {
    local s r
    s="$(uname -s 2>/dev/null)"; r="$(uname -r 2>/dev/null)"
    case "$s" in
        MINGW*|MSYS*|CYGWIN*) report FAIL ENV01 "Git Bash / MSYS is not supported: install WSL 2 (wsl --install -d Ubuntu-24.04) and work inside it" ;;
        Linux)
            if printf '%s' "$r" | grep -qi 'microsoft-standard-wsl2\|wsl2'; then report PASS ENV01 "WSL 2"
            elif printf '%s' "$r" | grep -qi microsoft; then report FAIL ENV01 "WSL 1 is not supported: wsl --set-version <distribution> 2"
            else report PASS ENV01 "Linux"; fi ;;
        Darwin) report WARN ENV01 "macOS is not verified: Linux or WSL 2 is the supported setup" ;;
        *) report FAIL ENV01 "system $s is not supported: Linux or WSL 2" ;;
    esac
}

# ENV02: the project is in the Linux file system, not on a Windows drive.
check_location() {
    if on_windows_drive "$DIR"; then
        report FAIL ENV02 "$DIR is on a Windows drive: clone the project under ~/ in the Linux file system"
    else
        report PASS ENV02 "project in the Linux file system"
    fi
}

# ENV03: git present, and not converting LF to CRLF on checkout.
check_git() {
    local a
    if ! command -v git >/dev/null 2>&1; then report FAIL ENV03 "git not found: sudo apt install git"; return; fi
    a="$(git -C "$DIR" config core.autocrlf 2>/dev/null || git config --global core.autocrlf 2>/dev/null)"
    if [ "$a" = "true" ]; then
        report FAIL ENV03 "core.autocrlf=true rewrites every file in CRLF: git config --global core.autocrlf input"
    else
        report PASS ENV03 "git keeps the line endings"
    fi
}

# ENV04: a Linux java, version 17 or later.
check_java() {
    local p v
    p="$(command -v java 2>/dev/null)"
    if [ -z "$p" ]; then report FAIL ENV04 "java not found: sudo apt install openjdk-21-jdk-headless"; return; fi
    if on_windows_drive "$p"; then report FAIL ENV04 "java is the Windows one ($p): install openjdk-21-jdk-headless in Linux"; return; fi
    v="$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -1)"
    if [ -n "$v" ] && [ "$v" -ge 17 ] 2>/dev/null; then report PASS ENV04 "java $v"
    else report FAIL ENV04 "java ${v:-unknown} is too old: 17 or later (openjdk-21-jdk-headless)"; fi
}

# ENV05: a Linux Maven 3.9 (3.8 is too old, 4 is not supported).
check_maven() {
    local p v
    p="$(command -v mvn 2>/dev/null)"
    if [ -z "$p" ]; then report FAIL ENV05 "mvn not found: sdk install maven (SDKMAN), not apt"; return; fi
    if on_windows_drive "$p"; then report FAIL ENV05 "mvn is the Windows one ($p): install Maven in Linux (sdk install maven)"; return; fi
    v="$(mvn -v 2>/dev/null | sed -n 's/^Apache Maven \([0-9][0-9.]*\).*/\1/p' | head -1)"
    case "$v" in
        3.9*) report PASS ENV05 "Maven $v" ;;
        4*) report FAIL ENV05 "Maven $v is not supported: Maven 3.9 (sdk install maven 3.9.12)" ;;
        "") report FAIL ENV05 "mvn -v gives no version" ;;
        *) report FAIL ENV05 "Maven $v is too old: Maven 3.9 (sdk install maven)" ;;
    esac
}

# ENV06: Python 3.9 or later, with PyYAML for the e2e bench.
check_python() {
    if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; then
        report FAIL ENV06 "no python3 3.9 or later: sudo apt install python3"; return
    fi
    if python3 -c 'import yaml' >/dev/null 2>&1; then report PASS ENV06 "python3 with PyYAML"
    else report WARN ENV06 "PyYAML missing, the e2e bench needs it: sudo apt install python3-yaml"; fi
}

# ENV07: node, which checks the JavaScript of a plugin (JS07).
check_node() {
    if command -v node >/dev/null 2>&1; then report PASS ENV07 "node $(node --version 2>/dev/null)"
    else report WARN ENV07 "node missing: the JavaScript check JS07 is not evaluated (sudo apt install nodejs)"; fi
}

# ENV08: a reachable Docker daemon, for the e2e bench.
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        report WARN ENV08 "docker missing: the e2e bench cannot run (on Windows, Docker Desktop with the WSL integration of this distribution)"; return
    fi
    if timeout 10 docker info >/dev/null 2>&1; then report PASS ENV08 "docker reachable"
    else report WARN ENV08 "docker does not answer: start it (on Windows, tick this distribution in Docker Desktop > Settings > Resources > WSL integration)"; fi
}

check_system
check_location
check_git
check_java
check_maven
check_python
check_node
check_docker
echo "TOTAL: $((NPASS+NWARN+NFAIL)) checks, PASS $NPASS, WARN $NWARN, FAIL $NFAIL"
[ "$NFAIL" -eq 0 ]
