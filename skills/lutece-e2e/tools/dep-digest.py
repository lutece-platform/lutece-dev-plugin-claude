#!/usr/bin/env python3
"""dep-digest.py — prints a digest of the content of the Lutece dependencies an assembled site carries.

Usage: dep-digest.py <site_dir> [<own_artifact_id>]

For every jar of <site_dir>/WEB-INF/lib that the local Maven repository holds under fr/paris/lutece, the digest takes
the content of that repository copy and of its -webapp.zip beside it (what the assembly lays into the webapp). A
dependency rebuilt and installed locally changes the digest whatever the dates of its files, so a cached site or a
bench build that still carries the old one is seen as stale. The artefact under test is left out: it is rebuilt on
every run. Jars the repository does not hold under fr/paris/lutece are left out too.
"""
import hashlib
import os
import pathlib
import sys


def digest(site, own=None):
    """The digest of the repository copies of the site's Lutece jars, the artefact `own` left out."""
    repo = pathlib.Path(os.environ.get("M2_REPO", pathlib.Path.home() / ".m2" / "repository")) / "fr" / "paris" / "lutece"
    libs = sorted(p.name for p in (pathlib.Path(site) / "WEB-INF" / "lib").glob("*.jar"))
    if own:
        libs = [n for n in libs if not n.startswith(own + "-")]
    index = {p.name: p for p in repo.rglob("*.jar")} if repo.is_dir() and libs else {}
    h = hashlib.sha1()
    for name in libs:
        jar = index.get(name)
        if jar is None:
            continue
        for f in (jar, jar.with_name(jar.name[:-4] + "-webapp.zip")):
            if f.is_file():
                h.update(f.name.encode() + b"\0" + hashlib.sha1(f.read_bytes()).digest())
    return h.hexdigest()[:16]


def main():
    """Prints the digest of the site given on the command line."""
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        sys.exit(2)
    print(digest(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))


if __name__ == "__main__":
    main()
