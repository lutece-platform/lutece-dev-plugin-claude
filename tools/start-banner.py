#!/usr/bin/env python3
"""Prints the block a session start shows the user in a Lutece project: one line for the project and its Lutece
level, the command to run, one line with a mark per prerequisite of the machine, then the fix of each one that blocks.

Usage: start-banner.py <project_dir> <color 0|1> < doctor.sh output ("  PASS|WARN|FAIL [ENVnn] message")
Colour only when asked: the terminal renders ANSI, other surfaces print the codes as text.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
lutece_level = __import__("lutece-level")

ACCENT, DIM, RED, YELLOW = "1;38;2;30;136;229", "2", "31", "33"


def paint(text, code, color):
    """Wraps a text in an ANSI style when colour is on."""
    return "\033[%sm%s\033[0m" % (code, text) if color else text


def version():
    """The version of this lutecepowers, from its plugin manifest."""
    try:
        with open(os.path.join(HERE, "..", ".claude-plugin", "plugin.json"), encoding="utf-8") as fh:
            return json.load(fh).get("version", "")
    except (OSError, ValueError):
        return ""


def name(root):
    """The artifactId of the project, else its directory name."""
    pom = open(os.path.join(root, "pom.xml"), encoding="utf-8", errors="replace").read()
    pom = re.sub(r"<!--.*?-->|<parent>.*?</parent>", "", pom, flags=re.S)
    m = re.search(r"<artifactId>\s*([^<\s]+)\s*</artifactId>", pom)
    return m.group(1) if m else os.path.basename(root)


LABELS = {"ENV01": None, "ENV02": "path", "ENV03": "git", "ENV04": None, "ENV05": None, "ENV06": "python",
          "ENV07": "node", "ENV08": "docker"}
MARKS = {"PASS": ("✓", "32"), "WARN": ("▲", YELLOW), "FAIL": ("✗", RED)}


def prerequisites(doctor, color):
    """One line, a mark and a short name per doctor.sh check: the system, java and Maven carry their version."""
    items = []
    for status, code, message in doctor:
        label = LABELS.get(code, code.lower())
        if label is None:
            label = message.split(":")[0].split(" (")[0].lower()
            label = re.sub(r"^(java|maven) (\S+).*", r"\1 \2", label)
        mark, style = MARKS[status]
        items.append(paint(mark, style, color) + " " + (label if status != "PASS" else paint(label, DIM, color)))
    return "  ".join(items)


def lines(root, doctor, color):
    """The block: the project line, the command to run (the update below Lutece 8, else the checkup), then each blocking
    finding of the machine."""
    found = lutece_level.detect(root)
    kind, major = found if found else ("plugin", None)
    dot = paint(" · ", DIM, color)
    out = [paint("lutecepowers", ACCENT, color) + (" " + paint(version(), DIM, color) if version() else "") + dot + name(root) + dot + paint("lutece %s %s" % (major or "?", kind), DIM, color)]
    if major is not None and major < 8:
        out.append("%s below lutece 8 %s" % (paint("▲", YELLOW, color), paint("· run /lutecepowers-v8:lutece-update-%s" % kind, DIM, color)))
    else:
        out.append(paint("› run /lutecepowers-v8:lutece-checkup to check this %s" % kind, DIM, color))
    if doctor:
        out.append(prerequisites(doctor, color))
    for status, _, message in doctor:
        if status == "FAIL":
            problem, _, fix = message.partition(": ")
            out.append("%s %s%s" % (paint("✗", RED, color), problem, paint("  → " + fix, DIM, color) if fix else ""))
    return out


def main():
    """Prints the block, after a blank line that sets it apart from the hook prefix."""
    root, color = os.path.abspath(sys.argv[1]), sys.argv[2] == "1"
    doctor = [m.groups() for m in (re.match(r"^\s+(PASS|WARN|FAIL) \[(ENV\d+)\] (.*)$", l) for l in sys.stdin) if m]
    print("\n" + "\n".join(lines(root, doctor, color)), end="")


if __name__ == "__main__":
    main()
