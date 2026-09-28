#!/usr/bin/env bash
# Checks LE01 (verify-migration.sh) and restore-line-endings.sh together: a CRLF file saved as LF or left mixed, and an
# LF file saved as CRLF, fail LE01; the restore puts back HEAD's endings and LE01 passes; content changes survive.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
V="${VERIFY:-$HERE/../../tools/verify-migration.sh}"
R="$HERE/../../tools/restore-line-endings.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0

# Prints the LE01 status of the fixture project.
le01() {
    (cd "$T/p" && bash "$V" . 2>/dev/null) | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '(PASS|FAIL|WARN) \[LE01\]' | cut -d' ' -f1
}

# Records a failure when a condition does not hold.
check() {
    eval "$2" || { echo "FAIL: $1"; fails=$((fails + 1)); }
}

mkdir -p "$T/p/src/java"
cd "$T/p" || exit 1
printf 'class A\r\n{\r\n}\r\n' > src/java/A.java
printf 'class B\n{\n}\n' > src/java/B.java
printf 'class C\r\n{\r\n}\r\n' > src/java/C.java
printf 'class D\r\n{\r\n}\r\n' > src/java/D.java
git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init
check "LE01 passes on an untouched tree" '[ "$(le01)" = PASS ]'

printf 'class A\n{\n    int x;\n}\n' > src/java/A.java
printf 'class B\r\n{\r\n}\r\n' > src/java/B.java
printf 'class C\r\n{\n}\r\n' > src/java/C.java
printf 'class D\r\n{\r\n    int y;\r\n}\r\n' > src/java/D.java
check "LE01 fails on CRLF saved as LF, LF saved as CRLF, CRLF left mixed" '[ "$(le01)" = FAIL ]'

bash "$R" . >/dev/null
check "A is CRLF again with its new line kept" '[ "$(od -An -c src/java/A.java | tr -d " \n")" = "classA\r\n{\r\nintx;\r\n}\r\n" ]'
check "B is LF again" '! grep -q $'"'"'\r'"'"' src/java/B.java'
check "C is CRLF on every line" '[ "$(tr -cd "\r" < src/java/C.java | wc -c)" -eq 3 ]'
check "D, a content change only, is left alone" '[ "$(tr -cd "\r" < src/java/D.java | wc -c)" -eq 4 ]'
check "LE01 passes after the restore" '[ "$(le01)" = PASS ]'

[ "$fails" -eq 0 ] && { echo "PASS: LE01 fails on converted endings, a mixed file included, and restore-line-endings.sh brings back HEAD's"; exit 0; }
exit 1
