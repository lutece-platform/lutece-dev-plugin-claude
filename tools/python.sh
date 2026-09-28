# shellcheck shell=bash
# python.sh — sourced by the toolkit's shell scripts: makes `python3` run a Python 3.9+ that really works.
# On Windows, python3 is usually the Microsoft Store alias, which exits without running anything, while a python.org
# install answers to python or py. Each candidate is probed (stdin closed) and the fallback is then run by the exact
# executable its probe printed, since the py launcher may pick another Python than the one it probed.
# LUTECEPOWERS_PYTHON forces an interpreter. Without a usable Python, python3 fails with a message saying what to do.

# Prints the path of the first interpreter that runs Python 3.9 or newer, or nothing.
lp_find_python() {
  local candidate found
  for candidate in ${LUTECEPOWERS_PYTHON:+"$LUTECEPOWERS_PYTHON"} python3 python py; do
    found=$(command "$candidate" -c 'import sys; sys.stdout.write(sys.executable.replace("\\", "/")); sys.exit(3 * (sys.version_info < (3, 9)))' 2>/dev/null </dev/null) && [ -n "$found" ] && { printf '%s' "$found"; return 0; }
  done
  return 1
}

if [ -z "${LP_PYTHON+x}" ]; then
  LP_PYTHON=$(lp_find_python) || LP_PYTHON=""
  export LP_PYTHON
fi

# Runs the Python found in place of python3, or explains how to get one.
python3() {
  if [ -z "$LP_PYTHON" ]; then
    echo "lutecepowers: no working Python 3.9+ (tried python3, python, py). On Windows install Python from python.org (not the Microsoft Store), or set LUTECEPOWERS_PYTHON to its python.exe." >&2
    return 127
  fi
  command "$LP_PYTHON" "$@"
}
export -f python3 lp_find_python 2>/dev/null || true
