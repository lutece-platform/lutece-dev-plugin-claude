#!/usr/bin/env python3
"""admin_rights.py — the UPDATE statements of an install SQL script that rewrite one admin right.

An install script may give an admin right its final value in a changeset appended after the shipped INSERT (a shipped
changeset body is never edited, rules/sql-liquibase.md): what a fresh install holds is the INSERT row with those
updates applied in order. Only an update that names one right (`WHERE id_right = '<id>'` and nothing else) with
literal values is understood; any other (a bulk update, an expression, an extra condition) is left out, as before.
"""
import re

UPDATE = re.compile(r"(?is)\bupdate\s+core_admin_right\s+set\s+(.*?)\s+where\s+(.*?)\s*;")
ASSIGN = re.compile(r"""\s*(\w+)\s*=\s*('(?:[^']|'')*'|"[^"]*"|-?\d+|null)\s*(,|$)""", re.I)
WHERE = re.compile(r"""\s*id_right\s*=\s*('(?:[^']|'')*'|"[^"]*")\s*""", re.I)


def uncommented(text):
    """A SQL text with its whole-line `--` comments and `/* */` blocks blanked, offsets and line numbers kept: a
    commented-out statement is never run."""
    blank = lambda m: re.sub(r"[^\n]", " ", m.group(0))
    return re.sub(r"(?m)^[ \t]*--[^\n]*", blank, re.sub(r"/\*.*?\*/", blank, text, flags=re.S))


def _literal(value):
    """A SQL literal as text: quotes removed, a doubled quote made single, NULL as 'NULL'."""
    if value[:1] in "'\"":
        return value[1:-1].replace("''", "'")
    return value.upper() if value.lower() == "null" else value


def updates(text):
    """Every update of one admin right in a SQL text, in order: (offset, id_right, {column: value}). A `SET id_right`
    renames the right; the caller follows it."""
    out = []
    for match in UPDATE.finditer(uncommented(text)):
        where = WHERE.fullmatch(match.group(2))
        if not where:
            continue
        sets, pos, body = {}, 0, match.group(1)
        while pos < len(body):
            assign = ASSIGN.match(body, pos)
            if not assign or assign.end() == pos:
                sets = None
                break
            sets[assign.group(1).lower()] = _literal(assign.group(2))
            pos = assign.end()
            if not assign.group(3):
                break
        if sets and pos >= len(body.rstrip()):
            out.append((match.start(), _literal(where.group(1)), sets))
    return out

