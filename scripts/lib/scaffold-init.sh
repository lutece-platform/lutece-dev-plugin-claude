#!/bin/bash

scaffold_show_usage() {
    echo "Usage: $0 <config.json> <output_directory>"
    echo ""
    echo "Config JSON format:"
    echo '{'
    echo '  "pluginName": "myplugin",'
    echo '  "pluginDescription": "My Plugin Description",'
    echo '  "packageBase": "fr.paris.lutece.plugins.myplugin",'
    echo '  "features": {'
    echo '    "xpage": { "enabled": true, "name": "myxpage" },'
    echo '    "cache": { "enabled": true },'
    echo '    "rbac": { "enabled": true, "permissions": ["CREATE", "MODIFY", "DELETE", "VIEW"] },'
    echo '    "workflow": { "enabled": true }'
    echo '  },'
    echo '  "entities": ['
    echo '    {'
    echo '      "name": "Project",'
    echo '      "tableName": "myplugin_project",'
    echo '      "fields": ['
    echo '        {"name": "name", "type": "String", "required": true},'
    echo '        {"name": "description", "type": "longtext", "required": false},'
    echo '        {"name": "active", "type": "boolean", "required": true}'
    echo '      ]'
    echo '    }'
    echo '  ]'
    echo '}'
}

scaffold_check_requirements() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required. Install with: apt install jq"
        exit 1
    fi
}

scaffold_load_config() {
    local config_file="$1"

    PLUGIN_NAME=$(jq -r '.pluginName' "$config_file")
    PLUGIN_DESC=$(jq -r '.pluginDescription' "$config_file")
    PACKAGE_BASE=$(jq -r '.packageBase // empty' "$config_file")
    if [ -z "$PACKAGE_BASE" ]; then
        PACKAGE_BASE="fr.paris.lutece.plugins.$PLUGIN_NAME"
    fi
    PACKAGE_PATH=$(echo "$PACKAGE_BASE" | tr '.' '/')

    FEATURE_XPAGE=$(jq -r '.features.xpage.enabled // false' "$config_file")
    FEATURE_XPAGE_NAME=$(jq -r '.features.xpage.name // empty' "$config_file")
    FEATURE_CACHE=$(jq -r '.features.cache.enabled // false' "$config_file")
    FEATURE_RBAC=$(jq -r '.features.rbac.enabled // false' "$config_file")
    RBAC_PERMISSIONS=$(jq -r '.features.rbac.permissions // ["CREATE", "MODIFY", "DELETE", "VIEW"] | @json' "$config_file")
    FEATURE_SITE=$(jq -r '.features.site.enabled // false' "$config_file")
    FEATURE_WORKFLOW=$(jq -r '.features.workflow.enabled // false' "$config_file")

    ENTITY_COUNT=$(jq '.entities | length' "$config_file")
    FIRST_ENTITY=$(jq -r '.entities[0].name' "$config_file")
    FIRST_ENTITY_LOWER=$(echo "$FIRST_ENTITY" | tr '[:upper:]' '[:lower:]')
}

scaffold_prescan_file_fields() {
    local config_file="$1"

    PLUGIN_HAS_FILE_FIELDS=false
    local entity_count=$(jq '.entities | length' "$config_file")

    for ((i=0; i<entity_count; i++)); do
        local field_count=$(jq ".entities[$i].fields | length" "$config_file")
        for ((j=0; j<field_count; j++)); do
            local field_type=$(jq -r ".entities[$i].fields[$j].type" "$config_file")
            if [ "$field_type" == "file" ] || [ "$field_type" == "File" ]; then
                PLUGIN_HAS_FILE_FIELDS=true
                return
            fi
        done
    done
}

scaffold_create_directories() {
    local plugin_dir="$1"

    echo "[1/9] Creating directory structure..."

    mkdir -p "$plugin_dir/src/java/$PACKAGE_PATH/business"
    mkdir -p "$plugin_dir/src/java/$PACKAGE_PATH/service"
    [ "$FEATURE_CACHE" = "true" ] && mkdir -p "$plugin_dir/src/java/$PACKAGE_PATH/service/cache"
    mkdir -p "$plugin_dir/src/java/$PACKAGE_PATH/web"
    mkdir -p "$plugin_dir/src/java/$PACKAGE_PATH/resources"
    mkdir -p "$plugin_dir/src/sql/plugins/$PLUGIN_NAME/plugin"
    mkdir -p "$plugin_dir/src/sql/plugins/$PLUGIN_NAME/core"
    mkdir -p "$plugin_dir/src/test/java/$PACKAGE_PATH"
    mkdir -p "$plugin_dir/webapp/WEB-INF/conf/plugins"
    mkdir -p "$plugin_dir/webapp/WEB-INF/plugins"
    mkdir -p "$plugin_dir/webapp/WEB-INF/templates/admin/plugins/$PLUGIN_NAME"
    mkdir -p "$plugin_dir/webapp/WEB-INF/templates/skin/plugins/$PLUGIN_NAME"
    mkdir -p "$plugin_dir/webapp/jsp/admin/plugins/$PLUGIN_NAME"
    mkdir -p "$plugin_dir/src/main/resources/META-INF"
}

get_i18n() {
    local json_path="$1"
    local lang="$2"
    local default="$3"
    local config_file="$4"
    local value=$(jq -r "${json_path}.${lang} // ${json_path} // empty" "$config_file" 2>/dev/null)
    if [ -z "$value" ] || [ "$value" == "null" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

scaffold_get_java_type_info() {
    local field_type="$1"

    case $field_type in
        "string"|"String"|"text")
            echo "String|_str|getString|setString|VARCHAR(255)"
            ;;
        "longtext"|"longText"|"LongText")
            echo "String|_str|getString|setString|LONG VARCHAR"
            ;;
        "int"|"integer"|"Integer"|"number")
            echo "int|_n|getInt|setInt|INT"
            ;;
        "long"|"Long")
            echo "long|_l|getLong|setLong|BIGINT"
            ;;
        "boolean"|"Boolean"|"bool")
            echo "boolean|_b|getBoolean|setBoolean|SMALLINT"
            ;;
        "double"|"Double")
            echo "double|_d|getDouble|setDouble|DOUBLE"
            ;;
        "float"|"Float")
            echo "float|_f|getFloat|setFloat|FLOAT"
            ;;
        "timestamp"|"Timestamp")
            echo "Timestamp|_ts|getTimestamp|setTimestamp|TIMESTAMP"
            ;;
        "date"|"Date")
            echo "Date|_date|getDate|setDate|DATE"
            ;;
        "time"|"Time")
            echo "Time|_time|getTime|setTime|TIME"
            ;;
        "decimal"|"BigDecimal")
            echo "BigDecimal|_bd|getBigDecimal|setBigDecimal|DECIMAL(10,2)"
            ;;
        "file"|"File")
            echo "File|_file|getInt|setInt|INT DEFAULT 0"
            ;;
        *)
            echo "String|_str|getString|setString|VARCHAR(255)"
            ;;
    esac
}
