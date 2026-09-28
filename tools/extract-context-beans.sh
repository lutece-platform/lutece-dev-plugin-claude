#!/bin/bash
# extract-context-beans.sh — Parse Spring context XML files into structured JSON
# Usage: bash extract-context-beans.sh [project_root] [output_file]
# Output: JSON catalog of all Spring bean definitions, written by spring-context-catalog.py

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/python.sh"

PROJECT_ROOT="${1:-.}"
OUTPUT_FILE="${2:-.migration/context-beans.json}"

mkdir -p "$(dirname "$OUTPUT_FILE")"
python3 "$(dirname "$0")/spring-context-catalog.py" "$PROJECT_ROOT" > "$OUTPUT_FILE"
python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print("=== Extracted %d beans from %d context files ===" % (len(d["beans"]), len(d["files"])))' "$OUTPUT_FILE" >&2
echo "Output: $OUTPUT_FILE" >&2
