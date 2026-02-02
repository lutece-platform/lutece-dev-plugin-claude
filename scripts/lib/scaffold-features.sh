#!/bin/bash

scaffold_generate_cache_service() {
    local plugin_dir="$1"
    local config_file="$2"

    if [ "$FEATURE_CACHE" != "true" ]; then
        return
    fi

    echo "[7.1/9] Generating CacheService..."

    local plugin_upper=$(echo "$PLUGIN_NAME" | sed 's/.*/\u&/')
    local entity_count=$(jq '.entities | length' "$config_file")

    local cache_methods=""
    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        cache_methods+="    public String get${entity_name}CacheKey( int nId${entity_name} )
    {
        return new StringBuilder( \"${entity_name}-id:\" ).append( nId${entity_name} ).toString( );
    }

    public String get${entity_name}ListCacheKey( )
    {
        return \"${entity_name}List\";
    }

"
    done

    cat > "$plugin_dir/src/java/$PACKAGE_PATH/service/cache/${plugin_upper}CacheService.java" << CACHEEOF
package $PACKAGE_BASE.service.cache;

import javax.cache.CacheException;

import fr.paris.lutece.portal.service.cache.AbstractCacheableService;
import fr.paris.lutece.portal.service.util.AppLogService;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.Initialized;
import jakarta.enterprise.event.Observes;
import jakarta.servlet.ServletContext;

@ApplicationScoped
public class ${plugin_upper}CacheService extends AbstractCacheableService<String, Object>
{
    public void onStartup( @Observes @Initialized( ApplicationScoped.class ) ServletContext context )
    {
    }

    private static final String CACHE_NAME = "${PLUGIN_NAME}CacheService";

    @PostConstruct
    public void initCache( )
    {
        initCache( CACHE_NAME, String.class, Object.class );
    }

    @Override
    public String getName( )
    {
        return CACHE_NAME;
    }

$cache_methods
    @Override
    public void put( String key, Object value )
    {
        if ( !isCacheEnable( ) )
        {
            return;
        }
        try
        {
            if ( _cache != null && !_cache.isClosed( ) )
            {
                _cache.put( key, value );
            }
        }
        catch ( CacheException | IllegalStateException e )
        {
            AppLogService.error( e.getMessage( ), e );
        }
    }

    @Override
    public Object get( String key )
    {
        if ( !isCacheEnable( ) )
        {
            return null;
        }
        try
        {
            if ( _cache != null && !_cache.isClosed( ) )
            {
                return _cache.get( key );
            }
        }
        catch ( CacheException | IllegalStateException e )
        {
            AppLogService.error( e.getMessage( ), e );
        }
        return null;
    }

    @Override
    public boolean remove( String key )
    {
        if ( !isCacheEnable( ) )
        {
            return false;
        }
        try
        {
            if ( _cache != null && !_cache.isClosed( ) )
            {
                return _cache.remove( key );
            }
        }
        catch ( CacheException | IllegalStateException e )
        {
            AppLogService.error( e.getMessage( ), e );
        }
        return false;
    }
}
CACHEEOF
}

scaffold_generate_xpage() {
    local plugin_dir="$1"
    local config_file="$2"

    if [ "$FEATURE_XPAGE" != "true" ]; then
        return
    fi

    echo "[7.2/9] Generating XPage..."

    local xpage_name=${FEATURE_XPAGE_NAME:-$PLUGIN_NAME}
    local plugin_upper=$(echo "$PLUGIN_NAME" | sed 's/.*/\u&/')

    cat > "$plugin_dir/src/java/$PACKAGE_PATH/web/${plugin_upper}XPage.java" << XPAGEEOF
package $PACKAGE_BASE.web;

import java.util.List;

import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;

import $PACKAGE_BASE.business.${FIRST_ENTITY};
import $PACKAGE_BASE.business.${FIRST_ENTITY}Home;
import fr.paris.lutece.portal.util.mvc.commons.annotations.View;
import fr.paris.lutece.portal.util.mvc.xpage.MVCApplication;
import fr.paris.lutece.portal.util.mvc.xpage.annotations.Controller;
import fr.paris.lutece.portal.web.cdi.mvc.Models;
import fr.paris.lutece.portal.web.util.IPager;
import fr.paris.lutece.portal.web.util.Pager;
import fr.paris.lutece.portal.web.xpages.XPage;

@RequestScoped
@Named( "${PLUGIN_NAME}.xpage.${xpage_name}" )
@Controller( xpageName = ${plugin_upper}XPage.XPAGE_NAME, pageTitleI18nKey = ${plugin_upper}XPage.MESSAGE_PAGE_TITLE, pagePathI18nKey = ${plugin_upper}XPage.MESSAGE_PATH )
public class ${plugin_upper}XPage extends MVCApplication
{
    private static final long serialVersionUID = 1L;

    protected static final String XPAGE_NAME = "${xpage_name}";
    protected static final String MESSAGE_PAGE_TITLE = "${PLUGIN_NAME}.xpage.pageTitle";
    protected static final String MESSAGE_PATH = "${PLUGIN_NAME}.xpage.pagePathLabel";

    private static final String TEMPLATE_LIST = "skin/plugins/${PLUGIN_NAME}/list_${FIRST_ENTITY_LOWER}s.html";

    private static final String MARK_LIST = "${FIRST_ENTITY_LOWER}_list";

    private static final String VIEW_LIST = "list";

    @Inject
    private Models _models;
    @Inject
    @Pager( name = "${FIRST_ENTITY_LOWER}List", listBookmark = MARK_LIST,
            defaultItemsPerPage = "${PLUGIN_NAME}.xpage.itemsPerPage" )
    private IPager<${FIRST_ENTITY}, ${FIRST_ENTITY}> _pager;

    @View( value = VIEW_LIST, defaultView = true )
    public XPage getList( HttpServletRequest request )
    {
        List<${FIRST_ENTITY}> listAll = ${FIRST_ENTITY}Home.findAll( );

        _pager.withListItem( listAll )
              .populateModels( request, _models, request.getLocale( ) );

        return getXPage( TEMPLATE_LIST, request.getLocale( ) );
    }
}
XPAGEEOF

    local xpage_table_headers=""
    local xpage_table_cols=""
    local first_entity_field_count=$(jq ".entities[0].fields | length" "$config_file")

    for ((j=0; j<first_entity_field_count; j++)); do
        local field_name=$(jq -r ".entities[0].fields[$j].name" "$config_file")
        local field_type_raw=$(jq -r ".entities[0].fields[$j].type" "$config_file")

        xpage_table_headers+="                    <th>#i18n{$PLUGIN_NAME.model.entity.${FIRST_ENTITY_LOWER}.attribute.$field_name}</th>
"
        if [ "$field_type_raw" == "boolean" ] || [ "$field_type_raw" == "Boolean" ] || [ "$field_type_raw" == "bool" ]; then
            xpage_table_cols+="                    <td><#if ${FIRST_ENTITY_LOWER}.$field_name!false><span class=\"text-success\">✓</span><#else><span class=\"text-danger\">✗</span></#if></td>
"
        else
            xpage_table_cols+="                    <td>\${${FIRST_ENTITY_LOWER}.$field_name!}</td>
"
        fi
    done

    cat > "$plugin_dir/webapp/WEB-INF/templates/skin/plugins/$PLUGIN_NAME/list_${FIRST_ENTITY_LOWER}s.html" << XPAGETPLEOF
<@cTpl>
<@cContainer>
    <@cRow>
        <@cCol>
            <@cTitle level=2>#i18n{${PLUGIN_NAME}.xpage.pageTitle}</@cTitle>
            <#if ${FIRST_ENTITY_LOWER}_list?has_content>
                <#if ${FIRST_ENTITY_LOWER}_list?size gt 5>
                    <@cPagination paginator=paginator />
                </#if>
                <@cCard>
                    <div class="table-responsive">
                        <table class="table table-striped">
                            <thead>
                                <tr>
$xpage_table_headers                                </tr>
                            </thead>
                            <tbody>
                                <#list ${FIRST_ENTITY_LOWER}_list as ${FIRST_ENTITY_LOWER}>
                                <tr>
$xpage_table_cols                                </tr>
                                </#list>
                            </tbody>
                        </table>
                    </div>
                </@cCard>
                <#if ${FIRST_ENTITY_LOWER}_list?size gt 5>
                    <@cRow class='mt-3'>
                        <@cCol>
                            <@cPagination paginator=paginator />
                        </@cCol>
                        <@cCol class='d-flex justify-content-end'>
                            <@cText>#i18n{portal.util.labelTotal} : <strong>\${paginator.itemsCount}</strong></@cText>
                        </@cCol>
                    </@cRow>
                </#if>
            <#else>
                <@cAlert title='#i18n{${PLUGIN_NAME}.xpage.noData}' class='info' />
            </#if>
        </@cCol>
    </@cRow>
</@cContainer>
</@cTpl>
XPAGETPLEOF
}

scaffold_generate_rbac() {
    local plugin_dir="$1"
    local config_file="$2"

    if [ "$FEATURE_RBAC" != "true" ]; then
        return
    fi

    echo "[7.3/9] Generating RBAC ResourceIdService..."

    local plugin_upper=$(echo "$PLUGIN_NAME" | sed 's/.*/\u&/')

    local perm_constants=""
    local perm_registrations=""
    local perm_labels=""

    for perm in $(echo "$RBAC_PERMISSIONS" | jq -r '.[]'); do
        local perm_upper=$(echo "$perm" | tr '[:lower:]' '[:upper:]')
        perm_constants+="    public static final String PERMISSION_${perm_upper} = \"${perm_upper}\";\n"
        perm_registrations+="        permission = new Permission( );\n"
        perm_registrations+="        permission.setPermissionKey( PERMISSION_${perm_upper} );\n"
        perm_registrations+="        permission.setPermissionTitleKey( PROPERTY_LABEL_${perm_upper} );\n"
        perm_registrations+="        resourceType.registerPermission( permission );\n\n"
        perm_labels+="    private static final String PROPERTY_LABEL_${perm_upper} = \"${PLUGIN_NAME}.permission.label.${perm,,}\";\n"
    done

    cat > "$plugin_dir/src/java/$PACKAGE_PATH/service/${plugin_upper}ResourceIdService.java" << RBACEOF
package $PACKAGE_BASE.service;

import $PACKAGE_BASE.business.${FIRST_ENTITY};
import $PACKAGE_BASE.business.${FIRST_ENTITY}Home;
import fr.paris.lutece.portal.service.rbac.Permission;
import fr.paris.lutece.portal.service.rbac.ResourceIdService;
import fr.paris.lutece.portal.service.rbac.ResourceType;
import fr.paris.lutece.portal.service.rbac.ResourceTypeManager;
import fr.paris.lutece.portal.service.util.AppLogService;
import fr.paris.lutece.util.ReferenceList;

import java.util.Locale;

public class ${plugin_upper}ResourceIdService extends ResourceIdService
{
$(echo -e "$perm_constants")
    private static final String PROPERTY_LABEL_RESOURCE_TYPE = "${PLUGIN_NAME}.permission.label.resourceType";
$(echo -e "$perm_labels")
    public ${plugin_upper}ResourceIdService( )
    {
        super( );
        setPluginName( ${plugin_upper}Plugin.PLUGIN_NAME );
    }

    @Override
    public void register( )
    {
        ResourceType resourceType = new ResourceType( );
        resourceType.setResourceIdServiceClass( ${plugin_upper}ResourceIdService.class.getName( ) );
        resourceType.setPluginName( ${plugin_upper}Plugin.PLUGIN_NAME );
        resourceType.setResourceTypeKey( ${FIRST_ENTITY}.RESOURCE_TYPE );
        resourceType.setResourceTypeLabelKey( PROPERTY_LABEL_RESOURCE_TYPE );

        Permission permission;

$(echo -e "$perm_registrations")
        ResourceTypeManager.registerResourceType( resourceType );
    }

    @Override
    public String getTitle( String strId, Locale locale )
    {
        int nId = -1;
        try
        {
            nId = Integer.parseInt( strId );
        }
        catch( NumberFormatException ne )
        {
            AppLogService.error( ne );
        }

        ${FIRST_ENTITY} entity = ${FIRST_ENTITY}Home.findByPrimaryKey( nId );
        return entity != null ? String.valueOf( entity.getId${FIRST_ENTITY}( ) ) : "";
    }

    @Override
    public ReferenceList getResourceIdList( Locale locale )
    {
        ReferenceList list = new ReferenceList( );
        for ( ${FIRST_ENTITY} entity : ${FIRST_ENTITY}Home.findAll( ) )
        {
            list.addItem( entity.getId${FIRST_ENTITY}( ), String.valueOf( entity.getId${FIRST_ENTITY}( ) ) );
        }
        return list;
    }
}
RBACEOF

    cat > "$plugin_dir/src/java/$PACKAGE_PATH/service/${plugin_upper}Plugin.java" << PLUGINCLASSEOF
package $PACKAGE_BASE.service;

import fr.paris.lutece.portal.service.plugin.Plugin;
import fr.paris.lutece.portal.service.plugin.PluginService;

public final class ${plugin_upper}Plugin
{
    public static final String PLUGIN_NAME = "${PLUGIN_NAME}";

    private ${plugin_upper}Plugin( )
    {
    }

    public static Plugin getPlugin( )
    {
        return PluginService.getPlugin( PLUGIN_NAME );
    }
}
PLUGINCLASSEOF

    local first_entity_file="$plugin_dir/src/java/$PACKAGE_PATH/business/${FIRST_ENTITY}.java"
    # Only add RESOURCE_TYPE if it doesn't already exist (workflow may have added it)
    if [ -f "$first_entity_file" ] && ! grep -q "RESOURCE_TYPE" "$first_entity_file"; then
        sed -i "s/private static final long serialVersionUID = 1L;/private static final long serialVersionUID = 1L;\n\n    public static final String RESOURCE_TYPE = \"${PLUGIN_NAME^^}_${FIRST_ENTITY^^}\";/" "$first_entity_file"
    fi
}

scaffold_generate_site() {
    local plugin_dir="$1"
    local config_file="$2"
    local parent_dir="$3"

    if [ "$FEATURE_SITE" != "true" ]; then
        return
    fi

    echo ""
    echo "=== Generating Lutece Site ==="

    local site_name=$(jq -r '.features.site.name // "site-'$PLUGIN_NAME'"' "$config_file")
    local site_desc=$(jq -r '.features.site.description // "Lutece Site for '$PLUGIN_NAME'"' "$config_file")
    local site_db=$(jq -r '.features.site.database.name // "lutece_'$PLUGIN_NAME'"' "$config_file")
    local site_db_user=$(jq -r '.features.site.database.user // "root"' "$config_file")
    local site_db_password=$(jq -r '.features.site.database.password // "root"' "$config_file")
    local site_db_host=$(jq -r '.features.site.database.host // "localhost"' "$config_file")
    local site_db_port=$(jq -r '.features.site.database.port // 3306' "$config_file")

    local sites_dir="$parent_dir"

    local site_config="/tmp/${PLUGIN_NAME}-site-config.json"

    # Build plugins array - always include main plugin
    local plugins_json='[
    {
      "groupId": "fr.paris.lutece.plugins",
      "artifactId": "plugin-'$PLUGIN_NAME'",
      "version": "[1.0.0-SNAPSHOT,)",
      "type": "lutece-plugin"
    }'

    # Add workflow dependencies if workflow feature is enabled
    if [ "$FEATURE_WORKFLOW" == "true" ]; then
        plugins_json+=',
    {
      "groupId": "fr.paris.lutece.plugins",
      "artifactId": "plugin-workflow",
      "version": "[7.0.0-SNAPSHOT,)",
      "type": "lutece-plugin"
    },
    {
      "groupId": "fr.paris.lutece.plugins",
      "artifactId": "module-workflow-'$PLUGIN_NAME'",
      "version": "[1.0.0-SNAPSHOT,)",
      "type": "lutece-plugin"
    }'
    fi

    plugins_json+='
  ]'

    cat > "$site_config" << SITEJSONEOF
{
  "siteName": "$site_name",
  "siteDescription": "$site_desc",
  "database": {
    "name": "$site_db",
    "user": "$site_db_user",
    "password": "$site_db_password",
    "host": "$site_db_host",
    "port": $site_db_port
  },
  "plugins": $plugins_json
}
SITEJSONEOF

    local script_dir="$(dirname "$0")"
    if [ -f "$script_dir/lutece-site.sh" ]; then
        bash "$script_dir/lutece-site.sh" "$site_config" "$sites_dir"
    else
        echo "Warning: lutece-site.sh not found in $script_dir"
    fi
}
