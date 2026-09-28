#!/usr/bin/env bash
# py.sh — runs a toolkit Python script with the first working Python 3.9+ (python3, python, py): use it instead of python3.
# Usage: bash py.sh <script.py | -c code | -m module> [args...]
. "$(dirname "$0")/python.sh"
python3 "$@"
