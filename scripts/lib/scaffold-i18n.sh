#!/bin/bash

scaffold_generate_i18n() {
    local plugin_dir="$1"
    local config_file="$2"

    echo "[8/9] Generating i18n properties..."

    local plugin_desc_en=$(get_i18n ".pluginDescription" "en" "$PLUGIN_DESC" "$config_file")
    local plugin_desc_fr=$(get_i18n ".pluginDescription" "fr" "$PLUGIN_DESC" "$config_file")

    local first_entity_label_en=$(get_i18n ".entities[0].label" "en" "$FIRST_ENTITY" "$config_file")
    local first_entity_label_fr=$(get_i18n ".entities[0].label" "fr" "$FIRST_ENTITY" "$config_file")

    local i18n_en="# Plugin\n"
    i18n_en+="plugin.description=${plugin_desc_en}\n"
    i18n_en+="plugin.provider=City of Paris\n\n"
    i18n_en+="# Admin features\n"
    i18n_en+="adminFeature.manage${FIRST_ENTITY}s.name=Manage ${first_entity_label_en}s\n"
    i18n_en+="adminFeature.manage${FIRST_ENTITY}s.description=Create and manage ${first_entity_label_en}s\n\n"

    local i18n_fr="# Plugin\n"
    i18n_fr+="plugin.description=${plugin_desc_fr}\n"
    i18n_fr+="plugin.provider=Ville de Paris\n\n"
    i18n_fr+="# Admin features\n"
    i18n_fr+="adminFeature.manage${FIRST_ENTITY}s.name=Gestion des ${first_entity_label_fr}s\n"
    i18n_fr+="adminFeature.manage${FIRST_ENTITY}s.description=Créer et gérer les ${first_entity_label_fr}s\n\n"

    local entity_count=$(jq '.entities | length' "$config_file")

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')

        local entity_label_en=$(get_i18n ".entities[$i].label" "en" "$entity_name" "$config_file")
        local entity_label_fr=$(get_i18n ".entities[$i].label" "fr" "$entity_name" "$config_file")

        i18n_en+="# ${entity_name}\n"
        i18n_en+="manage_${entity_lower}s.pageTitle=Manage ${entity_label_en}s\n"
        i18n_en+="manage_${entity_lower}s.buttonAdd=Add ${entity_label_en}\n"
        i18n_en+="manage_${entity_lower}s.noData=No ${entity_label_en}s found\n"
        i18n_en+="create_${entity_lower}.pageTitle=Create ${entity_label_en}\n"
        i18n_en+="modify_${entity_lower}.pageTitle=Modify ${entity_label_en}\n"
        i18n_en+="message.confirm_remove_${entity_lower}=Are you sure you want to delete this ${entity_label_en}?\n"

        i18n_fr+="# ${entity_name}\n"
        i18n_fr+="manage_${entity_lower}s.pageTitle=Gestion des ${entity_label_fr}s\n"
        i18n_fr+="manage_${entity_lower}s.buttonAdd=Ajouter une ${entity_label_fr}\n"
        i18n_fr+="manage_${entity_lower}s.noData=Aucune ${entity_label_fr} trouvée\n"
        i18n_fr+="create_${entity_lower}.pageTitle=Créer une ${entity_label_fr}\n"
        i18n_fr+="modify_${entity_lower}.pageTitle=Modifier la ${entity_label_fr}\n"
        i18n_fr+="message.confirm_remove_${entity_lower}=Êtes-vous sûr de vouloir supprimer cette ${entity_label_fr} ?\n"

        for ((k=0; k<entity_count; k++)); do
            local child_parent=$(jq -r ".entities[$k].parentEntity // empty" "$config_file")
            if [ "$child_parent" == "$entity_name" ]; then
                local child_name=$(jq -r ".entities[$k].name" "$config_file")
                local child_label_en=$(get_i18n ".entities[$k].label" "en" "$child_name" "$config_file")
                local child_label_fr=$(get_i18n ".entities[$k].label" "fr" "$child_name" "$config_file")
                i18n_en+="manage_${entity_lower}s.button${child_name}s=${child_label_en}s\n"
                i18n_fr+="manage_${entity_lower}s.button${child_name}s=${child_label_fr}s\n"
            fi
        done

        i18n_en+="\n"
        i18n_fr+="\n"

        local field_count=$(jq ".entities[$i].fields | length" "$config_file")

        for ((j=0; j<field_count; j++)); do
            local field_name=$(jq -r ".entities[$i].fields[$j].name" "$config_file")
            local default_label=$(echo "$field_name" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^./\U&/')

            local field_label_en=$(get_i18n ".entities[$i].fields[$j].label" "en" "$default_label" "$config_file")
            local field_label_fr=$(get_i18n ".entities[$i].fields[$j].label" "fr" "$default_label" "$config_file")

            i18n_en+="model.entity.${entity_lower}.attribute.${field_name}=${field_label_en}\n"
            i18n_fr+="model.entity.${entity_lower}.attribute.${field_name}=${field_label_fr}\n"
        done
        i18n_en+="\n"
        i18n_fr+="\n"
    done

    if [ "$FEATURE_XPAGE" = "true" ]; then
        local xpage_title_en=$(get_i18n ".features.xpage.title" "en" "My ${first_entity_label_en}s" "$config_file")
        local xpage_title_fr=$(get_i18n ".features.xpage.title" "fr" "Mes ${first_entity_label_fr}s" "$config_file")

        i18n_en+="# XPage\n"
        i18n_en+="xpage.pageTitle=${xpage_title_en}\n"
        i18n_en+="xpage.pagePathLabel=${xpage_title_en}\n"
        i18n_en+="xpage.noData=No data found\n\n"

        i18n_fr+="# XPage\n"
        i18n_fr+="xpage.pageTitle=${xpage_title_fr}\n"
        i18n_fr+="xpage.pagePathLabel=${xpage_title_fr}\n"
        i18n_fr+="xpage.noData=Aucune donnée trouvée\n\n"
    fi

    if [ "$FEATURE_RBAC" = "true" ]; then
        i18n_en+="# RBAC Permissions\n"
        i18n_en+="permission.label.resourceType=${first_entity_label_en}\n"

        i18n_fr+="# RBAC Permissions\n"
        i18n_fr+="permission.label.resourceType=${first_entity_label_fr}\n"

        for perm in $(echo "$RBAC_PERMISSIONS" | jq -r '.[]'); do
            local perm_lower=$(echo "$perm" | tr '[:upper:]' '[:lower:]')
            case $perm_lower in
                "create") i18n_en+="permission.label.${perm_lower}=Create\n"; i18n_fr+="permission.label.${perm_lower}=Créer\n";;
                "modify") i18n_en+="permission.label.${perm_lower}=Modify\n"; i18n_fr+="permission.label.${perm_lower}=Modifier\n";;
                "delete") i18n_en+="permission.label.${perm_lower}=Delete\n"; i18n_fr+="permission.label.${perm_lower}=Supprimer\n";;
                "view") i18n_en+="permission.label.${perm_lower}=View\n"; i18n_fr+="permission.label.${perm_lower}=Consulter\n";;
                *) i18n_en+="permission.label.${perm_lower}=${perm}\n"; i18n_fr+="permission.label.${perm_lower}=${perm}\n";;
            esac
        done
        i18n_en+="\n"
        i18n_fr+="\n"
    fi

    if [ "$FEATURE_WORKFLOW" = "true" ]; then
        i18n_en+="# Workflow\n"
        i18n_en+="workflow.title=Workflow Status\n"
        i18n_en+="workflow.currentState=Current State\n"
        i18n_en+="workflow.noState=Not initialized\n"
        i18n_en+="workflow.noWorkflow=No workflow\n"

        i18n_fr+="# Workflow\n"
        i18n_fr+="workflow.title=Statut du Workflow\n"
        i18n_fr+="workflow.currentState=État actuel\n"
        i18n_fr+="workflow.noState=Non initialisé\n"
        i18n_fr+="workflow.noWorkflow=Aucun workflow\n"

        for ((i=0; i<entity_count; i++)); do
            local entity_name=$(jq -r ".entities[$i].name" "$config_file")
            local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
            i18n_en+="manage_${entity_lower}s.columnState=State\n"
            i18n_en+="model.entity.${entity_lower}.attribute.idWorkflow=Workflow\n"
            i18n_fr+="manage_${entity_lower}s.columnState=État\n"
            i18n_fr+="model.entity.${entity_lower}.attribute.idWorkflow=Workflow\n"
        done
        i18n_en+="\n"
        i18n_fr+="\n"
    fi

    echo -e "$i18n_en" > "$plugin_dir/src/java/$PACKAGE_PATH/resources/${PLUGIN_NAME}_messages.properties"
    echo -e "$i18n_en" > "$plugin_dir/src/java/$PACKAGE_PATH/resources/${PLUGIN_NAME}_messages_en.properties"
    echo -e "$i18n_fr" > "$plugin_dir/src/java/$PACKAGE_PATH/resources/${PLUGIN_NAME}_messages_fr.properties"
}
