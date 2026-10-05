#!/usr/bin/env bash
# Checks that PV02 reads the version of a release tag carrying a build-number suffix, still fails a pom version that is
# not above the last release, and says it could not judge a shallow clone without tags or a folder outside git.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
V="$HERE/../../tools/verify-migration.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# Prints the status of check $5 (PV02 by default) on a fixture whose pom has version $2 and whose repository carries
# tag $3; with $4 = script, an upgrade script is committed after the tag.
pv02() {
    local d="$T/$1"
    mkdir -p "$d"
    printf '<project><modelVersion>4.0.0</modelVersion><groupId>x</groupId><artifactId>plugin-x</artifactId><version>%s</version></project>\n' "$2" > "$d/pom.xml"
    ( cd "$d" && git init -q && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init && git tag "$3" )
    if [ "${4:-}" = script ]; then
        mkdir -p "$d/src/sql/plugins/x/upgrade"
        printf -- '-- liquibase formatted sql\n-- changeset x:update_db_x-2.0.0-2.1.0.sql\nSELECT 1;\n' > "$d/src/sql/plugins/x/upgrade/update_db_x-2.0.0-2.1.0.sql"
        ( cd "$d" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m upgrade )
    fi
    ( cd "$d" && bash "$V" . 2>/dev/null ) | sed 's/\x1b\[[0-9;]*m//g' | grep -oE "(PASS|FAIL|WARN) \[${5:-PV02}\]" | cut -d' ' -f1
}

# Prints the PV02 status of a project with the given pom version, laid out as: shallow (a depth-1 clone without the
# tags of a repository that has a release tag), nogit (a plain folder) or untagged (a full repository, no release).
pv02_where() {
    local d="$T/$1" o="$T/$1-origin"
    case "$1" in
        shallow)
            mkdir -p "$o"
            printf '<project><modelVersion>4.0.0</modelVersion><groupId>x</groupId><artifactId>plugin-x</artifactId><version>%s</version></project>\n' "$2" > "$o/pom.xml"
            ( cd "$o" && git init -q && git add pom.xml && git -c user.name=t -c user.email=t@t commit -q -m a && git tag plugin-x-9.0.0 \
                && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m b )
            git clone -q --depth 1 --no-tags "file://$o" "$d" ;;
        *)
            mkdir -p "$d"
            printf '<project><modelVersion>4.0.0</modelVersion><groupId>x</groupId><artifactId>plugin-x</artifactId><version>%s</version></project>\n' "$2" > "$d/pom.xml"
            [ "$1" = untagged ] && ( cd "$d" && git init -q && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init ) ;;
    esac
    ( cd "$d" && bash "$V" . 2>/dev/null ) | sed 's/\x1b\[[0-9;]*m//g' | grep -oE "(PASS|FAIL|WARN) \[PV02\]" | cut -d' ' -f1
}

fails=0
[ "$(pv02 suffix 2.0.0-SNAPSHOT plugin-x-1.20.8-117214)" = "PASS" ] || { echo "FAIL: a tag with a build-number suffix is read as a version above the pom"; fails=1; }
[ "$(pv02 behind 2.0.0-SNAPSHOT plugin-x-2.1.0 script)" = "FAIL" ] || { echo "FAIL: a version below the last release with an upgrade script since is not a failure"; fails=1; }
[ "$(pv02 quiet 2.0.0-SNAPSHOT plugin-x-2.1.0 none PV02)" = "PASS" ] || { echo "FAIL: a version below the last release without upgrade script since fails PV02"; fails=1; }
[ "$(pv02 quiet2 2.0.0-SNAPSHOT plugin-x-2.1.0 none PV03)" = "WARN" ] || { echo "FAIL: a version below the last release without upgrade script since is not warned (PV03)"; fails=1; }
[ "$(pv02_where shallow 2.0.0-SNAPSHOT)" = "WARN" ] || { echo "FAIL: a shallow clone without tags passes PV02 it could not judge"; fails=1; }
[ "$(pv02_where nogit 2.0.0-SNAPSHOT)" = "WARN" ] || { echo "FAIL: a folder outside git passes PV02 it could not judge"; fails=1; }
[ "$(pv02_where untagged 1.0.0-SNAPSHOT)" = "PASS" ] || { echo "FAIL: a full repository with no release does not pass PV02"; fails=1; }
[ "$fails" -eq 0 ] && { echo "PASS: PV02 reads release tags with a build-number suffix, still fails a version below the last release, and does not pass a shallow clone without tags nor a folder outside git"; exit 0; }
exit 1
