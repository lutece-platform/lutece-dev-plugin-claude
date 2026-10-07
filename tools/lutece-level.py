#!/usr/bin/env python3
"""Prints the kind and the Lutece level of the Maven project holding a path: "plugin|site v8|old|unknown".

The level is read from the poms, from the nearest one up to the outermost one of the reactor: the version of a Lutece
parent (lutece-global-pom, lutece-site-pom) or of lutece-core, its ${property} resolved, the lower bound of a range.
Below 8 is "old". XML comments are ignored. Exit 0, or 1 when no pom.xml holds the path.
"""
import os
import re
import sys

LUTECE_PARENT = re.compile(r"<artifactId>\s*lutece-(?:global|site)-pom\s*</artifactId>")
CORE = re.compile(r"<dependency>(?:(?!</dependency>).)*?<artifactId>\s*lutece-core\s*</artifactId>(?:(?!</dependency>).)*?</dependency>", re.S)


def poms(path):
    """Returns the pom.xml files holding the path, nearest first, up to the outermost one of the reactor."""
    d = os.path.abspath(path if os.path.isdir(path) else os.path.dirname(path))
    found = []
    while True:
        p = os.path.join(d, "pom.xml")
        if os.path.isfile(p):
            found.append(p)
        elif found:
            break
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return found


def text(pom):
    """Returns the pom content without XML comments."""
    with open(pom, encoding="utf-8", errors="replace") as f:
        return re.sub(r"<!--.*?-->", "", f.read(), flags=re.S)


def major(version, props):
    """Returns the major number of a version, a ${property} resolved and a range reduced to its lower bound."""
    for _ in range(3):
        m = re.fullmatch(r"\$\{([^}]+)\}", version.strip())
        if not m:
            break
        version = props.get(m.group(1), "")
    m = re.match(r"\s*[\[(]?\s*(\d+)", version)
    return int(m.group(1)) if m else None


def detect(path):
    """Returns (kind, major Lutece version or None) for the project holding the path, or None without a pom."""
    chain = poms(path)
    if not chain:
        return None
    contents = [text(p) for p in chain]
    props = {}
    for c in reversed(contents):
        for block in re.findall(r"<properties>(.*?)</properties>", c, re.S):
            props.update(dict(re.findall(r"<([\w.\-]+)>\s*([^<]*?)\s*</\1>", block)))
    site = r"<packaging>\s*lutece-site\s*</packaging>|<parent>(?:(?!</parent>).)*<artifactId>\s*lutece-site-pom\s*</artifactId>"
    kind = "site" if re.search(site, contents[0], re.S) else "plugin"
    for c in contents:
        parent = re.search(r"<parent>(.*?)</parent>", c, re.S)
        if parent and LUTECE_PARENT.search(parent.group(1)):
            v = re.search(r"<version>([^<]*)</version>", parent.group(1))
            n = major(v.group(1), props) if v else None
            if n is not None:
                return kind, n
        core = CORE.search(c)
        if core:
            v = re.search(r"<version>([^<]*)</version>", core.group(0))
            n = major(v.group(1), props) if v else None
            if n is not None:
                return kind, n
    return kind, None


def major_of(path):
    """Returns the major Lutece version of the project holding the path, or None when unknown."""
    found = detect(path)
    return found[1] if found else None


def level(path):
    """Returns (kind, "old" | "v8" | "unknown") for the project holding the path, or None without a pom."""
    found = detect(path)
    if found is None:
        return None
    kind, n = found
    return kind, "unknown" if n is None else "old" if n < 8 else "v8"


if __name__ == "__main__":
    result = level(sys.argv[1] if len(sys.argv) > 1 else ".")
    if result is None:
        sys.exit(1)
    print(*result)
