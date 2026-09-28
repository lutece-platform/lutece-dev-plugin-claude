#!/usr/bin/env python3
"""source-key.py — prints a short key of everything a verdict on a project depends on.

Usage: source-key.py <project_dir> [<toolkit_dir> ...]

The key covers the project's files (the e2e bench's hand-written files included), the toolkit directories given
(the scripts that judge it), and the Lutece artefacts of the local Maven repository other than the project's own:
those the last assembled bench site carries in WEB-INF/lib, every one when no site was assembled yet.
Build output, bench artifacts and generated sites are left out, so two builds of the same sources give the same key.
"""
import hashlib
import os
import pathlib
import re
import sys

SKIP_DIRS = {".git", "target", "node_modules", "__pycache__", ".migration", "logs", "java.io.tmpdir", ".run.lock",
             ".pytest_cache"}
SKIP_PATHS = ("e2e/artifacts", "e2e/harness/site/target", "e2e/harness/site7", "e2e/harness/src7")


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


def site_artifacts(project):
    """The artifactIds of the jars the last assembled bench site carries, None when no site was assembled."""
    libs = list((pathlib.Path(project) / "e2e" / "harness" / "site" / "target").glob("*/WEB-INF/lib/*.jar"))
    if not libs:
        return None
    return {re.sub(r"-\d[^/]*\.jar$", "", p.name) for p in libs}


def maven_lutece(h, own, used):
    """Feeds path, size and time of the Lutece jars of the local repository the site uses, the project's own left out."""
    repo = pathlib.Path(os.environ.get("M2_REPO", pathlib.Path.home() / ".m2" / "repository")) / "fr" / "paris" / "lutece"
    if not repo.is_dir():
        return
    for p in sorted(repo.rglob("*")):
        if p.suffix in (".jar", ".zip") and not (own and "/%s/" % own in p.as_posix()) \
                and (used is None or p.parent.parent.name in used):
            st = p.stat()
            h.update(("%s %d %d" % (p.relative_to(repo).as_posix(), st.st_size, int(st.st_mtime))).encode())


def main():
    """Prints the key of the project and toolkit directories given on the command line."""
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        sys.exit(2)
    h = hashlib.sha256()
    for d in sys.argv[1:]:
        walk(d, h)
    maven_lutece(h, own_artifact(sys.argv[1]), site_artifacts(sys.argv[1]))
    print(h.hexdigest()[:16])


if __name__ == "__main__":
    main()
