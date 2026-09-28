#!/usr/bin/env bash
# Checks JP05, JP06, JS02, JS03, JS05, JS06, VL01, WB05 and WB06 both ways: the defect's shape fires the check, the v8
# form, a longer name or a legit neighbour of the defect does not.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
V="${VERIFY:-$HERE/../../tools/verify-migration.sh}"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0

# Writes one fixture file: $1 fixture, $2 relative path, $3 content printed with printf.
put() {
    mkdir -p "$T/$1/$(dirname "$2")"
    printf -- "$3" > "$T/$1/$2"
}

# Prints a descriptor with one admin feature, $1 being its group element.
feature() { printf '<plug-in><admin-features><admin-feature><feature-id>MY_MANAGEMENT</feature-id>%s<feature-url>jsp/admin/plugins/myplugin/ManageMyEntities.jsp</feature-url></admin-feature></admin-features></plug-in>\\n' "$1"; }

# Prints the status of one check on a fixture directory.
status() {
    ( cd "$T/$1" && bash "$V" . 2>/dev/null ) | sed 's/\x1b\[[0-9;]*m//g' | grep -oE "(PASS|FAIL|WARN) \[$2\]" | head -1 | cut -d' ' -f1
}

# Records a failure when a check does not answer the expected status.
expect() {
    local got; got=$(status "$1" "$2")
    [ "$got" = "$3" ] || { echo "FAIL: $2 on $1 expected $3, got ${got:-nothing}"; fails=$((fails + 1)); }
}

D=src/java/x/MyEntityDAO.java
put jp5-bad "$D" 'class MyEntityDAO\n{\n    void f( ) { em.createNativeQuery( "SELECT * FROM my_entity WHERE id_entity = :id" ); }\n}\n'
put jp5-ok "$D" 'class MyEntityDAO\n{\n    static final String Q = "SELECT e FROM MyEntity e WHERE e.id = :id";\n    static final String URL = "http://host:8080/x";\n    void f( ) { em.createNativeQuery( "SELECT CAST( code AS text ), label::text FROM my_entity WHERE id_entity = ?1" ); }\n}\n'
put jp5-jpql "$D" 'class MyEntityDAO\n{\n    void f( ) { em.createQuery( "SELECT e FROM e WHERE e.id = :id" ); }\n}\n'
expect jp5-bad JP05 WARN
expect jp5-ok JP05 PASS
expect jp5-jpql JP05 PASS

PX=src/main/resources/META-INF/persistence.xml
put jp6-bad "$PX" '<persistence version="3.0"><persistence-unit name="my"><class>x.MyEntity</class></persistence-unit></persistence>\n'
put jp6-ok "$PX" '<persistence version="3.0"><persistence-unit name="my"><class>x.MyEntity</class><shared-cache-mode>NONE</shared-cache-mode></persistence-unit></persistence>\n'
put jp6-none src/java/x/A.java 'class A { }\n'
expect jp6-bad JP06 WARN
expect jp6-ok JP06 PASS
expect jp6-none JP06 PASS
put jp6-cmt "$PX" '<persistence version="3.0"><persistence-unit name="my"><!-- <shared-cache-mode>NONE</shared-cache-mode> --></persistence-unit></persistence>\n'
put jp6-prop "$PX" '<persistence version="3.0"><persistence-unit name="my"><properties><property name="eclipselink.cache.shared.default" value="false"/></properties></persistence-unit></persistence>\n'
expect jp6-cmt JP06 WARN
expect jp6-prop JP06 PASS

J=webapp/jsp/admin/plugins/myplugin/ManageMyEntities.jsp
ENTRY='<%%@ page errorPage="../../ErrorPage.jsp" %%>\n<%%-- entry point --%%>\n<jsp:include page="../../AdminHeader.jsp" />\n${ myEntityJspBean.init( pageContext.request, MyEntityJspBean.RIGHT_MANAGE_MY_ENTITIES ) }\n${ myEntityJspBean.processController( pageContext.request, pageContext.response ) }\n<pre></pre>\n<%%@ include file="../../AdminFooter.jsp" %%>\n'
put js-ok "$J" "$ENTRY"
put js2-bad "$J" '<%%@ page errorPage="../../ErrorPage.jsp" %%>\n<%%= myEntityJspBean.getManage( request ) %%>\n'
put js3-bad "$J" '<%%@ page errorPage="../../ErrorPage.jsp" %%>\n${ MyEntityJspBean.processController( pageContext.request, pageContext.response ) }\n'
put js5-bad "$J" '<%%@ page errorPage="../../ErrorPage.jsp" %%>\n<div class="card">${ myEntityJspBean.processController( pageContext.request, pageContext.response ) }</div>\n'
put js5-site webapp/jsp/site/plugins/myplugin/MyPage.jsp '<%%@ page errorPage="../../ErrorPagePortal.jsp" %%>\n<div class="page">${ myPortalBean.getContent( pageContext.request ) }</div>\n'
expect js-ok JS02 PASS
expect js2-bad JS02 FAIL
expect js-ok JS03 PASS
expect js3-bad JS03 FAIL
expect js-ok JS05 PASS
expect js5-bad JS05 FAIL
expect js5-site JS05 PASS
put js2-eol "$J" '<%%@ page import="fr.paris.lutece.portal.web.LocalVariables" %%>\n<%%\n    LocalVariables.setLocal( config, request, response );\n%%>\n'
put js2-cmt "$J" '<%%@ page errorPage="../../ErrorPage.jsp" %%>\n<%%--\n    entry point\n--%%>\n${ myEntityJspBean.processController( pageContext.request, pageContext.response ) }\n'
put js5-cmt "$J" '<%%@ page errorPage="../../ErrorPage.jsp" %%>\n<%%-- <div class="card"> moved to the template --%%>\n${ myEntityJspBean.processController( pageContext.request, pageContext.response ) }\n'
put js5-eol "$J" '<%%@ page errorPage="../../ErrorPage.jsp" %%>\n<div\n    class="card"></div>\n'
expect js2-eol JS02 FAIL
expect js2-cmt JS02 PASS
expect js5-cmt JS05 PASS
expect js5-eol JS05 FAIL

DL=webapp/jsp/admin/plugins/myplugin/DoDownloadMyFile.jsp
put js6-ok "$DL" '<%%@ page errorPage="../../ErrorPage.jsp" %%><%%--\n--%%>${ myFileJspBean.doDownloadFile( pageContext.request, pageContext.response ) }'
put js6-nl "$DL" '<%%@ page errorPage="../../ErrorPage.jsp" %%>\n\n${ myFileJspBean.doDownloadFile( pageContext.request, pageContext.response ) }\n'
put js6-text "$DL" '<%%@ page errorPage="../../ErrorPage.jsp" %%>${ myFileJspBean.doExportCsv( pageContext.request, pageContext.response ) }done'
put js6-page "$J" "$ENTRY"
expect js6-ok JS06 PASS
expect js6-nl JS06 FAIL
expect js6-text JS06 FAIL
expect js6-page JS06 PASS
put js6-list "$J" '<%%@ page errorPage="../../ErrorPage.jsp" %%>\n<jsp:include page="../../AdminHeader.jsp" />\n${ myFileJspBean.getFileList( pageContext.request ) }\n<%%@ include file="../../AdminFooter.jsp" %%>\n'
put js6-scriptlet webapp/jsp/site/plugins/myplugin/DoDownloadMyFile.jsp '<%%@ page import="x.MyDownload" %%><%% MyDownload.doDownloadFile( request, response ); %%>'
expect js6-list JS06 PASS
expect js6-scriptlet JS06 PASS

put vl-ok webapp/js/plugins/myplugin/app.js 'document.querySelectorAll( ".x" ).forEach( e => e.remove( ) );\n$.fn.dataTable.ext.errMode = "none";\n'
put vl-ok webapp/WEB-INF/lib-js/jquery.min.js '/* outside the served tree */\n'
put vl-ok webapp/js/plugins/myplugin/jquery-helpers.css '.x { }\n'
put vl-plugin webapp/js/plugins/myplugin/widget.js '$.fn.myWidget = function( ) { return this; };\n'
expect vl-ok VL01 PASS
expect vl-plugin VL01 FAIL
put vl-lib webapp/js/jquery/jquery-3.4.1.min.js '/*! jQuery v3.4.1 */\n'
put vl-slim webapp/js/jquery.slim.min.js '!function(e,t){};S.fn.extend({a:1});\n'
put vl-upload webapp/js/plugins/myplugin/plupload/plupload.full.min.js '/* plupload */\n'
expect vl-lib VL01 FAIL
expect vl-slim VL01 FAIL
expect vl-upload VL01 FAIL

PL=webapp/WEB-INF/plugins/myplugin.xml
put wb5-ok "$PL" '<plug-in><filters><filter><filter-name>a</filter-name><url-pattern>/rest/*</url-pattern><filter-class>x.A</filter-class></filter><filter><filter-name>b</filter-name><url-pattern>/jsp/site/plugins/myplugin/*</url-pattern><filter-class>x.B</filter-class></filter></filters></plug-in>\n'
put wb5-bad "$PL" '<plug-in><filters><filter><filter-name>a</filter-name><url-pattern>/rest/myplugin/*</url-pattern><filter-class>x.A</filter-class></filter></filters></plug-in>\n'
expect wb5-ok WB05 PASS
expect wb5-bad WB05 FAIL
put wb5-cmt "$PL" '<plug-in>\n<!-- <filters><filter><filter-name>a</filter-name><url-pattern>/rest/myplugin/*</url-pattern><filter-class>x.A</filter-class></filter></filters> -->\n</plug-in>\n'
expect wb5-cmt WB05 PASS

SQL=src/sql/plugins/myplugin/core/init_core_myplugin.sql
COLS='INSERT INTO core_admin_right (id_right,name,level_right,admin_url,description,is_updatable,plugin_name,id_feature_group,icon_url,documentation_url,id_order,is_external_feature)'
for k in wb6-ok wb6-moved wb6-missing wb6-null; do put "$k" "$SQL" "$COLS VALUES ('MY_MANAGEMENT','myplugin.adminFeature.name',2,'jsp/admin/plugins/myplugin/ManageMyEntities.jsp','myplugin.adminFeature.description',0,'myplugin','CONTENT',NULL,NULL,4,0);\n"; done
put wb6-null "$SQL" "$COLS VALUES ('MY_MANAGEMENT','myplugin.adminFeature.name',2,'jsp/admin/plugins/myplugin/ManageMyEntities.jsp','myplugin.adminFeature.description',0,'myplugin',NULL,NULL,NULL,4,0);\n"
put wb6-ok src/sql/plugins/myplugin/upgrade/update_db_myplugin-1.0.0-2.0.0.sql "$COLS VALUES ('MY_MANAGEMENT','n',2,'u','d',0,'myplugin','SYSTEM',NULL,NULL,4,0);\n"
put wb6-ok "$PL" "$(feature '<feature-group>CONTENT</feature-group>')"
put wb6-moved "$PL" "$(feature '<feature-group>SYSTEM</feature-group>')"
put wb6-missing "$PL" "$(feature '')"
put wb6-null "$PL" "$(feature '')"
expect wb6-ok WB06 PASS
expect wb6-moved WB06 FAIL
expect wb6-missing WB06 FAIL
expect wb6-null WB06 PASS
put wb6-sqlcmt "$SQL" "-- $COLS VALUES ('MY_MANAGEMENT','n',2,'u','d',0,'myplugin','SYSTEM',NULL,NULL,4,0);\n/* $COLS VALUES ('MY_MANAGEMENT','n',2,'u','d',0,'myplugin','SYSTEM',NULL,NULL,4,0); */\n$COLS VALUES ('MY_MANAGEMENT','it''s',2,'u','d',0,'myplugin','CONTENT',NULL,NULL,4,0);\n"
put wb6-sqlcmt "$PL" "$(feature '<feature-group>CONTENT</feature-group>')"
put wb6-multi "$SQL" "$COLS VALUES ('OTHER_MANAGEMENT','n',2,'u','d',0,'myplugin','SYSTEM',NULL,NULL,5,0),\n('MY_MANAGEMENT','n',2,'u','d',0,'myplugin','CONTENT',NULL,NULL,4,0);\n"
put wb6-multi "$PL" "$(feature '<feature-group>SYSTEM</feature-group>')"
put wb6-xmlcmt "$SQL" "$COLS VALUES ('MY_MANAGEMENT','n',2,'u','d',0,'myplugin','CONTENT',NULL,NULL,4,0);\n"
put wb6-xmlcmt "$PL" '<plug-in><admin-features><!-- <admin-feature><feature-id>MY_MANAGEMENT</feature-id><feature-group>SYSTEM</feature-group></admin-feature> --><admin-feature><feature-id>MY_MANAGEMENT</feature-id><feature-group>CONTENT</feature-group></admin-feature></admin-features></plug-in>\n'
expect wb6-sqlcmt WB06 PASS
expect wb6-multi WB06 FAIL
expect wb6-xmlcmt WB06 PASS

[ "$fails" -eq 0 ] && { echo "PASS: JP05 reads native SQL only, JP06 wants shared-cache-mode or eclipselink.cache.shared.default outside comments, JS02 spares directives and JSP comments and sees a scriptlet opened at the end of a line, JS03 spares the bean name and static fields, JS05 reads admin JSPs only, outside JSP comments, a tag at the end of a line included, JS06 wants a glued download JSP and spares getFileList pages and glued scriptlets, VL01 finds vendored jQuery, slim included, jQuery plugins and upload widgets and spares a $.fn reader, WB05 spares /rest/* and comments, WB06 compares the descriptor group with the install SQL, comments left out, multi-row VALUES read"; exit 0; }
exit 1
