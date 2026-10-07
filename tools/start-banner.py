#!/usr/bin/env python3
"""Prints the block a session start shows the user in a Lutece project: lutecepowers and whether it is up to date, the
project and its Lutece level, what the machine lacks (with the command that fixes it), then the command to run.

Usage: start-banner.py <project_dir> <color 0|1> < doctor.sh output ("  PASS|WARN|FAIL [ENVnn] problem: fix")
Colour only when asked: the terminal renders ANSI, other surfaces print the codes as text.
"""
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
lutece_level = __import__("lutece-level")

ACCENT, DIM, BOLD, RED, YELLOW = "1;38;2;30;136;229", "2", "1", "31", "33"
LATEST_URL = "https://raw.githubusercontent.com/lutece-platform/lutece-dev-plugin-lutecepowers/main/.claude-plugin/plugin.json"


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


def latest():
    """The version published on the main branch, "" when it cannot be read within three seconds."""
    try:
        with urllib.request.urlopen(LATEST_URL, timeout=3) as r:
            return json.load(r).get("version", "")
    except (OSError, ValueError):
        return ""


def numbers(v):
    """A version as a tuple of numbers, for comparison."""
    return tuple(int(n) for n in re.findall(r"\d+", v)[:3])


def tool_line(color):
    """lutecepowers, its version, and whether a newer one is published."""
    mine, last = version(), latest()
    line = paint("lutecepowers", ACCENT, color) + (" " + mine if mine else "")
    if not mine or not last:
        return line
    if numbers(last) <= numbers(mine):
        return line + paint(" · up to date", DIM, color)
    return line + paint(" · %s is installing, run /reload-plugins when Claude Code offers it" % last, DIM, color)


def name(root):
    """The artifactId of the project, else its directory name."""
    pom = open(os.path.join(root, "pom.xml"), encoding="utf-8", errors="replace").read()
    pom = re.sub(r"<!--.*?-->|<parent>.*?</parent>", "", pom, flags=re.S)
    m = re.search(r"<artifactId>\s*([^<\s]+)\s*</artifactId>", pom)
    return m.group(1) if m else os.path.basename(root)


def lines(root, doctor, color):
    """The block, one line per fact, a problem line only for what the machine lacks."""
    found = lutece_level.detect(root)
    kind, major = found if found else ("plugin", None)
    dot = paint(" · ", DIM, color)
    problems = [(s, m) for s, _, m in doctor if s in ("FAIL", "WARN")]
    level = "Lutece %d %s" % (major, kind) if major is not None else "Lutece %s, version not detected" % kind
    project = name(root) + dot + level + (dot + paint("machine ready", DIM, color) if doctor and not problems else "")
    out = [tool_line(color), project]
    for status, message in problems:
        problem, _, fix = message.partition(": ")
        mark = paint("✗", RED, color) if status == "FAIL" else paint("▲", YELLOW, color)
        out.append("%s %s%s" % (mark, problem, paint("  → " + fix, DIM, color) if fix else ""))
    if major is not None and major < 8:
        skill = "lutece-update-site" if kind == "site" else "lutece-update-plugin"
        out.append("%s %s %s" % (paint("›", DIM, color), paint("/lutecepowers-v8:" + skill, BOLD, color),
                                 paint("to move to Lutece 8", DIM, color)))
    else:
        out.append("%s %s %s" % (paint("›", DIM, color), paint("/lutecepowers-v8:lutece-checkup", BOLD, color),
                                 paint("to check this " + kind, DIM, color)))
    return out


def main():
    """Prints the block, after a blank line that sets it apart from the hook prefix."""
    root, color = os.path.abspath(sys.argv[1]), sys.argv[2] == "1"
    doctor = [m.groups() for m in (re.match(r"^\s+(PASS|WARN|FAIL) \[(ENV\d+)\] (.*)$", l) for l in sys.stdin) if m]
    print("\n" + "\n".join(lines(root, doctor, color)), end="")


if __name__ == "__main__":
    main()
