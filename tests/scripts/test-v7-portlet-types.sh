#!/usr/bin/env bash
# Checks the portlet types the v7 leg registers: those of an installed plugin's descriptor, as Plugin.install( ) does;
# none for a plugin plugins.dat leaves off, none for a portlet without a home class.
set -u
. "$(dirname "$0")/../../tools/python.sh"
E="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
P="$T/WEB-INF/plugins"; mkdir -p "$P"
printf 'demo.installed=1\nother.installed=0\n' > "$P/plugins.dat"
printf '<plug-in><name>demo</name><portlets><portlet><portlet-class>x.DemoPortletHome</portlet-class><portlet-type-id>DEMO_PORTLET</portlet-type-id><portlet-type-name>demo.portlet.name</portlet-type-name><portlet-creation-url>plugins/demo/CreatePortletDemo.jsp</portlet-creation-url></portlet><portlet><portlet-type-id>NO_HOME</portlet-type-id></portlet></portlets></plug-in>\n' > "$P/demo.xml"
printf '<plug-in><name>other</name><portlets><portlet><portlet-class>y.OtherPortletHome</portlet-class><portlet-type-id>OTHER_PORTLET</portlet-type-id></portlet></portlets></plug-in>\n' > "$P/other.xml"
out=$(python3 "$E/tools/v7-portlet-types.py" "$T")
check "the installed plugin's portlet type is replaced, with its plugin name" 'echo "$out" | grep -q "^DELETE FROM core_portlet_type WHERE id_portlet_type = '"'"'DEMO_PORTLET'"'"';" && echo "$out" | grep -q "'"'"'x.DemoPortletHome'"'"', '"'"'demo'"'"'"'
check "a portlet without home class is skipped" '! echo "$out" | grep -q NO_HOME'
check "a plugin plugins.dat leaves off registers nothing" '! echo "$out" | grep -q OTHER_PORTLET'
if [ $fail = 0 ]; then echo "PASS: the v7 leg registers the portlet types of its installed plugins"; else echo "$out"; exit 1; fi
