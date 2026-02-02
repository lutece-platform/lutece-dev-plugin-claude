#!/bin/bash

scaffold_find_child_entities_for_template() {
    local parent_name="$1"
    local config_file="$2"

    local entity_count=$(jq '.entities | length' "$config_file")
    local children=""

    for ((k=0; k<entity_count; k++)); do
        local child_parent=$(jq -r ".entities[$k].parentEntity // empty" "$config_file")
        if [ "$child_parent" == "$parent_name" ]; then
            local child_name=$(jq -r ".entities[$k].name" "$config_file")
            children+="$child_name,"
        fi
    done

    echo "${children%,}"
}

scaffold_generate_templates() {
    local plugin_dir="$1"
    local config_file="$2"

    echo "[7/9] Generating templates..."

    local entity_count=$(jq '.entities | length' "$config_file")

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        local parent_entity_lower=""
        [ -n "$parent_entity" ] && parent_entity_lower=$(echo "$parent_entity" | tr '[:upper:]' '[:lower:]')

        local child_entities=$(scaffold_find_child_entities_for_template "$entity_name" "$config_file")

        local table_headers=""
        local table_cols=""
        local ajax_columns=""
        local field_count=$(jq ".entities[$i].fields | length" "$config_file")

        for ((j=0; j<field_count; j++)); do
            local field_name=$(jq -r ".entities[$i].fields[$j].name" "$config_file")
            local field_type_raw=$(jq -r ".entities[$i].fields[$j].type" "$config_file")

            table_headers+="                <th>#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}</th>
"
            if [ "$field_type_raw" == "boolean" ] || [ "$field_type_raw" == "Boolean" ] || [ "$field_type_raw" == "bool" ]; then
                table_cols+="                <td><#if ${entity_lower}.$field_name!false><@icon style='check text-success' /><#else><@icon style='x text-danger' /></#if></td>
"
            elif [ "$field_type_raw" == "file" ] || [ "$field_type_raw" == "File" ]; then
                table_cols+="                <td><#if ${entity_lower}.$field_name?? && ${entity_lower}.$field_name.idFile gt 0><@icon style='file text-primary' /><#else>-</#if></td>
"
            else
                table_cols+="                <td>\${${entity_lower}.$field_name!}</td>
"
            fi

            # Build paginationAjax columns (skip file fields — they don't serialize well to JSON)
            if [ "$field_type_raw" != "file" ] && [ "$field_type_raw" != "File" ]; then
                local sortable="true"
                if [ "$field_type_raw" == "boolean" ] || [ "$field_type_raw" == "Boolean" ] || [ "$field_type_raw" == "bool" ] || \
                   [ "$field_type_raw" == "date" ] || [ "$field_type_raw" == "Date" ] || \
                   [ "$field_type_raw" == "timestamp" ] || [ "$field_type_raw" == "Timestamp" ]; then
                    sortable="false"
                fi
                if [ -n "$ajax_columns" ]; then
                    ajax_columns+=",
"
                fi
                ajax_columns+="          {\"name\": \"#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}\", \"property\": \"$field_name\", \"sortable\": $sortable}"
            fi
        done

        local child_action_cols=""
        if [ -n "$child_entities" ]; then
            IFS=',' read -ra CHILD_ARR <<< "$child_entities"
            for child_name in "${CHILD_ARR[@]}"; do
                if [ -n "$child_name" ]; then
                    local child_lower=$(echo "$child_name" | tr '[:upper:]' '[:lower:]')
                    child_action_cols+="                        <@aButton href='jsp/admin/plugins/$PLUGIN_NAME/Manage${child_name}s.jsp?id${entity_name}=\${${entity_lower}.id${entity_name}}' buttonIcon='list' title='#i18n{$PLUGIN_NAME.manage_${entity_lower}s.button${child_name}s}' color='info' size='sm' />
"
                fi
            done
        fi

        local jsp_path="jsp/admin/plugins/$PLUGIN_NAME/Manage${entity_name}s.jsp"
        local parent_jsp_path=""
        [ -n "$parent_entity" ] && parent_jsp_path="jsp/admin/plugins/$PLUGIN_NAME/Manage${parent_entity}s.jsp"

        scaffold_generate_manage_template "$plugin_dir" "$entity_name" "$entity_lower" "$table_headers" "$table_cols" "$jsp_path" "$parent_entity" "$parent_entity_lower" "$parent_jsp_path" "$child_action_cols" "$ajax_columns"

        local template_has_files=false
        for ((j=0; j<field_count; j++)); do
            local field_type_check=$(jq -r ".entities[$i].fields[$j].type" "$config_file")
            if [ "$field_type_check" == "file" ] || [ "$field_type_check" == "File" ]; then
                template_has_files=true
                break
            fi
        done

        local form_fields_macro=""
        for ((j=0; j<field_count; j++)); do
            local field_name=$(jq -r ".entities[$i].fields[$j].name" "$config_file")
            local field_type_raw=$(jq -r ".entities[$i].fields[$j].type" "$config_file")
            local field_param=$(echo "$field_name" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
            local required=$(jq -r ".entities[$i].fields[$j].required" "$config_file")
            local mandatory=""
            [ "$required" == "true" ] && mandatory=" mandatory=true"

            if [ "$field_type_raw" == "boolean" ] || [ "$field_type_raw" == "Boolean" ] || [ "$field_type_raw" == "bool" ]; then
                form_fields_macro+="            <@formGroup labelFor='$field_name' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}' rows=2>\n"
                form_fields_macro+="                <@checkBox orientation='switch' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}' name='$field_name' id='$field_name' value='true' checked=${entity_lower}.$field_name!false />\n"
                form_fields_macro+="            </@formGroup>\n"
            elif [ "$field_type_raw" == "longtext" ] || [ "$field_type_raw" == "longText" ] || [ "$field_type_raw" == "LongText" ]; then
                form_fields_macro+="            <@formGroup labelFor='$field_name' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}'$mandatory rows=2>\n"
                form_fields_macro+="                <@input type='textarea' name='$field_name' id='$field_name'>\${${entity_lower}.$field_name!}</@input>\n"
                form_fields_macro+="            </@formGroup>\n"
            elif [ "$field_type_raw" == "date" ] || [ "$field_type_raw" == "Date" ]; then
                form_fields_macro+="            <@formGroup labelFor='$field_name' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}'$mandatory rows=2>\n"
                form_fields_macro+="                <@input type='date' name='$field_name' id='$field_name' value='\${${entity_lower}.$field_name!}' />\n"
                form_fields_macro+="            </@formGroup>\n"
            elif [ "$field_type_raw" == "timestamp" ] || [ "$field_type_raw" == "Timestamp" ]; then
                form_fields_macro+="            <@formGroup labelFor='$field_name' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}'$mandatory rows=2>\n"
                form_fields_macro+="                <@input type='datetime' name='$field_name' id='$field_name' value=\"\${(${entity_lower}.$field_name?string[\\\"yyyy-MM-dd'T'HH:mm:ss\\\"])!}\" />\n"
                form_fields_macro+="            </@formGroup>\n"
            elif [ "$field_type_raw" == "int" ] || [ "$field_type_raw" == "integer" ] || [ "$field_type_raw" == "Integer" ] || [ "$field_type_raw" == "number" ]; then
                form_fields_macro+="            <@formGroup labelFor='$field_name' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}'$mandatory rows=2>\n"
                form_fields_macro+="                <@input type='number' name='$field_name' id='$field_name' value='\${${entity_lower}.$field_name!0}' />\n"
                form_fields_macro+="            </@formGroup>\n"
            elif [ "$field_type_raw" == "file" ] || [ "$field_type_raw" == "File" ]; then
                form_fields_macro+="            <@formGroup labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}'$mandatory rows=2>\n"
                form_fields_macro+="                <@addFileBOInput fieldName='upload_${field_param}' handler=uploadHandler submitBtnName='action_doSynchronousUploadDocument' cssClass='' multiple=false />\n"
                form_fields_macro+="                <#if !listFiles??><#assign listFiles = ''></#if>\n"
                form_fields_macro+="                <div id='listUpload_${field_name}'>\n"
                form_fields_macro+="                    <@addBOUploadedFilesBox fieldName='upload_${field_param}' handler=uploadHandler submitBtnName='action_doSynchronousUploadDocument' listFiles=listFiles />\n"
                form_fields_macro+="                </div>\n"
                form_fields_macro+="            </@formGroup>\n"
            else
                form_fields_macro+="            <@formGroup labelFor='$field_name' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.$field_name}'$mandatory rows=2>\n"
                form_fields_macro+="                <@input type='text' name='$field_name' id='$field_name' value='\${${entity_lower}.$field_name!}' />\n"
                form_fields_macro+="            </@formGroup>\n"
            fi
        done

        scaffold_generate_create_template "$plugin_dir" "$entity_name" "$entity_lower" "$form_fields_macro" "$jsp_path" "$template_has_files" "$parent_entity" "$parent_entity_lower"
        scaffold_generate_modify_template "$plugin_dir" "$entity_name" "$entity_lower" "$form_fields_macro" "$jsp_path" "$template_has_files" "$parent_entity" "$parent_entity_lower"
    done
}

scaffold_generate_manage_template() {
    local plugin_dir="$1"
    local entity_name="$2"
    local entity_lower="$3"
    local table_headers="$4"
    local table_cols="$5"
    local jsp_path="$6"
    local parent_entity="$7"
    local parent_entity_lower="$8"
    local parent_jsp_path="$9"
    local child_action_cols="${10}"
    local ajax_columns="${11}"

    local back_button=""
    local page_description=""
    local parent_id_param=""
    if [ -n "$parent_entity" ]; then
        back_button="            <@aButton href='$parent_jsp_path?id${parent_entity}=\${${parent_entity_lower}.id${parent_entity}!}' buttonIcon='arrow-left' title='#i18n{portal.util.labelBack}' />
"
        page_description=" description='\${${parent_entity_lower}.name!}'"
        parent_id_param="&id${parent_entity}=\${id${parent_entity}}"
    fi

    local template_file="$plugin_dir/webapp/WEB-INF/templates/admin/plugins/$PLUGIN_NAME/manage_${entity_lower}s.html"

    # Use paginationAjax by default; fall back to manual table for workflow or child entities
    local use_ajax_pagination=true
    if [ "$FEATURE_WORKFLOW" == "true" ] || [ -n "$child_action_cols" ]; then
        use_ajax_pagination=false
    fi

    if [ "$use_ajax_pagination" = true ]; then
        # --- paginationAjax mode (AJAX-driven table with JSON endpoint) ---
        cat > "$template_file" << MANAGEEOF
<@pageContainer>
    <@pageColumn>
        <@pageHeader title='#i18n{$PLUGIN_NAME.manage_${entity_lower}s.pageTitle}'$page_description>
$back_button            <@aButton href='$jsp_path?view=create${entity_name}$parent_id_param' buttonIcon='plus' title='#i18n{$PLUGIN_NAME.manage_${entity_lower}s.buttonAdd}' color='primary' />
        </@pageHeader>
        <#assign ${entity_lower}Columns = [
$ajax_columns
        ]>
        <#assign ${entity_lower}Actions = {
          "edit": {
            "url": "$jsp_path?view=modify${entity_name}&id={id${entity_name}}",
            "icon": "edit",
            "title": "#i18n{portal.util.labelModify}",
            "btnClass": "btn-primary btn-sm"
          },
          "delete": {
            "url": "$jsp_path?action=confirmRemove${entity_name}&id={id${entity_name}}",
            "icon": "trash",
            "title": "#i18n{portal.util.labelDelete}",
            "btnClass": "btn-danger btn-sm",
            "confirm": "false"
          }
        }>
        <@paginationAjax paginator=paginator columns=${entity_lower}Columns
            ajaxUrl='$jsp_path?action=get${entity_name}Items'
            tableId='${entity_lower}Table'
            combo=1 showcount=1
            actions=${entity_lower}Actions />
    </@pageColumn>
</@pageContainer>
MANAGEEOF
    else
        # --- paginationAdmin mode (manual table — required for workflow columns / child actions) ---

        # Workflow columns (only if FEATURE_WORKFLOW is enabled)
        local wf_header=""
        local wf_col=""
        local wf_actions=""
        if [ "$FEATURE_WORKFLOW" == "true" ]; then
            wf_header="                <#if workflow_enabled!false><th>#i18n{$PLUGIN_NAME.manage_${entity_lower}s.columnState}</th></#if>
"
            wf_col="                <#if workflow_enabled!false>
                    <td>
                        <#if workflow_states_map?? && workflow_states_map[${entity_lower}.id${entity_name}?c]??>
                            <@tag color='primary'>\${workflow_states_map[${entity_lower}.id${entity_name}?c].name}</@tag>
                        <#else>
                            <@tag color='secondary'>#i18n{$PLUGIN_NAME.workflow.noState}</@tag>
                        </#if>
                    </td>
                </#if>
"
            wf_actions="                        <#if workflow_enabled!false && workflow_actions_map??>
                            <#list (workflow_actions_map[${entity_lower}.id${entity_name}?c])![] as action>
                                <@aButton href='$jsp_path?action=doWorkflowAction&id=\${${entity_lower}.id${entity_name}}&id_action=\${action.id}' buttonIcon='play' title='\${action.name}' color='success' size='sm' />
                            </#list>
                        </#if>
"
        fi

        cat > "$template_file" << MANAGEEOF
<@pageContainer>
    <@pageColumn>
        <@pageHeader title='#i18n{$PLUGIN_NAME.manage_${entity_lower}s.pageTitle}'$page_description>
$back_button            <@aButton href='$jsp_path?view=create${entity_name}$parent_id_param' buttonIcon='plus' title='#i18n{$PLUGIN_NAME.manage_${entity_lower}s.buttonAdd}' color='primary' />
        </@pageHeader>
        <#if ${entity_lower}_list?size gt 5><@paginationAdmin paginator=paginator showcount=1 combo=0 /></#if>
        <#if ${entity_lower}_list?size gt 0>
            <@table>
                <tr>
$table_headers$wf_header                    <th>#i18n{portal.util.labelActions}</th>
                </tr>
                <#list ${entity_lower}_list as ${entity_lower}>
                <tr>
$table_cols$wf_col                    <td>
$wf_actions$child_action_cols                        <@aButton href='$jsp_path?view=modify${entity_name}&id=\${${entity_lower}.id${entity_name}}' buttonIcon='edit' title='#i18n{portal.util.labelModify}' size='sm' />
                        <@aButton href='$jsp_path?action=confirmRemove${entity_name}&id=\${${entity_lower}.id${entity_name}}' buttonIcon='trash' color='danger' title='#i18n{portal.util.labelDelete}' size='sm' />
                    </td>
                </tr>
                </#list>
            </@table>
        <#else>
            <@alert color='info'>#i18n{$PLUGIN_NAME.manage_${entity_lower}s.noData}</@alert>
        </#if>
        <#if ${entity_lower}_list?size gt 5><@paginationAdmin paginator=paginator combo=1 showcount=0 /></#if>
    </@pageColumn>
</@pageContainer>
MANAGEEOF
    fi
}

scaffold_generate_create_template() {
    local plugin_dir="$1"
    local entity_name="$2"
    local entity_lower="$3"
    local form_fields_macro="$4"
    local jsp_path="$5"
    local has_files="$6"
    local parent_entity="$7"
    local parent_entity_lower="$8"

    local form_enctype=""
    local upload_include=""
    local upload_script=""
    if [ "$has_files" = true ]; then
        form_enctype=" params='enctype=\"multipart/form-data\"'"
        upload_include="<#include \"/admin/plugins/asynchronousupload/upload_commons.html\" />"
        upload_script="<script src=\"jsp/admin/plugins/asynchronousupload/GetMainUploadJs.jsp?handler=\${uploadHandler.handlerName}\" ></script>"
    fi

    local back_url="$jsp_path?view=manage${entity_name}s"
    local parent_hidden=""
    if [ -n "$parent_entity" ]; then
        back_url="$jsp_path?view=manage${entity_name}s&id${parent_entity}=\${id${parent_entity}}"
        parent_hidden="            <@input type='hidden' name='id${parent_entity}' value='\${id${parent_entity}}' />"
    fi

    # Workflow select dropdown (only if FEATURE_WORKFLOW is enabled)
    local workflow_select=""
    if [ "$FEATURE_WORKFLOW" == "true" ]; then
        workflow_select="            <#if workflow_list??>
            <@formGroup labelFor='idWorkflow' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.idWorkflow}' rows=2>
                <@select name='idWorkflow' id='idWorkflow'>
                    <option value=\"0\">#i18n{$PLUGIN_NAME.workflow.noWorkflow}</option>
                    <#list workflow_list as item>
                        <option value=\"\${item.code}\">\${item.name}</option>
                    </#list>
                </@select>
            </@formGroup>
            </#if>
"
    fi

    cat > "$plugin_dir/webapp/WEB-INF/templates/admin/plugins/$PLUGIN_NAME/create_${entity_lower}.html" << CREATEEOF
$upload_include
<@pageContainer>
    <@pageColumn>
        <@pageHeader title='#i18n{$PLUGIN_NAME.create_${entity_lower}.pageTitle}'>
            <@aButton href='$back_url' buttonIcon='arrow-left' title='#i18n{portal.util.labelBack}' />
        </@pageHeader>
        <@tform method='post' name='create_${entity_lower}' action='$jsp_path' boxed=true$form_enctype>
            <@input type='hidden' name='action' value='create${entity_name}' />
$parent_hidden
$(echo -e "$form_fields_macro")$workflow_select
            <@formGroup rows=2>
                <@button type='submit' buttonIcon='check' title='#i18n{portal.util.labelValidate}' color='primary' />
                <@aButton href='$back_url' buttonIcon='times' title='#i18n{portal.util.labelCancel}' />
            </@formGroup>
        </@tform>
    </@pageColumn>
</@pageContainer>
$upload_script
CREATEEOF
}

scaffold_generate_modify_template() {
    local plugin_dir="$1"
    local entity_name="$2"
    local entity_lower="$3"
    local form_fields_macro="$4"
    local jsp_path="$5"
    local has_files="$6"
    local parent_entity="$7"
    local parent_entity_lower="$8"

    local form_enctype=""
    local upload_include=""
    local upload_script=""
    if [ "$has_files" = true ]; then
        form_enctype=" params='enctype=\"multipart/form-data\"'"
        upload_include="<#include \"/admin/plugins/asynchronousupload/upload_commons.html\" />"
        upload_script="<script src=\"jsp/admin/plugins/asynchronousupload/GetMainUploadJs.jsp?handler=\${uploadHandler.handlerName}\" ></script>"
    fi

    local back_url="$jsp_path?view=manage${entity_name}s"
    if [ -n "$parent_entity" ]; then
        back_url="$jsp_path?view=manage${entity_name}s&id${parent_entity}=\${${entity_lower}.id${parent_entity}}"
    fi

    # Workflow section (only if FEATURE_WORKFLOW is enabled)
    local wf_section=""
    local workflow_select=""
    if [ "$FEATURE_WORKFLOW" == "true" ]; then
        wf_section="
        <#-- Workflow Status Section -->
        <#if workflow_enabled!false>
            <@box color='info' title='#i18n{$PLUGIN_NAME.workflow.title}'>
                <div class=\"d-flex align-items-center gap-3 mb-3\">
                    <strong>#i18n{$PLUGIN_NAME.workflow.currentState}:</strong>
                    <#if workflow_state??>
                        <@tag color='primary' class='fs-5'>\${workflow_state.name}</@tag>
                    <#else>
                        <@tag color='secondary'>#i18n{$PLUGIN_NAME.workflow.noState}</@tag>
                    </#if>
                </div>
                <#if workflow_actions?? && workflow_actions?size gt 0>
                    <div class=\"d-flex gap-2 flex-wrap\">
                        <#list workflow_actions as action>
                            <@aButton href='$jsp_path?action=doWorkflowAction&id=\${${entity_lower}.id${entity_name}}&id_action=\${action.id}' buttonIcon='play' title='\${action.name}' color='success' />
                        </#list>
                    </div>
                </#if>
            </@box>
        </#if>
"
        workflow_select="            <#if workflow_list??>
            <@formGroup labelFor='idWorkflow' labelKey='#i18n{$PLUGIN_NAME.model.entity.${entity_lower}.attribute.idWorkflow}' rows=2>
                <@select name='idWorkflow' id='idWorkflow'>
                    <option value=\"0\">#i18n{$PLUGIN_NAME.workflow.noWorkflow}</option>
                    <#list workflow_list as item>
                        <option value=\"\${item.code}\"<#if ${entity_lower}.idWorkflow?? && ${entity_lower}.idWorkflow == item.code?number> selected</#if>>\${item.name}</option>
                    </#list>
                </@select>
            </@formGroup>
            </#if>
"
    fi

    cat > "$plugin_dir/webapp/WEB-INF/templates/admin/plugins/$PLUGIN_NAME/modify_${entity_lower}.html" << MODIFYEOF
$upload_include
<@pageContainer>
    <@pageColumn>
        <@pageHeader title='#i18n{$PLUGIN_NAME.modify_${entity_lower}.pageTitle}'>
            <@aButton href='$back_url' buttonIcon='arrow-left' title='#i18n{portal.util.labelBack}' />
        </@pageHeader>
$wf_section
        <@tform method='post' name='modify_${entity_lower}' action='$jsp_path' boxed=true$form_enctype>
            <@input type='hidden' name='action' value='modify${entity_name}' />
            <@input type='hidden' name='id' value='\${${entity_lower}.id${entity_name}}' />
$(echo -e "$form_fields_macro")$workflow_select
            <@formGroup rows=2>
                <@button type='submit' buttonIcon='check' title='#i18n{portal.util.labelValidate}' color='primary' />
                <@aButton href='$back_url' buttonIcon='times' title='#i18n{portal.util.labelCancel}' />
            </@formGroup>
        </@tform>
    </@pageColumn>
</@pageContainer>
$upload_script
MODIFYEOF
}
