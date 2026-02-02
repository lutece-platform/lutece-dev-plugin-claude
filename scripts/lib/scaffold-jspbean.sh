#!/bin/bash

scaffold_build_file_handling_code() {
    local entity_var="$1"
    local file_fields="$2"

    JSPBEAN_FILE_IMPORTS=""
    JSPBEAN_FILE_CONSTANTS=""
    JSPBEAN_FILE_FIELDS=""
    JSPBEAN_FILE_METHODS=""
    JSPBEAN_FILE_CREATE_CODE=""
    JSPBEAN_FILE_MODIFY_CODE=""
    JSPBEAN_FILE_MODIFY_LOAD_CODE=""
    JSPBEAN_FILE_REMOVE_CODE=""
    JSPBEAN_UPLOAD_HANDLER_MARK=""

    if [ -n "$file_fields" ]; then
        JSPBEAN_FILE_IMPORTS="import fr.paris.lutece.portal.business.file.File;
import fr.paris.lutece.portal.business.file.FileHome;
import fr.paris.lutece.portal.business.physicalfile.PhysicalFile;
import fr.paris.lutece.portal.business.physicalfile.PhysicalFileHome;
import fr.paris.lutece.portal.service.upload.MultipartItem;
import fr.paris.lutece.plugins.asynchronousupload.service.IAsyncUploadHandler;
import fr.paris.lutece.plugins.genericattributes.business.GenAttFileItem;
import fr.paris.lutece.util.filesystem.FileSystemUtil;
"
        JSPBEAN_UPLOAD_HANDLER_MARK="
    private static final String MARK_UPLOAD_HANDLER = \"uploadHandler\";
"
        JSPBEAN_FILE_FIELDS="
    @Inject
    private IAsyncUploadHandler _uploadHandler;
"

        IFS=',' read -ra FILE_FIELDS_ARR <<< "$file_fields"
        for file_field in "${FILE_FIELDS_ARR[@]}"; do
            if [ -n "$file_field" ]; then
                local file_field_upper=$(echo "${file_field:0:1}" | tr '[:lower:]' '[:upper:]')${file_field:1}
                local file_field_param=$(echo "$file_field" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')

                JSPBEAN_FILE_CONSTANTS+="
    private static final String PARAMETER_UPLOAD_${file_field^^} = \"upload_${file_field_param}\";
"
                JSPBEAN_FILE_METHODS+="
    private File get${file_field_upper}FromRequest( HttpServletRequest request )
    {
        _uploadHandler.addFilesUploadedSynchronously( request, PARAMETER_UPLOAD_${file_field^^} );
        java.util.List<MultipartItem> listUploadedFileItems = _uploadHandler.getListUploadedFiles( PARAMETER_UPLOAD_${file_field^^}, request.getSession() );
        for ( MultipartItem fileItem : listUploadedFileItems )
        {
            if ( fileItem != null )
            {
                File file = new File();
                file.setTitle( fileItem.getName() );
                file.setSize( ( fileItem.getSize() < Integer.MAX_VALUE ) ? (int) fileItem.getSize() : Integer.MAX_VALUE );
                file.setMimeType( FileSystemUtil.getMIMEType( file.getTitle() ) );

                PhysicalFile physicalFile = new PhysicalFile();
                physicalFile.setValue( fileItem.get() );
                file.setPhysicalFile( physicalFile );
                return file;
            }
        }
        return null;
    }
"
                JSPBEAN_FILE_CREATE_CODE+="
        _${entity_var}.set${file_field_upper}( get${file_field_upper}FromRequest( request ) );
        if ( _${entity_var}.get${file_field_upper}() != null )
        {
            FileHome.create( _${entity_var}.get${file_field_upper}() );
        }
"
                JSPBEAN_FILE_MODIFY_CODE+="
        if ( _${entity_var}.get${file_field_upper}() != null )
        {
            FileHome.remove( _${entity_var}.get${file_field_upper}().getIdFile() );
            _${entity_var}.set${file_field_upper}( null );
        }
        _${entity_var}.set${file_field_upper}( get${file_field_upper}FromRequest( request ) );
        if ( _${entity_var}.get${file_field_upper}() != null )
        {
            FileHome.create( _${entity_var}.get${file_field_upper}() );
        }
"
                JSPBEAN_FILE_MODIFY_LOAD_CODE+="
        if ( _${entity_var}.get${file_field_upper}() != null )
        {
            File ${file_field} = FileHome.findByPrimaryKey( _${entity_var}.get${file_field_upper}().getIdFile() );
            if ( ${file_field} != null && ${file_field}.getPhysicalFile() != null )
            {
                PhysicalFile physicalFile = PhysicalFileHome.findByPrimaryKey( ${file_field}.getPhysicalFile().getIdPhysicalFile() );
                if ( physicalFile != null )
                {
                    MultipartItem fileItem = new GenAttFileItem( physicalFile.getValue(), ${file_field}.getTitle() );
                    _uploadHandler.addFileItemToUploadedFilesList( fileItem, PARAMETER_UPLOAD_${file_field^^}, request );
                }
            }
        }
"
                JSPBEAN_FILE_REMOVE_CODE+="
        ${entity_name} ${entity_var}ToRemove = ${entity_name}Home.findByPrimaryKey( nId );
        if ( ${entity_var}ToRemove != null && ${entity_var}ToRemove.get${file_field_upper}() != null )
        {
            FileHome.remove( ${entity_var}ToRemove.get${file_field_upper}().getIdFile() );
        }
"
            fi
        done
    fi
}

scaffold_build_workflow_code() {
    local entity_name="$1"
    local entity_var="$2"
    local entity_lower="$3"
    local parent_entity="$4"

    JSPBEAN_WF_IMPORTS=""
    JSPBEAN_WF_CONSTANTS=""
    JSPBEAN_WF_FIELDS=""
    JSPBEAN_WF_METHODS=""
    JSPBEAN_WF_MANAGE_CODE=""
    JSPBEAN_WF_MANAGE_MODEL=""
    JSPBEAN_WF_CREATE_CODE=""
    JSPBEAN_WF_CREATE_VIEW_MODEL=""
    JSPBEAN_WF_MODIFY_MODEL=""
    JSPBEAN_WF_REMOVE_CODE=""
    JSPBEAN_WF_ACTION_METHOD=""

    # Only generate workflow code for ROOT entities (no parent)
    if [ "$FEATURE_WORKFLOW" != "true" ] || [ -n "$parent_entity" ]; then
        return
    fi

    # Use WorkflowService directly (Forms pattern - per-entity workflow)
    JSPBEAN_WF_IMPORTS="import fr.paris.lutece.plugins.workflowcore.business.state.State;
import fr.paris.lutece.portal.service.workflow.WorkflowService;
import fr.paris.lutece.portal.business.user.AdminUser;
import fr.paris.lutece.util.ReferenceList;
import java.util.Collection;
import java.util.HashMap;
"

    JSPBEAN_WF_CONSTANTS="
    private static final String PARAMETER_ID_ACTION = \"id_action\";
    private static final String MARK_WORKFLOW_STATE = \"workflow_state\";
    private static final String MARK_WORKFLOW_ACTIONS = \"workflow_actions\";
    private static final String MARK_WORKFLOW_STATES_MAP = \"workflow_states_map\";
    private static final String MARK_WORKFLOW_ACTIONS_MAP = \"workflow_actions_map\";
    private static final String MARK_WORKFLOW_ENABLED = \"workflow_enabled\";
    private static final String MARK_WORKFLOW_REF_LIST = \"workflow_list\";
    private static final String ACTION_WORKFLOW = \"doWorkflowAction\";
"

    JSPBEAN_WF_FIELDS="
    @Inject
    private WorkflowService _workflowService;
"

    JSPBEAN_WF_METHODS="
    private boolean isWorkflowServiceAvailable()
    {
        return _workflowService.isAvailable();
    }

    private boolean isWorkflowEnabled( ${entity_name} ${entity_var} )
    {
        return isWorkflowServiceAvailable() && ${entity_var} != null && ${entity_var}.getIdWorkflow() > 0;
    }
"

    JSPBEAN_WF_MANAGE_CODE="
        _models.put( MARK_WORKFLOW_ENABLED, isWorkflowServiceAvailable() );

        if ( isWorkflowServiceAvailable() )
        {
            Map<String, State> statesMap = new HashMap<>();
            Map<String, Collection<fr.paris.lutece.plugins.workflowcore.business.action.Action>> actionsMap = new HashMap<>();

            for ( ${entity_name} ${entity_var} : paginator.getPageItems() )
            {
                if ( ${entity_var}.getIdWorkflow() > 0 )
                {
                    State state = _workflowService.getState( ${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, ${entity_var}.getIdWorkflow(), null );
                    if ( state != null )
                    {
                        statesMap.put( String.valueOf( ${entity_var}.getId${entity_name}() ), state );
                    }
                    Collection<fr.paris.lutece.plugins.workflowcore.business.action.Action> actions =
                        _workflowService.getActions( ${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, ${entity_var}.getIdWorkflow(), getUser() );
                    actionsMap.put( String.valueOf( ${entity_var}.getId${entity_name}() ), actions );
                }
            }

            _models.put( MARK_WORKFLOW_STATES_MAP, statesMap );
            _models.put( MARK_WORKFLOW_ACTIONS_MAP, actionsMap );
        }
"

    JSPBEAN_WF_CREATE_VIEW_MODEL="
        if ( isWorkflowServiceAvailable() )
        {
            AdminUser adminUser = getUser();
            ReferenceList workflowList = _workflowService.getWorkflowsEnabled( adminUser, getLocale() );
            _models.put( MARK_WORKFLOW_REF_LIST, workflowList );
        }
"

    JSPBEAN_WF_CREATE_CODE="
        if ( isWorkflowEnabled( _${entity_var} ) )
        {
            _workflowService.getState( _${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, _${entity_var}.getIdWorkflow(), null );
        }
"

    JSPBEAN_WF_MODIFY_MODEL="
        if ( isWorkflowServiceAvailable() )
        {
            AdminUser adminUser = getUser();
            ReferenceList workflowList = _workflowService.getWorkflowsEnabled( adminUser, getLocale() );
            _models.put( MARK_WORKFLOW_REF_LIST, workflowList );
        }

        _models.put( MARK_WORKFLOW_ENABLED, isWorkflowEnabled( _${entity_var} ) );

        if ( isWorkflowEnabled( _${entity_var} ) )
        {
            State state = _workflowService.getState( _${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, _${entity_var}.getIdWorkflow(), null );
            Collection<fr.paris.lutece.plugins.workflowcore.business.action.Action> actions =
                _workflowService.getActions( _${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, _${entity_var}.getIdWorkflow(), getUser() );

            _models.put( MARK_WORKFLOW_STATE, state );
            _models.put( MARK_WORKFLOW_ACTIONS, actions );
        }
"

    JSPBEAN_WF_REMOVE_CODE="
        if ( isWorkflowServiceAvailable() )
        {
            _workflowService.doRemoveWorkFlowResource( nId, ${entity_name}.RESOURCE_TYPE );
        }
"

    JSPBEAN_WF_ACTION_METHOD="
    @Action( ACTION_WORKFLOW )
    public String doWorkflowAction( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID ) );
        int nIdAction = Integer.parseInt( request.getParameter( PARAMETER_ID_ACTION ) );

        ${entity_name} ${entity_var} = _${entity_var}Service.findByPrimaryKey( nId );

        if ( ${entity_var} != null && isWorkflowEnabled( ${entity_var} ) )
        {
            _workflowService.doProcessAction( nId, ${entity_name}.RESOURCE_TYPE, nIdAction, null, request, getLocale(), false, getUser() );
        }

        return redirectView( request, VIEW_MANAGE );
    }
"
}

scaffold_generate_jspbean() {
    local plugin_dir="$1"
    local config_file="$2"

    echo "[6/9] Generating JSPBean..."

    local entity_count=$(jq '.entities | length' "$config_file")

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        local entity_var=$(echo "${entity_name:0:1}" | tr '[:upper:]' '[:lower:]')${entity_name:1}
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        local parent_entity_lower=""
        local parent_entity_var=""
        [ -n "$parent_entity" ] && parent_entity_lower=$(echo "$parent_entity" | tr '[:upper:]' '[:lower:]')
        [ -n "$parent_entity" ] && parent_entity_var=$(echo "${parent_entity:0:1}" | tr '[:upper:]' '[:lower:]')${parent_entity:1}

        local entity_has_files=false
        local entity_file_fields=""
        local field_count=$(jq ".entities[$i].fields | length" "$config_file")

        for ((j=0; j<field_count; j++)); do
            local field_type=$(jq -r ".entities[$i].fields[$j].type" "$config_file")
            local field_name=$(jq -r ".entities[$i].fields[$j].name" "$config_file")
            if [ "$field_type" == "file" ] || [ "$field_type" == "File" ]; then
                entity_has_files=true
                entity_file_fields+="$field_name,"
            fi
        done

        scaffold_build_file_handling_code "$entity_var" "$entity_file_fields"
        scaffold_build_workflow_code "$entity_name" "$entity_var" "$entity_lower" "$parent_entity"

        local upload_handler_model=""
        [ "$entity_has_files" = true ] && upload_handler_model="        _models.put( MARK_UPLOAD_HANDLER, _uploadHandler );"

        local parent_imports=""
        local parent_constants=""
        local parent_field=""
        local parent_id_field=""
        local manage_list_code=""
        local manage_model_parent=""
        local create_parent_init=""
        local create_view_parent_check=""
        local create_view_parent_model=""
        local parent_redirect=""
        local paginator_url_parent=""

        if [ -n "$parent_entity" ]; then
            parent_imports="import $PACKAGE_BASE.business.${parent_entity};
import $PACKAGE_BASE.business.${parent_entity}Home;
"
            parent_constants="
    private static final String PARAMETER_ID_${parent_entity^^} = \"id${parent_entity}\";
    private static final String MARK_PARENT = \"${parent_entity_lower}\";
    private static final String MARK_ID_${parent_entity^^} = \"id${parent_entity}\";"
            parent_field="
    private int _nId${parent_entity};"
            parent_id_field="        int nId${parent_entity} = _nId${parent_entity};"
            manage_list_code="        String strId${parent_entity} = request.getParameter( PARAMETER_ID_${parent_entity^^} );
        if ( strId${parent_entity} != null )
        {
            _nId${parent_entity} = Integer.parseInt( strId${parent_entity} );
        }
        List<$entity_name> listAll = ${entity_name}Home.findBy${parent_entity}Id( _nId${parent_entity} );
        ${parent_entity} ${parent_entity_var} = ${parent_entity}Home.findByPrimaryKey( _nId${parent_entity} );"
            manage_model_parent="        _models.put( MARK_PARENT, ${parent_entity_var} );
        _models.put( MARK_ID_${parent_entity^^}, _nId${parent_entity} );"
            create_parent_init="        _${entity_var}.setId${parent_entity}( _nId${parent_entity} );"
            create_view_parent_check="        String strId${parent_entity} = request.getParameter( PARAMETER_ID_${parent_entity^^} );
        if ( strId${parent_entity} != null )
        {
            _nId${parent_entity} = Integer.parseInt( strId${parent_entity} );
        }"
            create_view_parent_model="        _models.put( MARK_ID_${parent_entity^^}, _nId${parent_entity} );"
            parent_redirect="+ \"&id${parent_entity}=\" + _nId${parent_entity}"
            paginator_url_parent="
        url.addParameter( PARAMETER_ID_${parent_entity^^}, _nId${parent_entity} );"
        else
            manage_list_code="        List<$entity_name> listAll = ${entity_name}Home.findAll();"
            parent_redirect=""
            paginator_url_parent=""
        fi

        local jsp_path="jsp/admin/plugins/$PLUGIN_NAME/Manage${entity_name}s.jsp"

        cat > "$plugin_dir/src/java/$PACKAGE_PATH/web/${entity_name}JspBean.java" << JSPBEANEOF
package $PACKAGE_BASE.web;

${JSPBEAN_FILE_IMPORTS}${JSPBEAN_WF_IMPORTS}${parent_imports}import fr.paris.lutece.portal.service.message.AdminMessage;
import fr.paris.lutece.portal.service.message.AdminMessageService;
import fr.paris.lutece.portal.util.mvc.admin.annotations.Controller;
import fr.paris.lutece.portal.util.mvc.commons.annotations.Action;
import fr.paris.lutece.portal.util.mvc.commons.annotations.RequestParam;
import fr.paris.lutece.portal.util.mvc.commons.annotations.ResponseBody;
import fr.paris.lutece.portal.util.mvc.commons.annotations.View;
import fr.paris.lutece.portal.util.mvc.admin.MVCAdminJspBean;
import fr.paris.lutece.portal.web.cdi.mvc.Models;
import fr.paris.lutece.portal.web.util.IPager;
import fr.paris.lutece.portal.web.util.Pager;
import fr.paris.lutece.util.url.UrlItem;
import $PACKAGE_BASE.business.${entity_name};
import $PACKAGE_BASE.business.${entity_name}Home;
import $PACKAGE_BASE.service.${entity_name}Service;
import jakarta.enterprise.context.SessionScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;

@SessionScoped
@Named
@Controller( controllerJsp = "Manage${entity_name}s.jsp", controllerPath = "jsp/admin/plugins/$PLUGIN_NAME/", right = "${PLUGIN_NAME^^}_MANAGEMENT" )
public class ${entity_name}JspBean extends MVCAdminJspBean
{
    private static final long serialVersionUID = 1L;

    private static final String TEMPLATE_MANAGE = "/admin/plugins/$PLUGIN_NAME/manage_${entity_lower}s.html";
    private static final String TEMPLATE_CREATE = "/admin/plugins/$PLUGIN_NAME/create_${entity_lower}.html";
    private static final String TEMPLATE_MODIFY = "/admin/plugins/$PLUGIN_NAME/modify_${entity_lower}.html";

    private static final String PARAMETER_ID = "id";

    private static final String PROPERTY_PAGE_TITLE_MANAGE = "$PLUGIN_NAME.manage_${entity_lower}s.pageTitle";
    private static final String PROPERTY_PAGE_TITLE_CREATE = "$PLUGIN_NAME.create_${entity_lower}.pageTitle";
    private static final String PROPERTY_PAGE_TITLE_MODIFY = "$PLUGIN_NAME.modify_${entity_lower}.pageTitle";

    private static final String MARK_LIST = "${entity_lower}_list";
    private static final String MARK_ENTITY = "$entity_lower";
${JSPBEAN_UPLOAD_HANDLER_MARK}${parent_constants}
    private static final String VIEW_MANAGE = "manage${entity_name}s";
    private static final String VIEW_CREATE = "create${entity_name}";
    private static final String VIEW_MODIFY = "modify${entity_name}";

    private static final String ACTION_CREATE = "create${entity_name}";
    private static final String ACTION_MODIFY = "modify${entity_name}";
    private static final String ACTION_REMOVE = "remove${entity_name}";
    private static final String ACTION_CONFIRM_REMOVE = "confirmRemove${entity_name}";
    private static final String ACTION_GET_ITEMS = "get${entity_name}Items";
${JSPBEAN_WF_CONSTANTS}
    private static final String MSG_CONFIRM_REMOVE = "$PLUGIN_NAME.message.confirm_remove_${entity_lower}";

${JSPBEAN_FILE_CONSTANTS}
    @Inject
    private ${entity_name}Service _${entity_var}Service;
    @Inject
    private Models _models;
    @Inject
    @Pager( name = "${entity_lower}List", listBookmark = MARK_LIST,
            defaultItemsPerPage = "$PLUGIN_NAME.${entity_lower}.itemsPerPage",
            baseUrl = "$jsp_path" )
    private IPager<${entity_name}, ${entity_name}> _pager;
${JSPBEAN_WF_FIELDS}

    private $entity_name _$entity_var;
${JSPBEAN_FILE_FIELDS}${parent_field}

    @View( value = VIEW_MANAGE, defaultView = true )
    public String getManage${entity_name}s( HttpServletRequest request )
    {
$manage_list_code

        var paginator = _pager.withListItem( listAll )
              .populateModels( request, _models, getLocale( ) );
$manage_model_parent
${JSPBEAN_WF_MANAGE_CODE}
        return getPage( PROPERTY_PAGE_TITLE_MANAGE, TEMPLATE_MANAGE );
    }

    @Action( value = ACTION_GET_ITEMS )
    @ResponseBody
    public List<${entity_name}> get${entity_name}Items( @RequestParam( "page" ) int numPage )
    {
        return _pager.getPaginator( ).get( ).getPageItems( numPage );
    }

    @View( VIEW_CREATE )
    public String getCreate${entity_name}( HttpServletRequest request )
    {
        _$entity_var = new ${entity_name}();
$create_view_parent_check
        _models.put( MARK_ENTITY, _$entity_var );
$create_view_parent_model$upload_handler_model
${JSPBEAN_WF_CREATE_VIEW_MODEL}
        return getPage( PROPERTY_PAGE_TITLE_CREATE, TEMPLATE_CREATE );
    }

    @Action( ACTION_CREATE )
    public String doCreate${entity_name}( HttpServletRequest request )
    {
        populate( _$entity_var, request );
$create_parent_init${JSPBEAN_FILE_CREATE_CODE}
        _${entity_var}Service.create( _$entity_var );
${JSPBEAN_WF_CREATE_CODE}
        return redirectView( request, VIEW_MANAGE $parent_redirect );
    }

    @View( VIEW_MODIFY )
    public String getModify${entity_name}( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID ) );
        _$entity_var = _${entity_var}Service.findByPrimaryKey( nId );
${JSPBEAN_FILE_MODIFY_LOAD_CODE}
        _models.put( MARK_ENTITY, _$entity_var );
$upload_handler_model
${JSPBEAN_WF_MODIFY_MODEL}
        return getPage( PROPERTY_PAGE_TITLE_MODIFY, TEMPLATE_MODIFY );
    }

    @Action( ACTION_MODIFY )
    public String doModify${entity_name}( HttpServletRequest request )
    {
$parent_id_field
        populate( _$entity_var, request );
${JSPBEAN_FILE_MODIFY_CODE}
        _${entity_var}Service.update( _$entity_var );

        return redirectView( request, VIEW_MANAGE $parent_redirect );
    }

    @Action( ACTION_CONFIRM_REMOVE )
    public String getConfirmRemove${entity_name}( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID ) );
        UrlItem url = new UrlItem( getActionUrl( ACTION_REMOVE ) );
        url.addParameter( PARAMETER_ID, nId );

        return redirect( request, AdminMessageService.getMessageUrl( request, MSG_CONFIRM_REMOVE, url.getUrl(), AdminMessage.TYPE_CONFIRMATION ) );
    }

    @Action( ACTION_REMOVE )
    public String doRemove${entity_name}( HttpServletRequest request )
    {
        int nId = Integer.parseInt( request.getParameter( PARAMETER_ID ) );
${JSPBEAN_WF_REMOVE_CODE}${JSPBEAN_FILE_REMOVE_CODE}
        _${entity_var}Service.remove( nId );

        return redirectView( request, VIEW_MANAGE $parent_redirect );
    }
${JSPBEAN_FILE_METHODS}${JSPBEAN_WF_ACTION_METHOD}${JSPBEAN_WF_METHODS}
}
JSPBEANEOF

        local entity_var_lower=$(echo "${entity_name:0:1}" | tr '[:upper:]' '[:lower:]')${entity_name:1}
        cat > "$plugin_dir/webapp/jsp/admin/plugins/$PLUGIN_NAME/Manage${entity_name}s.jsp" << JSPEOF
<%@ page errorPage="../../ErrorPage.jsp" %>

\${ pageContext.setAttribute( 'strContent', ${entity_var_lower}JspBean.processController( pageContext.request , pageContext.response ) ) }

<jsp:include page="../../AdminHeader.jsp" />

\${ pageContext.getAttribute( 'strContent' ) }

<%@ include file="../../AdminFooter.jsp" %>
JSPEOF

    done
}
