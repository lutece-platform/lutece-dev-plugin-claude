#!/bin/bash

scaffold_generate_entity_service() {
    local plugin_dir="$1"
    local config_file="$2"

    echo "[6.5/9] Generating entity services..."

    local entity_count=$(jq '.entities | length' "$config_file")

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        local entity_var=$(echo "${entity_name:0:1}" | tr '[:upper:]' '[:lower:]')${entity_name:1}
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")

        local child_entities=""
        for ((k=0; k<entity_count; k++)); do
            local child_parent=$(jq -r ".entities[$k].parentEntity // empty" "$config_file")
            if [ "$child_parent" == "$entity_name" ]; then
                local child_name=$(jq -r ".entities[$k].name" "$config_file")
                child_entities+="$child_name,"
            fi
        done
        child_entities=${child_entities%,}

        local service_dir="$plugin_dir/src/java/$PACKAGE_PATH/service"
        mkdir -p "$service_dir"

        local child_imports=""
        local child_service_fields=""
        local child_service_inject=""
        local cascade_remove_code=""

        if [ -n "$child_entities" ]; then
            IFS=',' read -ra CHILD_ARR <<< "$child_entities"
            for child_name in "${CHILD_ARR[@]}"; do
                if [ -n "$child_name" ]; then
                    local child_lower=$(echo "$child_name" | tr '[:upper:]' '[:lower:]')
                    local child_var=$(echo "${child_name:0:1}" | tr '[:upper:]' '[:lower:]')${child_name:1}
                    child_imports+="import $PACKAGE_BASE.business.${child_name};
import $PACKAGE_BASE.business.${child_name}Home;
"
                    child_service_fields+="
    @Inject
    private ${child_name}Service _${child_var}Service;"
                    cascade_remove_code+="
        List<${child_name}> list${child_name}s = ${child_name}Home.findBy${entity_name}Id( nId${entity_name} );
        for ( ${child_name} ${child_var} : list${child_name}s )
        {
            _${child_var}Service.remove( ${child_var}.getId${child_name}() );
        }
"
                fi
            done
        fi

        local parent_import=""
        if [ -n "$parent_entity" ]; then
            parent_import="import $PACKAGE_BASE.business.${parent_entity}Home;
"
        fi

        echo "  - ${entity_name}Service"

        cat > "$service_dir/${entity_name}Service.java" << SERVICEEOF
package $PACKAGE_BASE.service;

${child_imports}${parent_import}import $PACKAGE_BASE.business.${entity_name};
import $PACKAGE_BASE.business.${entity_name}Home;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;

@ApplicationScoped
public class ${entity_name}Service
{
${child_service_fields}

    public ${entity_name} create( ${entity_name} ${entity_var} )
    {
        return ${entity_name}Home.create( ${entity_var} );
    }

    public ${entity_name} update( ${entity_name} ${entity_var} )
    {
        return ${entity_name}Home.update( ${entity_var} );
    }

    public ${entity_name} findByPrimaryKey( int nId${entity_name} )
    {
        return ${entity_name}Home.findByPrimaryKey( nId${entity_name} );
    }

    public List<${entity_name}> findAll()
    {
        return ${entity_name}Home.findAll();
    }

    @Transactional
    public void remove( int nId${entity_name} )
    {
${cascade_remove_code}
        ${entity_name}Home.remove( nId${entity_name} );
    }
}
SERVICEEOF

    done
}

scaffold_generate_workflow_service() {
    local plugin_dir="$1"
    local config_file="$2"

    # NOTE: With the Forms-pattern workflow integration, we use WorkflowService directly
    # from the JSPBean. No custom wrapper service is needed.
    # This function is kept for backwards compatibility but does nothing.
    return
}

scaffold_generate_plugin_properties() {
    local plugin_dir="$1"
    local config_file="$2"

    echo "[6.7/9] Generating plugin properties..."

    local conf_dir="$plugin_dir/webapp/WEB-INF/conf/plugins"
    mkdir -p "$conf_dir"

    local props_content="# ${PLUGIN_NAME^} Plugin Configuration

# Pagination
"

    local entity_count=$(jq '.entities | length' "$config_file")
    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        props_content+="$PLUGIN_NAME.${entity_lower}.itemsPerPage=50
"
    done

    # NOTE: Workflow IDs are now stored per-entity in the database (idWorkflow field)
    # No global workflow configuration needed in properties file

    echo "$props_content" > "$conf_dir/${PLUGIN_NAME}.properties"
}
