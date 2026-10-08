#!/usr/bin/env python3
"""source-key.py — prints a short key of everything a verdict on a project depends on.

Usage: source-key.py <project_dir> [<toolkit_dir> ...]

The key covers the project's files (the e2e bench's hand-written files included), the toolkit directories given
(the scripts that judge it), and the content of the local Maven repository copies of the Lutece jars the bench site
carries in WEB-INF/lib (exact names and versions, tools/dep-digest.py), the project's own left out. Any other artefact,
or another version of a carried one, installed or downloaded by any build leaves the key; without an assembled site
the local repository does not enter it.
Build output, bench artifacts and generated sites are left out, so two builds of the same sources give the same key.
"""
import hashlib
import importlib.util
import os
import pathlib
import re
import sys

SKIP_DIRS = {".git", "target", "node_modules", "__pycache__", ".migration", "logs", "java.io.tmpdir", ".run.lock",
             ".pytest_cache"}
SKIP_PATHS = ("e2e/artifacts", "e2e/harness/site/target")


def walk(root, h):
    """Feeds the relative path and bytes of every file under root, generated trees left out."""
    root = pathlib.Path(root)
    for dirpath, dirs, files in os.walk(root):
        rel = pathlib.Path(dirpath).relative_to(root).as_posix()
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS
                         and not ("%s/%s" % (rel, d)).lstrip("./").startswith(SKIP_PATHS))
        for f in sorted(files):
            p = pathlib.Path(dirpath) / f
            h.update(p.relative_to(root).as_posix().encode())
            try:
                h.update(p.read_bytes())
            except OSError:
                pass


def own_artifact(project):
    """The project's artifactId: the second one of its pom, after the parent's."""
    try:
        ids = re.findall(r"<artifactId>([^<]+)</artifactId>", (pathlib.Path(project) / "pom.xml").read_text(errors="replace"))
    except OSError:
        return None
    return ids[1] if len(ids) > 1 else None


def bench_site(project):
    """The site the project's bench assembled: LPE2E_SITE, else the state of the bench e2e/e2e.conf names; None when
    there is none."""
    site = os.environ.get("LPE2E_SITE")
    if not site:
        try:
            conf = (pathlib.Path(project) / "e2e" / "e2e.conf").read_text(errors="replace")
        except OSError:
            return None
        m = re.search(r"^E2E_NAME=[\"']?([^\"'\s]+)", conf, re.M)
        if not m:
            return None
        home = os.environ.get("LUTECEPOWERS_E2E_HOME") or str(pathlib.Path.home() / ".lutecepowers-e2e")
        site = os.path.join(home, "benches", m.group(1), "site")
    return pathlib.Path(site) if (pathlib.Path(site) / "WEB-INF" / "lib").is_dir() else None


def carried_jars(h, project):
    """Feeds the digest of the local repository copies of exactly the Lutece jars the bench site carries
    (tools/dep-digest.py), the project's own left out; nothing when no site was assembled."""
    site = bench_site(project)
    if site is None:
        return
    spec = importlib.util.spec_from_file_location("dep_digest", pathlib.Path(__file__).with_name("dep-digest.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    h.update(mod.digest(site, own_artifact(project)).encode())


def main():
    """Prints the key of the project and toolkit directories given on the command line."""
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        sys.exit(2)
    h = hashlib.sha256()
    for d in sys.argv[1:]:
        walk(d, h)
    carried_jars(h, sys.argv[1])
    print(h.hexdigest()[:16])


if __name__ == "__main__":
    main()
