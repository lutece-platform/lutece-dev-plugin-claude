#!/bin/bash

# =============================================================================
# Lutece Workflow Module Scaffold Generator
# Generates workflow modules for Lutece 8 plugins
# =============================================================================

scaffold_generate_workflow_module() {
    local parent_dir="$1"
    local config_file="$2"

    if [ "$FEATURE_WORKFLOW" != "true" ]; then
        return
    fi

    echo ""
    echo "=== Generating Workflow Module ==="

    local module_name="module-workflow-${PLUGIN_NAME}"
    local module_dir="$parent_dir/$module_name"
    local module_package="fr.paris.lutece.plugins.workflow.modules.${PLUGIN_NAME}"
    local module_package_path=$(echo "$module_package" | tr '.' '/')

    mkdir -p "$module_dir"

    # Create directory structure
    scaffold_workflow_create_directories "$module_dir" "$module_package_path"

    # Generate files
    scaffold_workflow_generate_pom "$module_dir" "$config_file"
    scaffold_workflow_generate_beans_xml "$module_dir"
    scaffold_workflow_generate_plugin_xml "$module_dir" "$config_file"
    scaffold_workflow_generate_properties "$module_dir" "$config_file"

    # Generate workflow wrapper service (like FormWorkflowService)
    scaffold_workflow_generate_wrapper_service "$module_dir" "$module_package" "$module_package_path" "$config_file"

    # Generate tasks only for ROOT entities (no parent)
    local entity_count=$(jq '.entities | length' "$config_file")
    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        # Only generate workflow task for root entities
        if [ -z "$parent_entity" ]; then
            scaffold_workflow_generate_task "$module_dir" "$module_package" "$module_package_path" "$entity_name" "$config_file"
        fi
    done

    # Generate combined SQL for all entities
    scaffold_workflow_generate_all_sql "$module_dir" "$config_file"

    # Generate init SQL with sample workflow data
    scaffold_workflow_generate_init_sql "$module_dir" "$config_file"

    # Generate i18n
    scaffold_workflow_generate_i18n "$module_dir" "$config_file"

    echo "Workflow module generated: $module_dir"
}

scaffold_workflow_create_directories() {
    local module_dir="$1"
    local package_path="$2"

    echo "[WF 1/8] Creating workflow module directories..."

    mkdir -p "$module_dir/src/java/$package_path/business"
    mkdir -p "$module_dir/src/java/$package_path/service"
    mkdir -p "$module_dir/src/java/$package_path/web"
    mkdir -p "$module_dir/src/sql/plugins/workflow/modules/${PLUGIN_NAME}/plugin"
    mkdir -p "$module_dir/src/main/resources/META-INF"
    mkdir -p "$module_dir/webapp/WEB-INF/conf/plugins"
    mkdir -p "$module_dir/webapp/WEB-INF/plugins"
    mkdir -p "$module_dir/webapp/WEB-INF/templates/admin/plugins/workflow/modules/${PLUGIN_NAME}"
}

scaffold_workflow_generate_pom() {
    local module_dir="$1"
    local config_file="$2"

    echo "[WF 2/8] Generating workflow module pom.xml..."

    cat > "$module_dir/pom.xml" << POMEOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>module-workflow-${PLUGIN_NAME}</artifactId>
    <packaging>lutece-plugin</packaging>
    <version>1.0.0-SNAPSHOT</version>
    <name>Lutece Workflow Module for ${PLUGIN_NAME}</name>

    <parent>
        <artifactId>lutece-global-pom</artifactId>
        <groupId>fr.paris.lutece.tools</groupId>
        <version>8.0.0-SNAPSHOT</version>
    </parent>

    <dependencies>
        <dependency>
            <groupId>fr.paris.lutece</groupId>
            <artifactId>lutece-core</artifactId>
            <version>[8.0.0-SNAPSHOT,)</version>
            <type>lutece-core</type>
        </dependency>
        <dependency>
            <groupId>fr.paris.lutece.plugins</groupId>
            <artifactId>plugin-workflow</artifactId>
            <version>[7.0.0-SNAPSHOT,)</version>
            <type>lutece-plugin</type>
        </dependency>
        <dependency>
            <groupId>fr.paris.lutece.plugins</groupId>
            <artifactId>library-workflow-core</artifactId>
            <version>[4.0.0-SNAPSHOT,)</version>
        </dependency>
        <dependency>
            <groupId>fr.paris.lutece.plugins</groupId>
            <artifactId>plugin-${PLUGIN_NAME}</artifactId>
            <version>[1.0.0-SNAPSHOT,)</version>
            <type>lutece-plugin</type>
        </dependency>
    </dependencies>

    <repositories>
        <repository>
            <id>lutece</id>
            <url>https://dev.lutece.paris.fr/maven_repository</url>
        </repository>
        <repository>
            <id>luteceSnapshot</id>
            <url>https://dev.lutece.paris.fr/snapshot_repository</url>
        </repository>
    </repositories>
</project>
POMEOF
}

scaffold_workflow_generate_beans_xml() {
    local module_dir="$1"

    echo "[WF 3/8] Generating beans.xml..."

    cat > "$module_dir/src/main/resources/META-INF/beans.xml" << 'BEANSEOF'
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0"
       bean-discovery-mode="annotated">
</beans>
BEANSEOF
}

scaffold_workflow_generate_plugin_xml() {
    local module_dir="$1"
    local config_file="$2"

    echo "[WF 4/8] Generating workflow-${PLUGIN_NAME}.xml..."

    cat > "$module_dir/webapp/WEB-INF/plugins/workflow-${PLUGIN_NAME}.xml" << PLUGINEOF
<?xml version="1.0" encoding="UTF-8"?>
<plug-in>
    <name>workflow-${PLUGIN_NAME}</name>
    <class>fr.paris.lutece.portal.service.plugin.PluginDefaultImplementation</class>
    <version>1.0.0-SNAPSHOT</version>
    <documentation/>
    <installation/>
    <changes/>
    <user-guide/>
    <description>module.workflow.${PLUGIN_NAME}.plugin.description</description>
    <provider>Ville de Paris</provider>
    <provider-url>http://lutece.paris.fr</provider-url>
    <icon-url>images/admin/skin/feature_default_icon.png</icon-url>
    <copyright>Copyright (c) 2025</copyright>
    <db-pool-required>1</db-pool-required>

    <core-version-dependency>
        <min-core-version>8.0.0</min-core-version>
        <max-core-version/>
    </core-version-dependency>
</plug-in>
PLUGINEOF
}

scaffold_workflow_generate_properties() {
    local module_dir="$1"
    local config_file="$2"

    echo "[WF 5/8] Generating workflow-${PLUGIN_NAME}.properties..."

    local props_content=""
    local entity_count=$(jq '.entities | length' "$config_file")

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        # Only generate for root entities
        if [ -n "$parent_entity" ]; then
            continue
        fi
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        local task_key="task${entity_name}StateChange"

        props_content+="# Task ${entity_name} State Change
workflow-${PLUGIN_NAME}.${task_key}.key=${task_key}
workflow-${PLUGIN_NAME}.${task_key}.titleI18nKey=module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.title
workflow-${PLUGIN_NAME}.${task_key}.beanName=workflow-${PLUGIN_NAME}.task${entity_name}StateChange
workflow-${PLUGIN_NAME}.${task_key}.configBeanName=workflow-${PLUGIN_NAME}.task${entity_name}StateChangeConfig
workflow-${PLUGIN_NAME}.${task_key}.configRequired=true
workflow-${PLUGIN_NAME}.${task_key}.formTaskRequired=false
workflow-${PLUGIN_NAME}.${task_key}.taskForAutomaticAction=true

"
    done

    cat > "$module_dir/webapp/WEB-INF/conf/plugins/workflow-${PLUGIN_NAME}.properties" << PROPSEOF
# =============================================================================
# Workflow Module ${PLUGIN_NAME} - Task Types Configuration
# =============================================================================

$props_content
PROPSEOF
}

scaffold_workflow_generate_wrapper_service() {
    local module_dir="$1"
    local module_package="$2"
    local module_package_path="$3"
    local config_file="$4"

    echo "[WF 5.5/8] Generating workflow wrapper service..."

    local plugin_cap=$(echo "${PLUGIN_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${PLUGIN_NAME:1}
    local service_dir="$module_dir/src/java/$module_package_path/service"

    # Generate interface
    local entity_count=$(jq '.entities | length' "$config_file")
    local interface_methods=""
    local impl_imports=""
    local impl_methods=""

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        # Only generate for root entities
        if [ -n "$parent_entity" ]; then
            continue
        fi
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        local entity_var=$(echo "${entity_name:0:1}" | tr '[:upper:]' '[:lower:]')${entity_name:1}

        impl_imports+="import ${PACKAGE_BASE}.business.${entity_name};
"

        interface_methods+="
    /**
     * Initialize workflow state for a new ${entity_lower}
     * @param ${entity_var} the ${entity_lower}
     */
    void initWorkflowState( ${entity_name} ${entity_var} );

    /**
     * Get the current workflow state for a ${entity_lower}
     * @param ${entity_var} the ${entity_lower}
     * @return the current state or null
     */
    State getState( ${entity_name} ${entity_var} );

    /**
     * Get available actions for a ${entity_lower}
     * @param ${entity_var} the ${entity_lower}
     * @param user the admin user
     * @return collection of available actions
     */
    Collection<Action> getActions( ${entity_name} ${entity_var}, AdminUser user );

    /**
     * Execute a workflow action on a ${entity_lower}
     * @param ${entity_var} the ${entity_lower}
     * @param nIdAction the action id
     * @param request the HTTP request
     * @param locale the locale
     * @param user the admin user
     */
    void doProcessAction( ${entity_name} ${entity_var}, int nIdAction, HttpServletRequest request, Locale locale, AdminUser user );

    /**
     * Remove workflow resources for a ${entity_lower}
     * @param ${entity_var} the ${entity_lower}
     */
    void removeWorkflowResource( ${entity_name} ${entity_var} );
"

        impl_methods+="
    // ========== ${entity_name^^} WORKFLOW METHODS ==========

    @Override
    public void initWorkflowState( ${entity_name} ${entity_var} )
    {
        if ( isAvailable() && ${entity_var}.getIdWorkflow() > 0 )
        {
            _workflowService.getState( ${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, ${entity_var}.getIdWorkflow(), null );
        }
    }

    @Override
    public State getState( ${entity_name} ${entity_var} )
    {
        if ( isAvailable() && ${entity_var}.getIdWorkflow() > 0 )
        {
            return _workflowService.getState( ${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, ${entity_var}.getIdWorkflow(), null );
        }
        return null;
    }

    @Override
    public Collection<Action> getActions( ${entity_name} ${entity_var}, AdminUser user )
    {
        if ( isAvailable() && ${entity_var}.getIdWorkflow() > 0 )
        {
            return _workflowService.getActions( ${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, ${entity_var}.getIdWorkflow(), user );
        }
        return Collections.emptyList();
    }

    @Override
    public void doProcessAction( ${entity_name} ${entity_var}, int nIdAction, HttpServletRequest request, Locale locale, AdminUser user )
    {
        if ( isAvailable() && ${entity_var}.getIdWorkflow() > 0 )
        {
            _workflowService.doProcessAction( ${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE, nIdAction, null, request, locale, false, user );
        }
    }

    @Override
    public void removeWorkflowResource( ${entity_name} ${entity_var} )
    {
        if ( isAvailable() )
        {
            _workflowService.doRemoveWorkFlowResource( ${entity_var}.getId${entity_name}(), ${entity_name}.RESOURCE_TYPE );
        }
    }
"
    done

    # Generate interface
    cat > "$service_dir/I${plugin_cap}WorkflowService.java" << INTERFACEEOF
package ${module_package}.service;

${impl_imports}import fr.paris.lutece.plugins.workflowcore.business.action.Action;
import fr.paris.lutece.plugins.workflowcore.business.state.State;
import fr.paris.lutece.portal.business.user.AdminUser;

import jakarta.servlet.http.HttpServletRequest;

import java.util.Collection;
import java.util.Locale;

/**
 * Interface for ${PLUGIN_NAME} workflow service
 */
public interface I${plugin_cap}WorkflowService
{
    /**
     * Check if workflow is available
     * @return true if workflow is available
     */
    boolean isAvailable();
${interface_methods}}
INTERFACEEOF

    # Generate implementation
    cat > "$service_dir/${plugin_cap}WorkflowService.java" << IMPLEOF
package ${module_package}.service;

${impl_imports}import fr.paris.lutece.plugins.workflowcore.business.action.Action;
import fr.paris.lutece.plugins.workflowcore.business.state.State;
import fr.paris.lutece.portal.business.user.AdminUser;
import fr.paris.lutece.portal.service.workflow.WorkflowService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;

import java.util.Collection;
import java.util.Collections;
import java.util.Locale;

/**
 * Workflow service for ${PLUGIN_NAME} entities
 */
@ApplicationScoped
@Named( "workflow-${PLUGIN_NAME}.workflowService" )
public class ${plugin_cap}WorkflowService implements I${plugin_cap}WorkflowService
{
    @Inject
    private WorkflowService _workflowService;

    @Override
    public boolean isAvailable()
    {
        return _workflowService != null && _workflowService.isAvailable();
    }
${impl_methods}}
IMPLEOF

    echo "  - I${plugin_cap}WorkflowService (interface)"
    echo "  - ${plugin_cap}WorkflowService (implementation)"
}

scaffold_workflow_generate_task() {
    local module_dir="$1"
    local module_package="$2"
    local module_package_path="$3"
    local entity_name="$4"
    local config_file="$5"

    local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')

    echo "[WF 6/8] Generating workflow task for ${entity_name}..."

    # Generate Task Config
    scaffold_workflow_generate_task_config "$module_dir" "$module_package" "$module_package_path" "$entity_name"

    # Generate Task Config DAO
    scaffold_workflow_generate_task_config_dao "$module_dir" "$module_package" "$module_package_path" "$entity_name"

    # Generate Task Implementation
    scaffold_workflow_generate_task_impl "$module_dir" "$module_package" "$module_package_path" "$entity_name"

    # Generate Task Type Producer
    scaffold_workflow_generate_task_type_producer "$module_dir" "$module_package" "$module_package_path" "$entity_name"

    # Generate Task Config Service Producer
    scaffold_workflow_generate_config_service_producer "$module_dir" "$module_package" "$module_package_path" "$entity_name"

    # Generate Task Component
    scaffold_workflow_generate_task_component "$module_dir" "$module_package" "$module_package_path" "$entity_name"

    # Generate Templates
    scaffold_workflow_generate_templates "$module_dir" "$entity_name"
}

scaffold_workflow_generate_task_config() {
    local module_dir="$1"
    local module_package="$2"
    local module_package_path="$3"
    local entity_name="$4"

    cat > "$module_dir/src/java/$module_package_path/business/Task${entity_name}StateChangeConfig.java" << CONFIGEOF
package ${module_package}.business;

import fr.paris.lutece.plugins.workflowcore.business.config.TaskConfig;

/**
 * Configuration for ${entity_name} state change task
 */
public class Task${entity_name}StateChangeConfig extends TaskConfig
{
    private String _strTargetState;
    private String _strMessage;
    private boolean _bNotifyUser;

    public String getTargetState( )
    {
        return _strTargetState;
    }

    public void setTargetState( String strTargetState )
    {
        _strTargetState = strTargetState;
    }

    public String getMessage( )
    {
        return _strMessage;
    }

    public void setMessage( String strMessage )
    {
        _strMessage = strMessage;
    }

    public boolean isNotifyUser( )
    {
        return _bNotifyUser;
    }

    public void setNotifyUser( boolean bNotifyUser )
    {
        _bNotifyUser = bNotifyUser;
    }
}
CONFIGEOF
}

scaffold_workflow_generate_task_config_dao() {
    local module_dir="$1"
    local module_package="$2"
    local module_package_path="$3"
    local entity_name="$4"

    local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')

    cat > "$module_dir/src/java/$module_package_path/business/Task${entity_name}StateChangeConfigDAO.java" << DAOEOF
package ${module_package}.business;

import fr.paris.lutece.plugins.workflowcore.business.config.ITaskConfigDAO;
import fr.paris.lutece.util.sql.DAOUtil;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Named;

/**
 * DAO for Task${entity_name}StateChangeConfig
 */
@ApplicationScoped
@Named( "workflow-${PLUGIN_NAME}.task${entity_name}StateChangeConfigDAO" )
public class Task${entity_name}StateChangeConfigDAO implements ITaskConfigDAO<Task${entity_name}StateChangeConfig>
{
    private static final String SQL_QUERY_SELECT = "SELECT id_task, target_state, message, notify_user FROM workflow_task_${entity_lower}_statechange_config WHERE id_task = ?";
    private static final String SQL_QUERY_INSERT = "INSERT INTO workflow_task_${entity_lower}_statechange_config ( id_task, target_state, message, notify_user ) VALUES ( ?, ?, ?, ? )";
    private static final String SQL_QUERY_UPDATE = "UPDATE workflow_task_${entity_lower}_statechange_config SET target_state = ?, message = ?, notify_user = ? WHERE id_task = ?";
    private static final String SQL_QUERY_DELETE = "DELETE FROM workflow_task_${entity_lower}_statechange_config WHERE id_task = ?";

    @Override
    public void insert( Task${entity_name}StateChangeConfig config )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_INSERT ) )
        {
            int nIndex = 1;
            daoUtil.setInt( nIndex++, config.getIdTask( ) );
            daoUtil.setString( nIndex++, config.getTargetState( ) );
            daoUtil.setString( nIndex++, config.getMessage( ) );
            daoUtil.setBoolean( nIndex++, config.isNotifyUser( ) );
            daoUtil.executeUpdate( );
        }
    }

    @Override
    public void store( Task${entity_name}StateChangeConfig config )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_UPDATE ) )
        {
            int nIndex = 1;
            daoUtil.setString( nIndex++, config.getTargetState( ) );
            daoUtil.setString( nIndex++, config.getMessage( ) );
            daoUtil.setBoolean( nIndex++, config.isNotifyUser( ) );
            daoUtil.setInt( nIndex++, config.getIdTask( ) );
            daoUtil.executeUpdate( );
        }
    }

    @Override
    public Task${entity_name}StateChangeConfig load( int nIdTask )
    {
        Task${entity_name}StateChangeConfig config = null;

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECT ) )
        {
            daoUtil.setInt( 1, nIdTask );
            daoUtil.executeQuery( );

            if ( daoUtil.next( ) )
            {
                config = new Task${entity_name}StateChangeConfig( );
                int nIndex = 1;
                config.setIdTask( daoUtil.getInt( nIndex++ ) );
                config.setTargetState( daoUtil.getString( nIndex++ ) );
                config.setMessage( daoUtil.getString( nIndex++ ) );
                config.setNotifyUser( daoUtil.getBoolean( nIndex++ ) );
            }
        }

        return config;
    }

    @Override
    public void delete( int nIdTask )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_DELETE ) )
        {
            daoUtil.setInt( 1, nIdTask );
            daoUtil.executeUpdate( );
        }
    }
}
DAOEOF
}

scaffold_workflow_generate_task_impl() {
    local module_dir="$1"
    local module_package="$2"
    local module_package_path="$3"
    local entity_name="$4"

    local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')

    cat > "$module_dir/src/java/$module_package_path/service/Task${entity_name}StateChange.java" << TASKEOF
package ${module_package}.service;

import java.util.Locale;

import ${PACKAGE_BASE}.business.${entity_name};
import ${PACKAGE_BASE}.business.${entity_name}Home;
import ${module_package}.business.Task${entity_name}StateChangeConfig;
import fr.paris.lutece.plugins.workflowcore.business.resource.ResourceHistory;
import fr.paris.lutece.plugins.workflowcore.service.config.ITaskConfigService;
import fr.paris.lutece.plugins.workflowcore.service.resource.IResourceHistoryService;
import fr.paris.lutece.plugins.workflowcore.service.task.SimpleTask;
import fr.paris.lutece.api.user.User;
import fr.paris.lutece.portal.service.util.AppLogService;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;

/**
 * Task to change ${entity_name} state in workflow
 */
@Dependent
@Named( "workflow-${PLUGIN_NAME}.task${entity_name}StateChange" )
public class Task${entity_name}StateChange extends SimpleTask
{
    public static final String BEAN_CONFIG_SERVICE = "workflow-${PLUGIN_NAME}.task${entity_name}StateChangeConfigService";

    @Inject
    @Named( BEAN_CONFIG_SERVICE )
    private ITaskConfigService _taskConfigService;

    @Inject
    private IResourceHistoryService _resourceHistoryService;

    @Override
    public void processTask( int nIdResourceHistory, HttpServletRequest request, Locale locale, User user )
    {
        ResourceHistory resourceHistory = _resourceHistoryService.findByPrimaryKey( nIdResourceHistory );

        if ( resourceHistory == null )
        {
            AppLogService.error( "Task${entity_name}StateChange: ResourceHistory not found for id " + nIdResourceHistory );
            return;
        }

        Task${entity_name}StateChangeConfig config = _taskConfigService.findByPrimaryKey( this.getId( ) );

        if ( config == null )
        {
            AppLogService.error( "Task${entity_name}StateChange: Config not found for task " + this.getId( ) );
            return;
        }

        // Get the ${entity_name} from resource history
        ${entity_name} ${entity_lower} = ${entity_name}Home.findByPrimaryKey( resourceHistory.getIdResource( ) );

        if ( ${entity_lower} != null )
        {
            // Apply state change logic here
            // Example: update status, send notification, etc.
            AppLogService.info( "Task${entity_name}StateChange: Processing ${entity_name} id=" + ${entity_lower}.getId${entity_name}( )
                + " targetState=" + config.getTargetState( ) );

            if ( config.isNotifyUser( ) )
            {
                // Add notification logic here
                AppLogService.info( "Task${entity_name}StateChange: Would notify user with message: " + config.getMessage( ) );
            }

            // Update the entity if needed
            ${entity_name}Home.update( ${entity_lower} );
        }
    }

    @Override
    public String getTitle( Locale locale )
    {
        Task${entity_name}StateChangeConfig config = _taskConfigService.findByPrimaryKey( this.getId( ) );
        if ( config != null && config.getTargetState( ) != null )
        {
            return config.getTargetState( );
        }
        return "Task ${entity_name} State Change";
    }

    @Override
    public void doRemoveConfig( )
    {
        _taskConfigService.remove( this.getId( ) );
    }
}
TASKEOF
}

scaffold_workflow_generate_task_type_producer() {
    local module_dir="$1"
    local module_package="$2"
    local module_package_path="$3"
    local entity_name="$4"

    cat > "$module_dir/src/java/$module_package_path/service/TaskType${entity_name}StateChangeProducer.java" << PRODUCEREOF
package ${module_package}.service;

import fr.paris.lutece.plugins.workflowcore.business.task.ITaskType;
import fr.paris.lutece.plugins.workflowcore.business.task.TaskType;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * CDI Producer for ${entity_name} State Change Task Type
 */
@ApplicationScoped
public class TaskType${entity_name}StateChangeProducer
{
    @Produces
    @ApplicationScoped
    @Named( "workflow-${PLUGIN_NAME}.taskType${entity_name}StateChange" )
    public ITaskType produceTaskType${entity_name}StateChange(
        @ConfigProperty( name = "workflow-${PLUGIN_NAME}.task${entity_name}StateChange.key" ) String strKey,
        @ConfigProperty( name = "workflow-${PLUGIN_NAME}.task${entity_name}StateChange.titleI18nKey" ) String strTitleI18nKey,
        @ConfigProperty( name = "workflow-${PLUGIN_NAME}.task${entity_name}StateChange.beanName" ) String strBeanName,
        @ConfigProperty( name = "workflow-${PLUGIN_NAME}.task${entity_name}StateChange.configBeanName" ) String strConfigBeanName,
        @ConfigProperty( name = "workflow-${PLUGIN_NAME}.task${entity_name}StateChange.configRequired", defaultValue = "false" ) boolean bConfigRequired,
        @ConfigProperty( name = "workflow-${PLUGIN_NAME}.task${entity_name}StateChange.formTaskRequired", defaultValue = "false" ) boolean bFormTaskRequired,
        @ConfigProperty( name = "workflow-${PLUGIN_NAME}.task${entity_name}StateChange.taskForAutomaticAction", defaultValue = "false" ) boolean bTaskForAutomaticAction )
    {
        TaskType taskType = new TaskType( );
        taskType.setKey( strKey );
        taskType.setTitleI18nKey( strTitleI18nKey );
        taskType.setBeanName( strBeanName );
        taskType.setConfigBeanName( strConfigBeanName );
        taskType.setConfigRequired( bConfigRequired );
        taskType.setFormTaskRequired( bFormTaskRequired );
        taskType.setTaskForAutomaticAction( bTaskForAutomaticAction );
        return taskType;
    }
}
PRODUCEREOF
}

scaffold_workflow_generate_config_service_producer() {
    local module_dir="$1"
    local module_package="$2"
    local module_package_path="$3"
    local entity_name="$4"

    cat > "$module_dir/src/java/$module_package_path/service/Task${entity_name}StateChangeConfigServiceProducer.java" << CSPRODUCEREOF
package ${module_package}.service;

import ${module_package}.business.Task${entity_name}StateChangeConfig;
import ${module_package}.business.Task${entity_name}StateChangeConfigDAO;
import fr.paris.lutece.plugins.workflowcore.business.config.ITaskConfigDAO;
import fr.paris.lutece.plugins.workflowcore.service.config.ITaskConfigService;
import fr.paris.lutece.plugins.workflowcore.service.config.TaskConfigService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;

/**
 * CDI Producer for ${entity_name} State Change Task Config Service
 */
@ApplicationScoped
public class Task${entity_name}StateChangeConfigServiceProducer
{
    @Produces
    @ApplicationScoped
    @Named( Task${entity_name}StateChange.BEAN_CONFIG_SERVICE )
    public ITaskConfigService produceTask${entity_name}StateChangeConfigService(
        @Named( "workflow-${PLUGIN_NAME}.task${entity_name}StateChangeConfigDAO" ) ITaskConfigDAO<Task${entity_name}StateChangeConfig> taskConfigDAO )
    {
        TaskConfigService taskConfigService = new TaskConfigService( );
        taskConfigService.setTaskConfigDAO( (ITaskConfigDAO) taskConfigDAO );
        return taskConfigService;
    }
}
CSPRODUCEREOF
}

scaffold_workflow_generate_task_component() {
    local module_dir="$1"
    local module_package="$2"
    local module_package_path="$3"
    local entity_name="$4"

    local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')

    cat > "$module_dir/src/java/$module_package_path/web/${entity_name}StateChangeTaskComponent.java" << COMPONENTEOF
package ${module_package}.web;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import ${module_package}.business.Task${entity_name}StateChangeConfig;
import ${module_package}.service.Task${entity_name}StateChange;
import fr.paris.lutece.plugins.workflow.web.task.AbstractTaskComponent;
import fr.paris.lutece.plugins.workflowcore.service.config.ITaskConfigService;
import fr.paris.lutece.plugins.workflowcore.service.task.ITask;
import fr.paris.lutece.portal.service.template.AppTemplateService;
import fr.paris.lutece.util.html.HtmlTemplate;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;

/**
 * Task Component for ${entity_name} State Change
 */
@ApplicationScoped
@Named( "workflow-${PLUGIN_NAME}.task${entity_name}StateChangeComponent" )
public class ${entity_name}StateChangeTaskComponent extends AbstractTaskComponent
{
    private static final String TEMPLATE_CONFIG = "admin/plugins/workflow/modules/${PLUGIN_NAME}/task_${entity_lower}_statechange_config.html";
    private static final String TEMPLATE_FORM = "admin/plugins/workflow/modules/${PLUGIN_NAME}/task_${entity_lower}_statechange_form.html";
    private static final String TEMPLATE_INFO = "admin/plugins/workflow/modules/${PLUGIN_NAME}/task_${entity_lower}_statechange_information.html";

    private static final String MARK_CONFIG = "config";

    private static final String PARAMETER_TARGET_STATE = "target_state";
    private static final String PARAMETER_MESSAGE = "message";
    private static final String PARAMETER_NOTIFY_USER = "notify_user";

    @Inject
    @Named( Task${entity_name}StateChange.BEAN_CONFIG_SERVICE )
    private ITaskConfigService _taskConfigService;

    @Override
    public String getDisplayConfigForm( HttpServletRequest request, Locale locale, ITask task )
    {
        Map<String, Object> model = new HashMap<>( );

        Task${entity_name}StateChangeConfig config = _taskConfigService.findByPrimaryKey( task.getId( ) );
        model.put( MARK_CONFIG, config );

        HtmlTemplate template = AppTemplateService.getTemplate( TEMPLATE_CONFIG, locale, model );
        return template.getHtml( );
    }

    @Override
    public String doSaveConfig( HttpServletRequest request, Locale locale, ITask task )
    {
        String strTargetState = request.getParameter( PARAMETER_TARGET_STATE );
        String strMessage = request.getParameter( PARAMETER_MESSAGE );
        boolean bNotifyUser = request.getParameter( PARAMETER_NOTIFY_USER ) != null;

        Task${entity_name}StateChangeConfig config = _taskConfigService.findByPrimaryKey( task.getId( ) );

        if ( config == null )
        {
            config = new Task${entity_name}StateChangeConfig( );
            config.setIdTask( task.getId( ) );
            config.setTargetState( strTargetState );
            config.setMessage( strMessage );
            config.setNotifyUser( bNotifyUser );
            _taskConfigService.create( config );
        }
        else
        {
            config.setTargetState( strTargetState );
            config.setMessage( strMessage );
            config.setNotifyUser( bNotifyUser );
            _taskConfigService.update( config );
        }

        return null;
    }

    @Override
    public String getDisplayTaskForm( int nIdResource, String strResourceType, HttpServletRequest request, Locale locale, ITask task )
    {
        Map<String, Object> model = new HashMap<>( );

        Task${entity_name}StateChangeConfig config = _taskConfigService.findByPrimaryKey( task.getId( ) );
        model.put( MARK_CONFIG, config );

        HtmlTemplate template = AppTemplateService.getTemplate( TEMPLATE_FORM, locale, model );
        return template.getHtml( );
    }

    @Override
    public String doValidateTask( int nIdResource, String strResourceType, HttpServletRequest request, Locale locale, ITask task )
    {
        return null;
    }

    @Override
    public String getDisplayTaskInformation( int nIdHistory, HttpServletRequest request, Locale locale, ITask task )
    {
        Map<String, Object> model = new HashMap<>( );

        Task${entity_name}StateChangeConfig config = _taskConfigService.findByPrimaryKey( task.getId( ) );
        model.put( MARK_CONFIG, config );

        HtmlTemplate template = AppTemplateService.getTemplate( TEMPLATE_INFO, locale, model );
        return template.getHtml( );
    }
}
COMPONENTEOF
}

scaffold_workflow_generate_templates() {
    local module_dir="$1"
    local entity_name="$2"

    local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
    local template_dir="$module_dir/webapp/WEB-INF/templates/admin/plugins/workflow/modules/${PLUGIN_NAME}"

    echo "[WF 7/8] Generating workflow templates for ${entity_name}..."

    # Config template
    cat > "$template_dir/task_${entity_lower}_statechange_config.html" << CONFIGTPLEOF
<@row>
    <@columns>
        <@formGroup labelKey="module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.config.targetState" mandatory=true>
            <@input type="text" name="target_state" id="target_state" value=config.targetState!'' />
        </@formGroup>

        <@formGroup labelKey="module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.config.message">
            <@input type="text" name="message" id="message" value=config.message!'' size="50" />
        </@formGroup>

        <@formGroup>
            <@checkBox name="notify_user" id="notify_user" labelKey="module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.config.notifyUser" checked=config.notifyUser!false />
        </@formGroup>
    </@columns>
</@row>
CONFIGTPLEOF

    # Form template
    cat > "$template_dir/task_${entity_lower}_statechange_form.html" << FORMTPLEOF
<div class="alert alert-info">
    <#if config??>
        #i18n{module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.form.info}
        <strong>\${config.targetState!}</strong>
    </#if>
</div>
FORMTPLEOF

    # Information template
    cat > "$template_dir/task_${entity_lower}_statechange_information.html" << INFOTPLEOF
<div class="task-information">
    <#if config??>
        <p>
            <strong>#i18n{module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.info.targetState}:</strong>
            \${config.targetState!}
        </p>
        <#if config.message?has_content>
            <p>
                <strong>#i18n{module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.info.message}:</strong>
                \${config.message}
            </p>
        </#if>
        <p>
            <strong>#i18n{module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.info.notifyUser}:</strong>
            <#if config.notifyUser>#i18n{portal.util.labelYes}<#else>#i18n{portal.util.labelNo}</#if>
        </p>
    <#else>
        <p class="text-muted">#i18n{module.workflow.${PLUGIN_NAME}.task.${entity_lower}StateChange.info.noConfig}</p>
    </#if>
</div>
INFOTPLEOF
}

scaffold_workflow_generate_all_sql() {
    local module_dir="$1"
    local config_file="$2"

    local entity_count=$(jq '.entities | length' "$config_file")
    local sql_content="--liquibase formatted sql
--changeset workflow-${PLUGIN_NAME}:create_db_workflow-${PLUGIN_NAME}.sql
--preconditions onFail:MARK_RAN onError:WARN

--
-- Table structure for workflow-${PLUGIN_NAME} task configurations
--
"

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        # Only generate for root entities
        if [ -n "$parent_entity" ]; then
            continue
        fi
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')

        sql_content+="
DROP TABLE IF EXISTS workflow_task_${entity_lower}_statechange_config;
CREATE TABLE workflow_task_${entity_lower}_statechange_config (
    id_task INT NOT NULL,
    target_state VARCHAR(255) DEFAULT NULL,
    message VARCHAR(1000) DEFAULT NULL,
    notify_user SMALLINT DEFAULT 0,
    PRIMARY KEY (id_task)
);
"
    done

    echo "$sql_content" > "$module_dir/src/sql/plugins/workflow/modules/${PLUGIN_NAME}/plugin/create_db_workflow-${PLUGIN_NAME}.sql"
}

scaffold_workflow_generate_i18n() {
    local module_dir="$1"
    local config_file="$2"

    echo "[WF 8/8] Generating workflow i18n..."

    local entity_count=$(jq '.entities | length' "$config_file")
    local i18n_content_en=""
    local i18n_content_fr=""

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        # Only generate for root entities
        if [ -n "$parent_entity" ]; then
            continue
        fi
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')

        local plugin_name_cap=$(echo "${PLUGIN_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${PLUGIN_NAME:1}
        i18n_content_en+="# Task ${entity_name} State Change
task.${entity_lower}StateChange.title=(${plugin_name_cap}) ${entity_name} State Change
task.${entity_lower}StateChange.config.targetState=Target State
task.${entity_lower}StateChange.config.message=Notification Message
task.${entity_lower}StateChange.config.notifyUser=Notify User
task.${entity_lower}StateChange.form.info=This action will change the state to:
task.${entity_lower}StateChange.info.targetState=Target State
task.${entity_lower}StateChange.info.message=Message
task.${entity_lower}StateChange.info.notifyUser=Notify User
task.${entity_lower}StateChange.info.noConfig=No configuration found

"
        i18n_content_fr+="# Task ${entity_name} State Change
task.${entity_lower}StateChange.title=(${plugin_name_cap}) Changement d'\u00e9tat ${entity_name}
task.${entity_lower}StateChange.config.targetState=\u00c9tat cible
task.${entity_lower}StateChange.config.message=Message de notification
task.${entity_lower}StateChange.config.notifyUser=Notifier l'utilisateur
task.${entity_lower}StateChange.form.info=Cette action changera l'\u00e9tat vers :
task.${entity_lower}StateChange.info.targetState=\u00c9tat cible
task.${entity_lower}StateChange.info.message=Message
task.${entity_lower}StateChange.info.notifyUser=Notifier l'utilisateur
task.${entity_lower}StateChange.info.noConfig=Aucune configuration trouv\u00e9e

"
    done

    mkdir -p "$module_dir/src/java/fr/paris/lutece/plugins/workflow/modules/${PLUGIN_NAME}/resources"

    cat > "$module_dir/src/java/fr/paris/lutece/plugins/workflow/modules/${PLUGIN_NAME}/resources/${PLUGIN_NAME}_messages.properties" << I18NEOF
# Plugin description
plugin.description=Workflow module for ${PLUGIN_NAME}

$i18n_content_en
I18NEOF

    cat > "$module_dir/src/java/fr/paris/lutece/plugins/workflow/modules/${PLUGIN_NAME}/resources/${PLUGIN_NAME}_messages_fr.properties" << I18NFREOF
# Plugin description
plugin.description=Module workflow pour ${PLUGIN_NAME}

$i18n_content_fr
I18NFREOF
}

scaffold_workflow_generate_init_sql() {
    local module_dir="$1"
    local config_file="$2"

    local init_file="$module_dir/src/sql/plugins/workflow/modules/${PLUGIN_NAME}/plugin/init_db_workflow-${PLUGIN_NAME}.sql"

    local entity_count=$(jq '.entities | length' "$config_file")

    # Start with Liquibase header
    cat > "$init_file" << 'INITHEADER'
--liquibase formatted sql
--changeset workflow-PLUGIN_NAME:init_db_workflow-PLUGIN_NAME.sql
--preconditions onFail:MARK_RAN onError:WARN

--
-- Sample Workflow Configuration for PLUGIN_NAME
--
INITHEADER
    sed -i "s/PLUGIN_NAME/$PLUGIN_NAME/g" "$init_file"

    # Clean up existing workflow data for this plugin
    cat >> "$init_file" << 'CLEANUPEOF'
-- Clean up existing workflow data
DELETE FROM workflow_action_state_before WHERE id_action IN (SELECT id_action FROM workflow_action WHERE id_workflow IN (SELECT id_workflow FROM workflow_workflow WHERE uid_workflow LIKE 'PLUGIN_NAME_%'));
DELETE FROM workflow_task WHERE id_action IN (SELECT id_action FROM workflow_action WHERE id_workflow IN (SELECT id_workflow FROM workflow_workflow WHERE uid_workflow LIKE 'PLUGIN_NAME_%'));
DELETE FROM workflow_action WHERE id_workflow IN (SELECT id_workflow FROM workflow_workflow WHERE uid_workflow LIKE 'PLUGIN_NAME_%');
DELETE FROM workflow_state WHERE id_workflow IN (SELECT id_workflow FROM workflow_workflow WHERE uid_workflow LIKE 'PLUGIN_NAME_%');
DELETE FROM workflow_workflow WHERE uid_workflow LIKE 'PLUGIN_NAME_%';

CLEANUPEOF
    sed -i "s/PLUGIN_NAME/$PLUGIN_NAME/g" "$init_file"

    local workflow_id=100
    local state_id=100
    local action_id=100

    # Generate workflow for each root entity (entities without parent)
    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")

        # Only generate workflow for root entities (entities without parent)
        if [ -z "$parent_entity" ]; then
            local plugin_cap=$(echo "${PLUGIN_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${PLUGIN_NAME:1}

            cat >> "$init_file" << WORKFLOWEOF
--
-- Workflow: ${entity_name} Lifecycle
--
INSERT INTO workflow_workflow (id_workflow, name, description, creation_date, is_enabled, uid_workflow) VALUES
($workflow_id, '${entity_name} Lifecycle', 'Workflow for managing ${entity_lower} states', NOW(), 1, '${PLUGIN_NAME}_${entity_lower}');

-- States for ${entity_name} workflow
INSERT INTO workflow_state (id_state, name, description, id_workflow, is_initial_state, display_order, uid_state) VALUES
($state_id, 'New', '${entity_name} just created', $workflow_id, 1, 1, '${PLUGIN_NAME}_${entity_lower}_new'),
($((state_id+1)), 'In Progress', '${entity_name} being worked on', $workflow_id, 0, 2, '${PLUGIN_NAME}_${entity_lower}_in_progress'),
($((state_id+2)), 'On Hold', '${entity_name} temporarily paused', $workflow_id, 0, 3, '${PLUGIN_NAME}_${entity_lower}_on_hold'),
($((state_id+3)), 'Completed', '${entity_name} finished successfully', $workflow_id, 0, 4, '${PLUGIN_NAME}_${entity_lower}_completed'),
($((state_id+4)), 'Cancelled', '${entity_name} cancelled', $workflow_id, 0, 5, '${PLUGIN_NAME}_${entity_lower}_cancelled');

-- Actions for ${entity_name} workflow
INSERT INTO workflow_action (id_action, name, description, id_workflow, id_state_after, is_automatic, is_mass_action, display_order, uid_action) VALUES
($action_id, 'Start', 'Begin working on the ${entity_lower}', $workflow_id, $((state_id+1)), 0, 0, 1, '${PLUGIN_NAME}_${entity_lower}_start'),
($((action_id+1)), 'Put On Hold', 'Pause the ${entity_lower} temporarily', $workflow_id, $((state_id+2)), 0, 0, 2, '${PLUGIN_NAME}_${entity_lower}_hold'),
($((action_id+2)), 'Resume', 'Resume work on the ${entity_lower}', $workflow_id, $((state_id+1)), 0, 0, 3, '${PLUGIN_NAME}_${entity_lower}_resume'),
($((action_id+3)), 'Complete', 'Mark ${entity_lower} as completed', $workflow_id, $((state_id+3)), 0, 0, 4, '${PLUGIN_NAME}_${entity_lower}_complete'),
($((action_id+4)), 'Cancel', 'Cancel the ${entity_lower}', $workflow_id, $((state_id+4)), 0, 0, 5, '${PLUGIN_NAME}_${entity_lower}_cancel'),
($((action_id+5)), 'Reopen', 'Reopen a completed or cancelled ${entity_lower}', $workflow_id, $((state_id+1)), 0, 0, 6, '${PLUGIN_NAME}_${entity_lower}_reopen');

-- Action prerequisites (which states allow which actions)
INSERT INTO workflow_action_state_before (id_action, id_state_before) VALUES
($action_id, $state_id),                    -- Start: from New
($((action_id+1)), $((state_id+1))),        -- Put On Hold: from In Progress
($((action_id+2)), $((state_id+2))),        -- Resume: from On Hold
($((action_id+3)), $((state_id+1))),        -- Complete: from In Progress
($((action_id+4)), $state_id),              -- Cancel: from New
($((action_id+4)), $((state_id+1))),        -- Cancel: from In Progress
($((action_id+4)), $((state_id+2))),        -- Cancel: from On Hold
($((action_id+5)), $((state_id+3))),        -- Reopen: from Completed
($((action_id+5)), $((state_id+4)));        -- Reopen: from Cancelled

WORKFLOWEOF

            ((workflow_id++))
            ((state_id+=10))
            ((action_id+=10))
        fi
    done
}
