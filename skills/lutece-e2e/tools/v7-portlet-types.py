#!/usr/bin/env python3
"""v7-portlet-types.py — the SQL a Lutece 7 plugin installation runs for its portlet types.

Usage: v7-portlet-types.py <v7 exploded webapp>

A v7 site installs a plugin from the admin: Plugin.install( ) calls registerPortlets( ), which replaces the
core_portlet_type row of every <portlets>/<portlet> of the plugin descriptor that names a portlet-class. The v7 site of
lpe2e upgrade enables its plugins through plugins.dat, which only runs init( ): those rows are missing and the v7 base
taken over by the bench site lacks portlet types a real site has. Prints, for each plugin enabled in plugins.dat, the DELETE
and INSERT that registerPortlets( ) runs, with the columns of the v7 PortletTypeDAO.
"""
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

COLUMNS = [("id_portlet_type", "portlet-type-id"), ("name", "portlet-type-name"), ("url_creation", "portlet-creation-url"),
           ("url_update", "portlet-update-url"), ("home_class", "portlet-class"), ("plugin_name", None),
           ("url_docreate", "portlet-create-action-url"), ("create_script", "portlet-create-script-template"),
           ("create_specific", "portlet-create-specific-template"),
           ("create_specific_form", "portlet-create-specific-form-template"),
           ("url_domodify", "portlet-modify-action-url"), ("modify_script", "portlet-modify-script-template"),
           ("modify_specific", "portlet-modify-specific-template"),
           ("modify_specific_form", "portlet-modify-specific-form-template")]


def sql(value):
    """A SQL literal: NULL for a missing value, a quoted string otherwise."""
    return "NULL" if value is None else "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def enabled(webapp):
    """Names of the plugins plugins.dat marks installed."""
    try:
        text = open(os.path.join(webapp, "WEB-INF", "plugins", "plugins.dat"), errors="replace").read()
    except OSError:
        return set()
    return set(re.findall(r"(?m)^\s*([\w.-]+)\.installed\s*=\s*1\s*$", text))


def statements(webapp):
    """The DELETE and INSERT of every portlet type of the enabled plugins."""
    names = enabled(webapp)
    out = []
    for path in sorted(glob.glob(os.path.join(webapp, "WEB-INF", "plugins", "*.xml"))):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        plugin = (root.findtext("name") or "").strip()
        if plugin not in names:
            continue
        for p in root.findall("portlets/portlet"):
            values = {tag: (p.findtext(tag) or "").strip() or None for _, tag in COLUMNS if tag}
            if not values["portlet-type-id"] or not values["portlet-class"]:
                continue
            row = [plugin if tag is None else values[tag] for _, tag in COLUMNS]
            out.append("DELETE FROM core_portlet_type WHERE id_portlet_type = %s;" % sql(values["portlet-type-id"]))
            out.append("INSERT INTO core_portlet_type ( %s ) VALUES ( %s );"
                       % (", ".join(c for c, _ in COLUMNS), ", ".join(sql(v) for v in row)))
    return out


def main():
    """Prints the portlet type statements of a v7 webapp."""
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    print("\n".join(statements(sys.argv[1])))


if __name__ == "__main__":
    main()
