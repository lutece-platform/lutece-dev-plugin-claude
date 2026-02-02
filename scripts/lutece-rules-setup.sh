#!/bin/bash
# Detects if cwd is a Lutece project and copies rules to .claude/rules/

RULES_SRC="${CLAUDE_PLUGIN_ROOT}/rules"
RULES_DST=".claude/rules"

# Check if source rules exist
if [ ! -d "$RULES_SRC" ]; then
    echo "Rules source not found: $RULES_SRC"
    exit 0
fi

# Detect Lutece project
if [ -f "pom.xml" ]; then
    if grep -q "lutece-plugin\|lutece-site\|lutece-global-pom" pom.xml 2>/dev/null; then
        mkdir -p "$RULES_DST"
        cp "$RULES_SRC"/*.md "$RULES_DST/"
        echo "Lutece project detected. Rules copied to $RULES_DST/"
    fi
fi

exit 0
