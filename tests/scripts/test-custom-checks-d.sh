#!/usr/bin/env bash
# Checks the template checks TM02 to TM12 of verify-migration.sh both ways: a template or script in the defect's shape
# fires the check and is named in its report, the v8 form (BO/FO macro variants, null-safe messages, LuteceAutoComplete,
# @cForm, @modal, comments) leaves it green. Each fixture ships both macro families and, but for the TM02 WARN one, no
# pom.xml: the project is its own source and nothing is assembled with Maven.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
V="${VERIFY:-$HERE/../../tools/verify-migration.sh}"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0
A=webapp/WEB-INF/templates/admin/plugins/x
S=webapp/WEB-INF/templates/skin/plugins/x

# Creates an empty fixture project $1 that is its own macro source.
project() {
    mkdir -p "$T/$1/webapp/WEB-INF/templates/admin/themes/tabler/forms/checkbox" "$T/$1/webapp/WEB-INF/templates/skin/themes/macros"
    touch "$T/$1/webapp/WEB-INF/templates/admin/themes/tabler/forms/checkbox/checkBox.ftl"
}

# Writes one file of fixture $1: $2 relative path, $3 content.
put() {
    mkdir -p "$T/$1/$(dirname "$2")"
    printf '%s\n' "$3" > "$T/$1/$2"
}

# Runs verify-migration once on fixture $1 and keeps its report without colours.
run() {
    ( cd "$T/$1" && bash "$V" . 2>/dev/null ) | sed 's/\x1b\[[0-9;]*m//g' > "$T/$1.out"
}

# Records a failure when check $2 does not answer status $3 on fixture $1.
expect() {
    local got
    got=$(grep -oE "(PASS|FAIL|WARN) \[$2\]" "$T/$1.out" | head -1 | cut -d' ' -f1)
    [ "$got" = "$3" ] || { echo "FAIL: $2 on $1 expected $3, got ${got:-nothing}"; fails=$((fails + 1)); }
}

# Records a failure when the report of check $2 on fixture $1 does not name file $3.
names() {
    awk -v c="$2" '$0 ~ "(FAIL|WARN) \\[" c "\\]" { on = 1; next } on && /^    / { print; next } { on = 0 }' "$T/$1.out" | grep -qF "$3" \
        || { echo "FAIL: $2 on $1 does not report $3"; fails=$((fails + 1)); }
}

project good
put good webapp/js/plugins/x/x.js "const el = document.querySelector( '#x' );
el.textContent = \`\${el.id}\`;"
put good webapp/js/plugins/x/lib/legacy.js "\$( '#x' ).hide( );"
put good "$A/good.html" "<@addRequiredBOJsFiles />
<@addFileBOInput fieldName='f' handler=handler cssClass='' multiple=true />
<@addBOUploadedFilesBox fieldName='f' handler=handler listFiles=listFiles />
<#if (errors!)?size gt 0><#list errors as error>\${error.message}</#list></#if>
<#if infos?? && infos?has_content>\${infos?size}</#if>
<#if (warnings![])?has_content>w</#if>
<p>\${error!}</p>
<@modal id='m' title='#i18n{x.title}'>body</@modal>
<#-- <@offcanvas id='o' title='t'>body</@offcanvas> -->
<!-- <div class=\"offcanvas offcanvas-end\"></div> -->
<form action='jsp/admin/plugins/x/ManageX.jsp' method='post'><input type='text' name='a' /></form>
<@tform type='inline' action='jsp/admin/plugins/x/ManageX.jsp'><@input type='hidden' name='id' value='1' /><@button type='submit' title='#i18n{x.export}' /></@tform>
<@tform action='x'><@row><@columns md=6><@input name='a' /></@columns><@columns md=6><@input name='b' /></@columns></@row></@tform>
<#-- <@tform type='inline' action='x'><@input name='a' /><@input name='b' /><@input name='c' /></@tform> -->
<#-- <#if unclosed -->
<#-- <@addFileInput fieldName='f' /> <@addRequiredJsFiles /> \${error} errors?size -->
<!-- jQuery is not loaded: \$( '#x' ) -->
<#if map_errors?size gt 0>m</#if>
<p>\${error}</p>
<#list infos as info>\${info}</#list>
<#list warnings as warning><#if warning.message??>\${warning.message}</#if></#list>
<script>
// \$( '#x' ).hide( );
/* jQuery( '#x' ).show( ); */
</script>
<script type='module'>
import LuteceAutoComplete from './themes/shared/modules/luteceAutoComplete.js';
new LuteceAutoComplete( document.getElementById( 'a' ) );
</script>"
put good "$S/good.html" "<@addRequiredJsFiles />
<@addFileInput fieldName='f' handler=handler cssClass='' multiple=true />
<@addUploadedFilesBox fieldName='f' handler=handler listFiles=listFiles />
<@cForm action='jsp/site/Portal.jsp' method='post' name='x'>
<@cInput type='text' name='a' />
<@cBtn type='submit' label='#i18n{x.send}' />
</@cForm>
<#-- <form action='x'></form> <@cForm foValidation=false></@cForm> -->"
put good webapp/js/plugins/x/editor.umd.js "\$( '#x' ).hide( );"
put good webapp/WEB-INF/templates/skin/themes/x/macros/cOffcanvas.ftl "<#macro cOffcanvas id><div class=\"offcanvas\"></div></#macro>"
put good "$S/standalone.html" "<html><body><form action='jsp/site/Portal.jsp'></form></body></html>"
run good

project bad
put bad webapp/js/plugins/x/x.js "const el = document.querySelector( '#x' );"
put bad "$S/tm02.html" "<script>\$( document ).ready( function( ) { } );</script>"
put bad "$A/tm03.html" "<@addFileInput fieldName='f' handler=handler cssClass='' multiple=true />"
put bad "$S/tm04.html" "<#if errors?size gt 0>e</#if>"
put bad "$S/tm05.html" "<script src='jsp/site/plugins/address/modules/autocomplete/autocomplete-js.jsp'></script>"
put bad "$A/tm06.html" "<@addRequiredJsFiles />"
put bad "$A/tm07.html" "<#list errors as error><@alert color='danger'>\${error}</@alert></#list>"
put bad "$S/tm02-url.html" "<script>const u = 'http://x'; \$( '#y' ).hide( );</script>"
put bad "$A/tm03-ftl.ftl" "<@addUploadedFilesBox
    fieldName='f' />"
put bad "$S/tm07-info.html" "<#list infos as info><p>\${info.message}</p></#list>"
put bad "$A/tm09.html" "<#if x>open"
put bad "$A/tm10.html" "<@offcanvas id='o' title='t'>body</@offcanvas>"
put bad "$S/tm10-markup.html" "<button data-bs-toggle=\"offcanvas\" data-bs-target=\"#o\">x</button>"
put bad "$S/tm11-form.html" "<form action='jsp/site/Portal.jsp' method='post'></form>"
put bad "$S/tm11-novalidation.html" "<@cForm action='jsp/site/Portal.jsp' foValidation=false></@cForm>"
put bad "$S/tm11-tform.html" "<@tform action='jsp/site/Portal.jsp'></@tform>"
put bad "$A/tm12.html" "<@tform type='inline' action='x'><@input name='a' /><@input name='b' /><@input name='c' /></@tform>"
run bad

project jquery
put jquery pom.xml "<project><artifactId>plugin-x</artifactId><dependencies><dependency><artifactId>library-theme-jquery</artifactId></dependency></dependencies></project>"
put jquery webapp/js/plugins/x/x.js "\$( '#x' ).hide( );"
touch -d '2020-01-01' "$T/jquery/pom.xml"
mkdir -p "$T/jquery/target"
printf '0\t%s\tV8FLOOR ok\n' "$T/jquery/pom.xml" > "$T/jquery/target/.v8-floor"
run jquery

project design-bad
put design-bad "$A/tm08.html" "<a href=\"jsp/admin/plugins/x/ManageX.jsp?q=\${q?url}\">x</a>"
run design-bad

project design-good
put design-good webapp/WEB-INF/templates/admin/themes/tabler/aButton.ftl "<#macro aButton href='' title='' color='primary' deprecated...></#macro>"
put design-good "$A/tm08.html" "<a href=\"jsp/admin/plugins/x/ManageX.jsp?q=\${q?url('UTF-8')}\">x</a>
<#-- <a href=\"x?q=\${c?url}\">x</a> -->
<@aButton href='jsp/admin/plugins/x/ManageX.jsp' title='#i18n{portal.util.labelCancel}' color='light' />"
run design-good

for code in TM02 TM03 TM04 TM05 TM06 TM07 TM09 TM10 TM11 TM12; do expect good "$code" PASS; done
for code in TM02 TM03 TM04 TM05 TM06 TM07 TM09 TM10 TM11 TM12; do expect bad "$code" FAIL; done
names bad TM02 "$S/tm02.html"
names bad TM03 "$A/tm03.html"
names bad TM04 "$S/tm04.html"
names bad TM05 "$S/tm05.html"
names bad TM06 "$A/tm06.html"
names bad TM07 "$A/tm07.html"
names bad TM07 "$S/tm07-info.html"
names bad TM03 "$A/tm03-ftl.ftl"
names bad TM02 "$S/tm02-url.html"
names bad TM09 "$A/tm09.html"
names bad TM10 "admin/plugins/x/tm10.html"
names bad TM10 "skin/plugins/x/tm10-markup.html"
names bad TM11 "tm11-form.html"
names bad TM11 "tm11-novalidation.html"
names bad TM11 "tm11-tform.html"
names bad TM12 "admin/plugins/x/tm12.html"
project ownmsg
put ownmsg "$S/calendar.html" "<#list infos as info><p>\${info.message}</p></#list>"
put ownmsg src/java/fr/paris/lutece/plugins/x/web/XApp.java "public class XApp extends MVCApplication { void view( Map<String, Object> model ) { List<MVCMessage> infos = new ArrayList<>( ); infos.add( new MVCMessage( \"x\" ) ); model.put( MARK_INFOS, infos ); } }"
run ownmsg
project ownmsg-admin
put ownmsg-admin "$A/manage.html" "<#list infos as info><p>\${info.message}</p></#list>"
put ownmsg-admin src/java/fr/paris/lutece/plugins/x/web/XApp.java "public class XApp extends MVCApplication { void view( Map<String, Object> model ) { List<MVCMessage> infos = new ArrayList<>( ); infos.add( new MVCMessage( \"x\" ) ); model.put( MARK_INFOS, infos ); } }"
run ownmsg-admin
expect ownmsg-admin TM07 FAIL
expect ownmsg TM07 PASS
expect ownmsg TM13 WARN
names ownmsg TM13 "$S/calendar.html"
expect good TM13 PASS
expect jquery TM02 WARN
names jquery TM02 "webapp/js/plugins/x/x.js"
expect design-bad TM08 WARN
names design-bad TM08 "tm08.html:1 TD66"
expect design-good TM08 PASS

[ "$fails" -eq 0 ] && { echo "PASS: TM02 to TM12 fire on their defect and stay silent on the v8 form"; exit 0; }
exit 1
