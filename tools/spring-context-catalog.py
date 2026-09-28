#!/usr/bin/env python3
"""spring-context-catalog.py — lists the Spring beans of a Lutece project as JSON, read-only.

Usage: spring-context-catalog.py [project_root]

Reads every webapp/WEB-INF/conf/**/*_context.xml and the files they import, and prints the bean catalog: id, class,
scope, constructorArgs, properties, refs, needsProducer, sourceFile. needsProducer is true when the class cannot simply
be annotated (constructor arguments, literal or inner-bean properties, a factory, a class outside the project).
Changes nothing; a project without a Spring context gets an empty catalog.
"""
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

CLASS_DECL = re.compile(r"(?m)^(?P<indent>[ \t]*)(?:@\w+(?:\([^()]*\))?[ \t]+)*(?P<mods>(?:(?:public|protected|private|abstract|final|static)\s+)*)"
                        r"(?P<kind>class|interface|enum)\s+(?P<name>\w+)(?P<generics><[^{]*?>)?"
                        r"(?P<rest>[^{;]*)\{")
ALIASES = {}


def local(tag):
    """Returns an XML tag name without its namespace."""
    return tag.rsplit("}", 1)[-1]


def parse_contexts(root):
    """Reads every *_context.xml under webapp/WEB-INF/conf and the files they import, returns (beans, files)."""
    beans, files = [], []
    conf = os.path.join(root, "webapp", "WEB-INF", "conf")
    queue = [os.path.join(d, n) for d, _, ns in os.walk(conf) for n in sorted(ns) if n.endswith("_context.xml")]
    while queue:
        path = os.path.normpath(queue.pop(0))
        if path in files:
            continue
        files.append(path)
        try:
            tree = ET.parse(path)
        except ET.ParseError as e:
            beans.append({"error": f"{path}: {e}"})
            continue
        containers = [tree.getroot()]
        while containers:
            for el in containers.pop(0):
                tag = local(el.tag)
                if tag == "beans":
                    containers.append(el)
                elif tag == "bean" and (el.get("id") or el.get("name")):
                    beans.append(read_bean(el, path))
                elif tag == "alias" and el.get("name") and el.get("alias"):
                    ALIASES[el.get("alias")] = el.get("name")
                elif tag == "import" and el.get("resource") and ":" not in el.get("resource"):
                    imported = os.path.join(os.path.dirname(path), el.get("resource"))
                    if os.path.isfile(imported):
                        queue.append(imported)
    return beans, files


def read_bean(el, path):
    """Turns one <bean> element into a dict: id, class, scope, lifecycle methods, properties, constructor args."""
    props, args = [], []
    for child in el:
        name = local(child.tag)
        if name == "property":
            props.append(read_value(child) | {"name": child.get("name")})
        elif name == "constructor-arg":
            args.append(read_value(child))
    names = [n for n in re.split(r"[,;\s]+", el.get("name") or "") if n]
    ident = el.get("id") or names[0]
    for n in names:
        if n != ident:
            ALIASES[n] = ident
    return {"id": ident, "class": el.get("class"), "scope": el.get("scope", "singleton"),
            "abstract": el.get("abstract") == "true", "parent": el.get("parent"),
            "factory": el.get("factory-method") or el.get("factory-bean"),
            "init": el.get("init-method"), "destroy": el.get("destroy-method"),
            "properties": props, "args": args, "file": path}


def read_value(el):
    """Describes the value of a property or constructor-arg: a literal, a single ref, or a collection."""
    if el.get("ref"):
        return {"kind": "ref", "ref": el.get("ref")}
    if el.get("value") is not None:
        return {"kind": "value", "value": el.get("value")}
    for child in el:
        name = local(child.tag)
        if name == "ref":
            return {"kind": "ref", "ref": child.get("bean") or child.get("local")}
        if name == "value":
            return {"kind": "value", "value": (child.text or "").strip()}
        if name in ("list", "set", "map", "props", "array"):
            refs = [c.get("bean") or c.get("local") for c in child.iter() if local(c.tag) == "ref"]
            return {"kind": name, "refs": refs}
        if name == "bean":
            return {"kind": "inner-bean", "class": child.get("class")}
    return {"kind": "unknown"}


def java_files(root):
    """Lists the main Java sources of the project (src/java or src/main/java), tests excluded."""
    out = []
    for base in ("src/java", "src/main/java"):
        top = os.path.join(root, base)
        for dirpath, dirs, names in os.walk(top):
            dirs[:] = [d for d in dirs if d != "test"]
            out.extend(os.path.join(dirpath, n) for n in names if n.endswith(".java"))
    return sorted(out)


def read(path):
    """Reads a text file, keeping its line endings."""
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as fh:
        return fh.read()


def index_classes(files):
    """Maps each fully qualified class name of the project to its file, name, kind and direct supertypes."""
    idx = {}
    for f in files:
        text = read(f)
        pkg = re.search(r"(?m)^package\s+([\w.]+)\s*;", text)
        m = CLASS_DECL.search(strip_comments(text))
        if not pkg or not m:
            continue
        rest = " ".join(m.group("rest").split())
        supers = []
        ext = re.search(r"\bextends\s+([\w.<>, ]+?)(?:\bimplements\b|$)", rest)
        imp = re.search(r"\bimplements\s+([\w.<>, ]+)", rest)
        for grp in (ext, imp):
            if grp:
                supers += [re.sub(r"<.*", "", s).strip().split(".")[-1] for s in split_types(grp.group(1))]
        idx[f"{pkg.group(1)}.{m.group('name')}"] = {"file": f, "name": m.group("name"), "kind": m.group("kind"),
                                                   "abstract": "abstract" in m.group("mods"),
                                                   "extends": re.sub(r"<.*", "", ext.group(1)).strip().split(".")[-1]
                                                   if ext else None,
                                                   "supers": [s for s in supers if s]}
    return idx


def split_types(s):
    """Splits a comma separated type list, ignoring commas inside generics."""
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return [t.strip() for t in out if t.strip()]


def strip_comments(text):
    """Blanks Java comments and string contents, keeping offsets, so that regexes see only code."""
    def blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))
    return re.sub(r"/\*.*?\*/|//[^\n]*|\"(?:\\.|[^\"\\\n])*\"", lambda m: blank(m) if not m.group(0).startswith('"')
                  else '"' + " " * (len(m.group(0)) - 2) + '"', text, flags=re.S)


def producer_reason(bean):
    """Tells why a bean must be built by a @Produces method rather than annotated: None when it can be annotated."""
    if bean["args"]:
        return f"{len(bean['args'])} constructor-arg"
    for p in bean["properties"]:
        if p["kind"] in ("value", "inner-bean", "unknown") or p["kind"] in ("list", "set", "array") and not p["refs"]:
            return f"property {p['name']} holds a {p['kind']}"
    return None


def catalog(root, beans, ctx_files, idx):
    """Builds the JSON catalog of the Spring beans that the Java step of the migration reads."""
    out = []
    for b in beans:
        refs = sorted({v["ref"] for v in b["properties"] + b["args"] if v.get("ref")} |
                      {r for v in b["properties"] + b["args"] for r in v.get("refs", []) if r})
        out.append({"id": b["id"], "class": b["class"], "scope": b["scope"], "constructorArgs": b["args"],
                    "properties": b["properties"], "refs": refs,
                    "needsProducer": bool(producer_reason(b) or b["factory"] or b["class"] not in idx),
                    "sourceFile": os.path.relpath(b["file"], root)})
    return {"beans": out, "files": [os.path.relpath(f, root) for f in ctx_files]}


def main():
    """Prints the bean catalog of one project."""
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = os.path.abspath(args[0] if args else ".")
    beans, ctx_files = parse_contexts(root)
    beans = [b for b in beans if "error" not in b]
    print(json.dumps(catalog(root, beans, ctx_files, index_classes(java_files(root))), indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
