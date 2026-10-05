#!/bin/sh
# First start of this container: create the schema the v7 way, with the Ant build assembled under WEB-INF/sql
# (`ant all` = core scripts, then every plugin's create/init scripts). A marker keeps a `docker restart` from
# running it again — `drop_and_create_db` is the first thing that build does. With the argument `init`, the container
# stops once the schema is created, before Tomcat starts.
set -eu
APP=/usr/local/tomcat/webapps/${E2E_CONTEXT:-lutece}
MARK=/usr/local/tomcat/.dbinit-done
if [ "${E2E_V7_INIT_DB:-1}" = 1 ] && [ ! -f "$MARK" ]; then
  JAR=$(ls "$APP"/WEB-INF/lib/mysql-connector-*.jar 2>/dev/null | head -1)
  echo ">> v7 schema: ant all (connector: ${JAR:-none})"
  ( cd "$APP/WEB-INF/sql" && ant -q -f build.xml all -Dmysql.connector.jar.path="$JAR" ) 2>&1 | tee /logs/ant-dbinit.log
  DBP="$APP/WEB-INF/conf/db.properties"
  prop() { sed -n "s/^portal\.$1=//p" "$DBP" | head -1; }
  # Runs the SQL files of a directory of the war matching the Ant patterns given, errors ignored.
  run_sql() {
    cat > /tmp/run-sql.xml <<XML
<project name="replay" default="replay">
  <target name="replay">
    <sql driver="$(prop driver)" url="$(prop url | sed 's/&/\&amp;/g')" userid="$(prop user)" password="$(prop password)"
         autocommit="true" onerror="continue" encoding="UTF-8">
      <fileset dir="$1" includes="$2"/>
      <classpath><fileset dir="$APP/WEB-INF/lib" includes="mysql-connector-*.jar"/></classpath>
    </sql>
  </target>
</project>
XML
    ant -q -f /tmp/run-sql.xml 2>&1 | grep -v "Failed to execute\|Duplicate entry\|SQLIntegrityConstraintViolation" | tee -a /logs/ant-dbinit.log
  }
  # `ant all` runs the plugins in alphabetical order, core scripts first: a plugin whose init fills a table another
  # plugin creates later (a plugin's rows in a table of a plugin sorted after it) loses those rows,
  # which a real v7 site installed over the years does carry. Replay the init scripts once every table exists;
  # the rows already there fail on their key and change nothing.
  if grep -q "doesn't exist" /logs/ant-dbinit.log; then
    echo ">> v7 schema: init scripts replayed once every plugin table exists"
    run_sql "$APP/WEB-INF/sql/plugins" "*/core/init*.sql,*/plugin/init*.sql"
  fi
  # `ant all` has no target for a theme's scripts, which a v7 site applied when it installed the theme: without its
  # datastore keys the v7 front office fails on the first one its templates read.
  if ls "$APP"/WEB-INF/sql/themes/*/*.sql >/dev/null 2>&1; then
    echo ">> v7 schema: theme scripts ($(ls -d "$APP"/WEB-INF/sql/themes/*/ | xargs -n1 basename | tr '\n' ' '))"
    run_sql "$APP/WEB-INF/sql/themes" "*/create*.sql,*/init*.sql"
  fi
  touch "$MARK"
fi
[ "${1:-}" != init ] || exit 0
exec catalina.sh run
