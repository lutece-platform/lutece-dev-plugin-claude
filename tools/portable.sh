# shellcheck shell=bash
# portable.sh — sourced by the toolkit's shell scripts: helpers that behave the same with GNU and BSD tools (Linux,
# Windows Git Bash, macOS), and a guard for the scripts that still rely on GNU sed and grep regex extensions.

# Sorts lines by the first dotted version they carry (8.0.10 after 8.0.9), a true version sort on every platform.
lp_version_sort() {
  awk '{ v = ""; if (match($0, /[0-9]+(\.[0-9]+)+/)) v = substr($0, RSTART, RLENGTH); n = split(v, p, ".")
         k = ""; for (i = 1; i <= 6; i++) k = k sprintf("%09d.", (i <= n ? p[i] : 0)); print k "\t" $0 }' | LC_ALL=C sort | cut -f2-
}

# Prints the lines of stdin last first, as GNU tac does; a reader that stops early is not an error.
lp_reverse() {
  awk '{ l[NR] = $0 } END { for (i = NR; i > 0; i--) print l[i] }' 2>/dev/null || true
}

# Stops the calling script unless sed and grep are the GNU ones, whose regex extensions (\b, \s, \|) it relies on.
lp_require_gnu() {
  if ! sed --version 2>/dev/null | grep -q GNU || ! grep --version 2>/dev/null | grep -q GNU; then
    echo "$(basename "$0") stopped: it needs GNU sed and GNU grep (BSD ones would give wrong results without an error). On macOS: brew install gnu-sed grep, then put their gnubin directories first on PATH." >&2
    exit 2
  fi
}
