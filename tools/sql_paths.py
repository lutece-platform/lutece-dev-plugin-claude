#!/usr/bin/env python3
"""sql_paths.py — the SQL files of a project that Liquibase runs, by the rules of SqlPathInfo (library-sql-utils).

Usage: sql_paths.py <project_dir> [--folders]

Prints, one per line and relative to the project, every non-empty file under src/sql whose path SqlPathInfo parses:
install and upgrade scripts of a plugin or module, of the core, of a theme. The lutece-maven-plugin copies only
those to the classpath where plugin-liquibase looks; any other SQL file (an archived old-upgrade/, a per-DBMS
variant) is never run. --folders prints instead every file of the folders those scripts live in, whatever its name:
the files that need the Liquibase header, a misnamed one included (SQ06 then says it is never run).
"""
import os
import re
import sys

VERSION = r"[0-9]+(?:\.[0-9]+)*"
MANAGED = [re.compile(p) for p in (
    r"sql/plugins/[\w\-]+(?:/modules/[\w]+)?/(?:core|plugin)/(?:init|create)[\w\-]+\.sql",
    r"sql/plugins/[\w\-]+(?:/modules/[\w]+)?/upgrades?/(?:update|upgrade)[\w\-]+?[\-_]?" + VERSION + r"[\-_]" + VERSION + r"\.sql",
    r"sql/(?:init|create)[A-Za-z_]+core\.sql",
    r"sql/upgrade/update_db_lutece_core-" + VERSION + "-" + VERSION + r"\.sql",
    r"sql/themes/[\w]+/(?:init|create)[\w\-]*\.sql",
    r"sql/themes/[\w]+/upgrade/(?:update|upgrade)[\w\-]+?[\-_]?" + VERSION + r"[\-_]" + VERSION + r"\.sql",
)]
"""The patterns of fr.paris.lutece.utils.sql.SqlPathInfo, applied to the path from src/."""


FOLDERS = re.compile(r"sql/(?:plugins/[\w\-]+(?:/modules/[\w]+)?/(?:core|plugin|upgrades?)|themes/[\w]+(?:/upgrade)?|upgrade)?/?[^/]+\.sql")
"""The folders SqlPathInfo reads, from the path under src/."""


def managed(rel):
    """Tells whether a path relative to src/ is one Liquibase runs."""
    return any(p.fullmatch(rel) for p in MANAGED)


def main():
    """Prints the Liquibase-managed SQL files of the project given, or every file of their folders with --folders."""
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = args[0] if args else "."
    src = os.path.join(root, "src")
    for dirpath, _, names in os.walk(os.path.join(src, "sql")):
        for n in sorted(names):
            p = os.path.join(dirpath, n)
            rel = os.path.relpath(p, src).replace(os.sep, "/")
            keep = FOLDERS.fullmatch(rel) if "--folders" in sys.argv else managed(rel)
            if n.endswith(".sql") and os.path.getsize(p) > 0 and keep:
                print(os.path.relpath(p, root).replace(os.sep, "/"))


if __name__ == "__main__":
    main()
