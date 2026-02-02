#!/bin/bash

#set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/scaffold-init.sh"
source "$SCRIPT_DIR/lib/scaffold-config.sh"
source "$SCRIPT_DIR/lib/scaffold-entity.sh"
source "$SCRIPT_DIR/lib/scaffold-service.sh"
source "$SCRIPT_DIR/lib/scaffold-jspbean.sh"
source "$SCRIPT_DIR/lib/scaffold-templates.sh"
source "$SCRIPT_DIR/lib/scaffold-features.sh"
source "$SCRIPT_DIR/lib/scaffold-i18n.sh"
source "$SCRIPT_DIR/lib/scaffold-workflow.sh"

CONFIG_FILE="$1"
OUTPUT_DIR="$2"

if [ -z "$CONFIG_FILE" ] || [ -z "$OUTPUT_DIR" ]; then
    scaffold_show_usage
    exit 1
fi

scaffold_check_requirements

scaffold_load_config "$CONFIG_FILE"
scaffold_prescan_file_fields "$CONFIG_FILE"

echo "=== Lutece Plugin Scaffold Generator ==="
echo "Plugin: $PLUGIN_NAME"
echo "Package: $PACKAGE_BASE"
echo "Output: $OUTPUT_DIR"
echo "Features: xpage=$FEATURE_XPAGE, cache=$FEATURE_CACHE, rbac=$FEATURE_RBAC, workflow=$FEATURE_WORKFLOW"
echo ""

PLUGIN_DIR="$OUTPUT_DIR/plugin-$PLUGIN_NAME"
mkdir -p "$PLUGIN_DIR"
cd "$PLUGIN_DIR"

scaffold_create_directories "$PLUGIN_DIR"

scaffold_generate_pom "$PLUGIN_DIR"

scaffold_generate_beans_xml "$PLUGIN_DIR"

scaffold_generate_entities "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_entity_service "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_workflow_service "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_plugin_properties "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_plugin_xml "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_jspbean "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_templates "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_cache_service "$PLUGIN_DIR" "$CONFIG_FILE"
scaffold_generate_xpage "$PLUGIN_DIR" "$CONFIG_FILE"
scaffold_generate_rbac "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_i18n "$PLUGIN_DIR" "$CONFIG_FILE"

scaffold_generate_claude_md "$PLUGIN_DIR"

echo ""
echo "=== Plugin scaffold generated successfully! ==="
echo ""
echo "Structure:"
find . -type f | head -30
echo "..."
echo ""

scaffold_generate_site "$PLUGIN_DIR" "$CONFIG_FILE" "$OUTPUT_DIR"

scaffold_generate_workflow_module "$OUTPUT_DIR" "$CONFIG_FILE"

echo ""
echo "Next steps:"
echo "1. cd $PLUGIN_DIR && mvn clean install"
if [ "$FEATURE_WORKFLOW" = "true" ]; then
    echo "2. cd $OUTPUT_DIR/module-workflow-$PLUGIN_NAME && mvn clean install"
fi
if [ "$FEATURE_SITE" = "true" ]; then
    SITE_NAME=$(jq -r '.features.site.name // "site-'$PLUGIN_NAME'"' "$CONFIG_FILE")
    echo "3. cd $OUTPUT_DIR/$SITE_NAME && mvn lutece:site-assembly"
    echo "4. cd target/${SITE_NAME}-1.0.0-SNAPSHOT/WEB-INF/sql && ant"
    echo "5. cd ../../../.. && mvn liberty:dev"
    echo "6. Open http://localhost:9080/${SITE_NAME}-1.0.0-SNAPSHOT/"
else
    echo "3. Deploy to Lutece site"
fi
echo ""
echo "CLAUDE.md created with Lutece rules"
if [ "$FEATURE_WORKFLOW" = "true" ]; then
    echo "Workflow module: $OUTPUT_DIR/module-workflow-$PLUGIN_NAME"
fi
