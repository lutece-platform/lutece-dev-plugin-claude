#!/usr/bin/env bash
# Checks I18N03 (a key of the default bundle missing from _fr, or the reverse) both ways, and that a key nothing uses
# is left to I18N08: removing it is the fix, translating it is not.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
V="$HERE/../../tools/verify-migration.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
P="$T/plugin-x"; R="$P/src/java/fr/paris/lutece/plugins/x/resources"
mkdir -p "$R"
printf '<project><modelVersion>4.0.0</modelVersion><groupId>x</groupId><artifactId>plugin-x</artifactId><version>1.0.0-SNAPSHOT</version></project>\n' > "$P/pom.xml"
printf 'label.used=Used\nlabel.dead=Dead\nlabel.both=Both\n' > "$R/x_messages.properties"
printf 'label.both=Les deux\nlabel.frOnly=Seulement\n' > "$R/x_messages_fr.properties"
printf 'package fr.paris.lutece.plugins.x;\npublic class XService\n{\n    static final String[] KEYS = { "x.label.used", "x.label.both", "x.label.frOnly" };\n}\n' > "$P/src/java/fr/paris/lutece/plugins/x/XService.java"
( cd "$P" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -q -m init )
out=$(cd "$P" && bash "$V" . 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
block() { echo "$out" | awk -v c="$1" '$0 ~ "(FAIL|WARN|PASS) \\[" c "\\]" { on = 1; print; next } on && /^    / { print; next } { on = 0 }'; }
fail=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; block I18N03; block I18N08; fi; }
check "I18N03 fails a used key missing from _fr" 'block I18N03 | grep -q "label.used missing"'
check "I18N03 fails a key of _fr missing from the default bundle" 'block I18N03 | grep -q "label.frOnly missing"'
check "I18N03 leaves a key nothing uses to I18N08" '! block I18N03 | grep -q "label.dead" && block I18N08 | grep -q "label.dead"'
exit $fail
