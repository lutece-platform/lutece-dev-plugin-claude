#!/bin/bash

scaffold_generate_entity_class() {
    local plugin_dir="$1"
    local entity_name="$2"
    local entity_imports="$3"
    local fields_decl="$4"
    local getters_setters="$5"
    local parent_entity="$6"

    local entity_dir="$plugin_dir/src/java/$PACKAGE_PATH/business"

    local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
    local plugin_upper=$(echo "$PLUGIN_NAME" | tr '[:lower:]' '[:upper:]')

    # Add RESOURCE_TYPE constant and workflow fields only for ROOT entities (no parent)
    local resource_type_const=""
    local workflow_field=""
    local workflow_getters=""
    if [ "$FEATURE_WORKFLOW" == "true" ] && [ -z "$parent_entity" ]; then
        resource_type_const="
    public static final String RESOURCE_TYPE = \"${plugin_upper}_${entity_name^^}\";
"
        workflow_field="    private int _nIdWorkflow;
"
        workflow_getters="    public int getIdWorkflow()
    {
        return _nIdWorkflow;
    }

    public void setIdWorkflow( int nIdWorkflow )
    {
        _nIdWorkflow = nIdWorkflow;
    }

"
    fi

    cat > "$entity_dir/$entity_name.java" << ENTITYEOF
package $PACKAGE_BASE.business;

$(echo -e "$entity_imports")

public class $entity_name implements Serializable
{
    private static final long serialVersionUID = 1L;
$resource_type_const
    private int _nId${entity_name};
$workflow_field$(echo -e "$fields_decl")

    public int getId${entity_name}()
    {
        return _nId${entity_name};
    }

    public void setId${entity_name}( int nId${entity_name} )
    {
        _nId${entity_name} = nId${entity_name};
    }

$workflow_getters$(echo -e "$getters_setters")
}
ENTITYEOF
}

scaffold_generate_idao() {
    local plugin_dir="$1"
    local entity_name="$2"
    local entity_var="$3"
    local parent_entity="$4"

    local entity_dir="$plugin_dir/src/java/$PACKAGE_PATH/business"

    local parent_methods=""
    if [ -n "$parent_entity" ]; then
        parent_methods="
    List<$entity_name> selectBy${parent_entity}Id( int nId${parent_entity} );

    void deleteBy${parent_entity}Id( int nId${parent_entity} );"
    fi

    cat > "$entity_dir/I${entity_name}DAO.java" << IDAOEOF
package $PACKAGE_BASE.business;

import java.util.List;

public interface I${entity_name}DAO
{
    void insert( $entity_name $entity_var );

    $entity_name load( int nId );

    void store( $entity_name $entity_var );

    void delete( int nId );

    List<$entity_name> selectAll();
$parent_methods
}
IDAOEOF
}

scaffold_generate_dao() {
    local plugin_dir="$1"
    local entity_name="$2"
    local entity_var="$3"
    local entity_lower="$4"
    local table_name="$5"
    local sql_columns="$6"
    local sql_insert_cols="$7"
    local sql_insert_vals="$8"
    local sql_update="$9"
    local dao_set_insert="${10}"
    local dao_set_update="${11}"
    local dao_get="${12}"
    local need_file="${13}"
    local parent_entity="${14}"
    local parent_entity_lower="${15}"

    local entity_dir="$plugin_dir/src/java/$PACKAGE_PATH/business"
    local dao_file_import=""
    [ "$need_file" = true ] && dao_file_import="import fr.paris.lutece.portal.business.file.File;\n"

    # Add id_workflow column only for ROOT entities (no parent)
    if [ "$FEATURE_WORKFLOW" == "true" ] && [ -z "$parent_entity" ]; then
        sql_columns+=", id_workflow"
        sql_insert_cols+=", id_workflow"
        sql_insert_vals+=", ?"
        sql_update+=", id_workflow = ?"
        dao_set_insert+="            daoUtil.setInt( nIndex++, ${entity_var}.getIdWorkflow() );\n"
        dao_set_update+="            daoUtil.setInt( nIndex++, ${entity_var}.getIdWorkflow() );\n"
        dao_get+="                ${entity_var}.setIdWorkflow( daoUtil.getInt( nIndex++ ) );\n"
    fi

    local parent_sql_queries=""
    local parent_methods=""
    if [ -n "$parent_entity" ]; then
        parent_sql_queries="
    private static final String SQL_QUERY_SELECTALL_BY_${parent_entity^^}_ID = \"SELECT id_${entity_lower}, $sql_columns FROM $table_name WHERE id_${parent_entity_lower} = ?\";
    private static final String SQL_QUERY_DELETE_BY_${parent_entity^^}_ID = \"DELETE FROM $table_name WHERE id_${parent_entity_lower} = ?\";"

        parent_methods="
    @Override
    public List<$entity_name> selectBy${parent_entity}Id( int nId${parent_entity} )
    {
        List<$entity_name> list = new ArrayList<>();

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECTALL_BY_${parent_entity^^}_ID ) )
        {
            daoUtil.setInt( 1, nId${parent_entity} );
            daoUtil.executeQuery();

            while ( daoUtil.next() )
            {
                $entity_name $entity_var = new ${entity_name}();
                int nIndex = 1;
                ${entity_var}.setId${entity_name}( daoUtil.getInt( nIndex++ ) );
$(echo -e "$dao_get")
                list.add( $entity_var );
            }
        }

        return list;
    }

    @Override
    public void deleteBy${parent_entity}Id( int nId${parent_entity} )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_DELETE_BY_${parent_entity^^}_ID ) )
        {
            daoUtil.setInt( 1, nId${parent_entity} );
            daoUtil.executeUpdate();
        }
    }"
    fi

    cat > "$entity_dir/${entity_name}DAO.java" << DAOEOF
package $PACKAGE_BASE.business;

$(echo -e "$dao_file_import")import fr.paris.lutece.util.sql.DAOUtil;
import jakarta.enterprise.context.ApplicationScoped;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

@ApplicationScoped
public class ${entity_name}DAO implements I${entity_name}DAO
{
    private static final String SQL_QUERY_SELECT = "SELECT id_${entity_lower}, $sql_columns FROM $table_name WHERE id_${entity_lower} = ?";
    private static final String SQL_QUERY_INSERT = "INSERT INTO $table_name ( $sql_insert_cols ) VALUES ( $sql_insert_vals )";
    private static final String SQL_QUERY_UPDATE = "UPDATE $table_name SET $sql_update WHERE id_${entity_lower} = ?";
    private static final String SQL_QUERY_DELETE = "DELETE FROM $table_name WHERE id_${entity_lower} = ?";
    private static final String SQL_QUERY_SELECTALL = "SELECT id_${entity_lower}, $sql_columns FROM $table_name";
$parent_sql_queries

    @Override
    public void insert( $entity_name $entity_var )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_INSERT, Statement.RETURN_GENERATED_KEYS ) )
        {
            int nIndex = 1;
$(echo -e "$dao_set_insert")
            daoUtil.executeUpdate();

            if ( daoUtil.nextGeneratedKey() )
            {
                ${entity_var}.setId${entity_name}( daoUtil.getGeneratedKeyInt( 1 ) );
            }
        }
    }

    @Override
    public $entity_name load( int nId )
    {
        $entity_name $entity_var = null;

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECT ) )
        {
            daoUtil.setInt( 1, nId );
            daoUtil.executeQuery();

            if ( daoUtil.next() )
            {
                $entity_var = new ${entity_name}();
                int nIndex = 1;
                ${entity_var}.setId${entity_name}( daoUtil.getInt( nIndex++ ) );
$(echo -e "$dao_get")            }
        }

        return $entity_var;
    }

    @Override
    public void store( $entity_name $entity_var )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_UPDATE ) )
        {
            int nIndex = 1;
$(echo -e "$dao_set_update")            daoUtil.setInt( nIndex, ${entity_var}.getId${entity_name}() );

            daoUtil.executeUpdate();
        }
    }

    @Override
    public void delete( int nId )
    {
        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_DELETE ) )
        {
            daoUtil.setInt( 1, nId );
            daoUtil.executeUpdate();
        }
    }

    @Override
    public List<$entity_name> selectAll()
    {
        List<$entity_name> list = new ArrayList<>();

        try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY_SELECTALL ) )
        {
            daoUtil.executeQuery();

            while ( daoUtil.next() )
            {
                $entity_name $entity_var = new ${entity_name}();
                int nIndex = 1;
                ${entity_var}.setId${entity_name}( daoUtil.getInt( nIndex++ ) );
$(echo -e "$dao_get")
                list.add( $entity_var );
            }
        }

        return list;
    }
$parent_methods
}
DAOEOF
}

scaffold_generate_home_with_cache() {
    local plugin_dir="$1"
    local entity_name="$2"
    local entity_var="$3"
    local parent_entity="$4"

    local entity_dir="$plugin_dir/src/java/$PACKAGE_PATH/business"
    local plugin_upper=$(echo "$PLUGIN_NAME" | sed 's/.*/\u&/')

    local parent_methods=""
    if [ -n "$parent_entity" ]; then
        parent_methods="
    public static List<$entity_name> findBy${parent_entity}Id( int nId${parent_entity} )
    {
        return _dao.selectBy${parent_entity}Id( nId${parent_entity} );
    }

    public static void removeBy${parent_entity}Id( int nId${parent_entity} )
    {
        List<$entity_name> list = findBy${parent_entity}Id( nId${parent_entity} );
        for ( $entity_name $entity_var : list )
        {
            _cache.remove( _cache.get${entity_name}CacheKey( ${entity_var}.getId${entity_name}() ) );
        }
        _dao.deleteBy${parent_entity}Id( nId${parent_entity} );
        _cache.remove( _cache.get${entity_name}ListCacheKey() );
    }"
    fi

    cat > "$entity_dir/${entity_name}Home.java" << HOMEEOF
package $PACKAGE_BASE.business;

import ${PACKAGE_BASE}.service.cache.${plugin_upper}CacheService;
import jakarta.enterprise.inject.spi.CDI;
import java.util.ArrayList;
import java.util.List;

public final class ${entity_name}Home
{
    private static I${entity_name}DAO _dao = CDI.current().select( I${entity_name}DAO.class ).get();
    private static ${plugin_upper}CacheService _cache = CDI.current().select( ${plugin_upper}CacheService.class ).get();

    private ${entity_name}Home()
    {
    }

    public static $entity_name create( $entity_name $entity_var )
    {
        _dao.insert( $entity_var );
        _cache.put( _cache.get${entity_name}CacheKey( ${entity_var}.getId${entity_name}() ), $entity_var );
        _cache.remove( _cache.get${entity_name}ListCacheKey() );
        return $entity_var;
    }

    public static $entity_name update( $entity_name $entity_var )
    {
        _dao.store( $entity_var );
        _cache.put( _cache.get${entity_name}CacheKey( ${entity_var}.getId${entity_name}() ), $entity_var );
        _cache.remove( _cache.get${entity_name}ListCacheKey() );
        return $entity_var;
    }

    public static void remove( int nId )
    {
        _dao.delete( nId );
        _cache.remove( _cache.get${entity_name}CacheKey( nId ) );
        _cache.remove( _cache.get${entity_name}ListCacheKey() );
    }

    @SuppressWarnings( "unchecked" )
    public static $entity_name findByPrimaryKey( int nId )
    {
        String cacheKey = _cache.get${entity_name}CacheKey( nId );
        $entity_name $entity_var = ($entity_name) _cache.get( cacheKey );
        if ( $entity_var == null )
        {
            $entity_var = _dao.load( nId );
            if ( $entity_var != null )
            {
                _cache.put( cacheKey, $entity_var );
            }
        }
        return $entity_var;
    }

    @SuppressWarnings( "unchecked" )
    public static List<$entity_name> findAll()
    {
        String cacheKey = _cache.get${entity_name}ListCacheKey();
        List<$entity_name> list = (List<$entity_name>) _cache.get( cacheKey );
        if ( list == null )
        {
            list = _dao.selectAll();
            _cache.put( cacheKey, list );
        }
        return new ArrayList<>( list );
    }
$parent_methods
}
HOMEEOF
}

scaffold_generate_home_without_cache() {
    local plugin_dir="$1"
    local entity_name="$2"
    local entity_var="$3"
    local parent_entity="$4"

    local entity_dir="$plugin_dir/src/java/$PACKAGE_PATH/business"

    local parent_methods=""
    if [ -n "$parent_entity" ]; then
        parent_methods="
    public static List<$entity_name> findBy${parent_entity}Id( int nId${parent_entity} )
    {
        return _dao.selectBy${parent_entity}Id( nId${parent_entity} );
    }

    public static void removeBy${parent_entity}Id( int nId${parent_entity} )
    {
        _dao.deleteBy${parent_entity}Id( nId${parent_entity} );
    }"
    fi

    cat > "$entity_dir/${entity_name}Home.java" << HOMEEOF
package $PACKAGE_BASE.business;

import jakarta.enterprise.inject.spi.CDI;
import java.util.List;

public final class ${entity_name}Home
{
    private static I${entity_name}DAO _dao = CDI.current().select( I${entity_name}DAO.class ).get();

    private ${entity_name}Home()
    {
    }

    public static $entity_name create( $entity_name $entity_var )
    {
        _dao.insert( $entity_var );
        return $entity_var;
    }

    public static $entity_name update( $entity_name $entity_var )
    {
        _dao.store( $entity_var );
        return $entity_var;
    }

    public static void remove( int nId )
    {
        _dao.delete( nId );
    }

    public static $entity_name findByPrimaryKey( int nId )
    {
        return _dao.load( nId );
    }

    public static List<$entity_name> findAll()
    {
        return _dao.selectAll();
    }
$parent_methods
}
HOMEEOF
}

scaffold_generate_sql() {
    local plugin_dir="$1"
    local entity_lower="$2"
    local table_name="$3"
    local sql_create_cols="$4"
    local parent_entity_lower="$5"

    local sql_index=""
    if [ -n "$parent_entity_lower" ]; then
        sql_index="
CREATE INDEX idx_${table_name}_id_${parent_entity_lower} ON $table_name ( id_${parent_entity_lower} );"
    fi

    # Add id_workflow column only for ROOT entities (no parent)
    local workflow_col=""
    if [ "$FEATURE_WORKFLOW" == "true" ] && [ -z "$parent_entity_lower" ]; then
        workflow_col="    id_workflow INT DEFAULT 0,\n"
    fi

    cat > "$plugin_dir/src/sql/plugins/$PLUGIN_NAME/plugin/create_db_${PLUGIN_NAME}.sql" << SQLEOF
--liquibase formatted sql
--changeset ${PLUGIN_NAME}:create_db_${PLUGIN_NAME}.sql
--preconditions onFail:MARK_RAN onError:WARN

--
-- Table structure for table $table_name
--
CREATE TABLE $table_name (
    id_${entity_lower} INT AUTO_INCREMENT NOT NULL,
$(echo -e "$workflow_col")$(echo -e "$sql_create_cols")    PRIMARY KEY (id_${entity_lower})
);
$sql_index
SQLEOF
}

scaffold_append_sql() {
    local plugin_dir="$1"
    local entity_lower="$2"
    local table_name="$3"
    local sql_create_cols="$4"
    local parent_entity_lower="$5"

    local sql_index=""
    if [ -n "$parent_entity_lower" ]; then
        sql_index="
CREATE INDEX idx_${table_name}_id_${parent_entity_lower} ON $table_name ( id_${parent_entity_lower} );"
    fi

    # Add id_workflow column only for ROOT entities (no parent)
    local workflow_col=""
    if [ "$FEATURE_WORKFLOW" == "true" ] && [ -z "$parent_entity_lower" ]; then
        workflow_col="    id_workflow INT DEFAULT 0,\n"
    fi

    cat >> "$plugin_dir/src/sql/plugins/$PLUGIN_NAME/plugin/create_db_${PLUGIN_NAME}.sql" << SQLEOF

--
-- Table structure for table $table_name
--
CREATE TABLE $table_name (
    id_${entity_lower} INT AUTO_INCREMENT NOT NULL,
$(echo -e "$workflow_col")$(echo -e "$sql_create_cols")    PRIMARY KEY (id_${entity_lower})
);
$sql_index
SQLEOF
}

scaffold_generate_entities() {
    local plugin_dir="$1"
    local config_file="$2"

    echo "[4/9] Generating entities..."

    local entity_count=$(jq '.entities | length' "$config_file")

    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local table_name=$(jq -r ".entities[$i].tableName" "$config_file")
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        local entity_var=$(echo "${entity_name:0:1}" | tr '[:upper:]' '[:lower:]')${entity_name:1}
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        local parent_entity_lower=""
        [ -n "$parent_entity" ] && parent_entity_lower=$(echo "$parent_entity" | tr '[:upper:]' '[:lower:]')

        echo "  - $entity_name"
        [ -n "$parent_entity" ] && echo "    (child of $parent_entity)"

        local fields_decl=""
        local getters_setters=""
        local sql_columns=""
        local sql_insert_cols=""
        local sql_insert_vals=""
        local sql_update=""
        local dao_set_insert=""
        local dao_set_update=""
        local dao_get=""
        local sql_create_cols=""
        local entity_imports=""
        local need_date=false
        local need_timestamp=false
        local need_time=false
        local need_bigdecimal=false
        local need_file=false

        if [ -n "$parent_entity" ]; then
            local fk_field_name="id${parent_entity}"
            local fk_db_col="id_${parent_entity_lower}"

            fields_decl+="    private int _nId${parent_entity};\n"
            getters_setters+="    public int getId${parent_entity}()\n    {\n        return _nId${parent_entity};\n    }\n\n"
            getters_setters+="    public void setId${parent_entity}( int nId${parent_entity} )\n    {\n        _nId${parent_entity} = nId${parent_entity};\n    }\n\n"

            sql_columns+="$fk_db_col, "
            sql_insert_cols+="$fk_db_col, "
            sql_insert_vals+="?, "
            sql_update+="$fk_db_col = ?, "

            dao_set_insert+="            daoUtil.setInt( nIndex++, ${entity_var}.getId${parent_entity}() );\n"
            dao_set_update+="            daoUtil.setInt( nIndex++, ${entity_var}.getId${parent_entity}() );\n"
            dao_get+="                ${entity_var}.setId${parent_entity}( daoUtil.getInt( nIndex++ ) );\n"

            sql_create_cols+="    $fk_db_col INT NOT NULL,\n"
        fi

        local field_count=$(jq ".entities[$i].fields | length" "$config_file")

        for ((j=0; j<field_count; j++)); do
            local field_name=$(jq -r ".entities[$i].fields[$j].name" "$config_file")
            local field_type_raw=$(jq -r ".entities[$i].fields[$j].type" "$config_file")
            local sql_type=$(jq -r ".entities[$i].fields[$j].sqlType // empty" "$config_file")
            local required=$(jq -r ".entities[$i].fields[$j].required" "$config_file")

            local field_upper=$(echo "${field_name:0:1}" | tr '[:lower:]' '[:upper:]')${field_name:1}
            local db_col=$(echo "$field_name" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')

            local type_info=$(scaffold_get_java_type_info "$field_type_raw")
            IFS='|' read -r java_type prefix getter setter default_sql_type <<< "$type_info"

            [ -z "$sql_type" ] && sql_type="$default_sql_type"

            case $field_type_raw in
                "timestamp"|"Timestamp") need_timestamp=true ;;
                "date"|"Date") need_date=true ;;
                "time"|"Time") need_time=true ;;
                "decimal"|"BigDecimal") need_bigdecimal=true ;;
                "file"|"File") need_file=true ;;
            esac

            fields_decl+="    private $java_type ${prefix}${field_upper};\n"

            if [ "$java_type" == "boolean" ]; then
                getters_setters+="    public $java_type is${field_upper}()\n    {\n        return ${prefix}${field_upper};\n    }\n\n"
            elif [ "$java_type" == "File" ]; then
                getters_setters+="    public $java_type get${field_upper}()\n    {\n        return ${prefix}${field_upper};\n    }\n\n"
                getters_setters+="    public String get${field_upper}Base64()\n    {\n        if ( ${prefix}${field_upper} == null || ${prefix}${field_upper}.getPhysicalFile() == null )\n        {\n            return \"\";\n        }\n        return java.util.Base64.getEncoder().encodeToString( ${prefix}${field_upper}.getPhysicalFile().getValue() );\n    }\n\n"
            else
                getters_setters+="    public $java_type get${field_upper}()\n    {\n        return ${prefix}${field_upper};\n    }\n\n"
            fi
            getters_setters+="    public void set${field_upper}( $java_type ${entity_var}${field_upper} )\n    {\n        ${prefix}${field_upper} = ${entity_var}${field_upper};\n    }\n\n"

            if [ "$java_type" == "File" ]; then
                sql_columns+="id_$db_col, "
                sql_insert_cols+="id_$db_col, "
            else
                sql_columns+="$db_col, "
                sql_insert_cols+="$db_col, "
            fi
            sql_insert_vals+="?, "
            sql_update+="$( [ "$java_type" == "File" ] && echo "id_$db_col" || echo "$db_col" ) = ?, "

            if [ "$java_type" == "boolean" ]; then
                dao_set_insert+="            daoUtil.$setter( nIndex++, ${entity_var}.is${field_upper}() );\n"
                dao_set_update+="            daoUtil.$setter( nIndex++, ${entity_var}.is${field_upper}() );\n"
            elif [ "$java_type" == "File" ]; then
                dao_set_insert+="            if ( ${entity_var}.get${field_upper}() != null )\n            {\n                daoUtil.setInt( nIndex++, ${entity_var}.get${field_upper}().getIdFile() );\n            }\n            else\n            {\n                daoUtil.setInt( nIndex++, 0 );\n            }\n"
                dao_set_update+="            if ( ${entity_var}.get${field_upper}() != null )\n            {\n                daoUtil.setInt( nIndex++, ${entity_var}.get${field_upper}().getIdFile() );\n            }\n            else\n            {\n                daoUtil.setInt( nIndex++, 0 );\n            }\n"
            else
                dao_set_insert+="            daoUtil.$setter( nIndex++, ${entity_var}.get${field_upper}() );\n"
                dao_set_update+="            daoUtil.$setter( nIndex++, ${entity_var}.get${field_upper}() );\n"
            fi

            if [ "$java_type" == "File" ]; then
                dao_get+="                int nId${field_upper} = daoUtil.getInt( nIndex++ );\n                if ( nId${field_upper} > 0 )\n                {\n                    File file${field_upper} = new File();\n                    file${field_upper}.setIdFile( nId${field_upper} );\n                    ${entity_var}.set${field_upper}( file${field_upper} );\n                }\n"
            else
                dao_get+="                ${entity_var}.set${field_upper}( daoUtil.$getter( nIndex++ ) );\n"
            fi

            local not_null=""
            [ "$required" == "true" ] && not_null=" NOT NULL"
            if [ "$java_type" == "File" ]; then
                sql_create_cols+="    id_$db_col $sql_type,\n"
            else
                sql_create_cols+="    $db_col $sql_type$not_null,\n"
            fi
        done

        sql_columns=${sql_columns%, }
        sql_insert_cols=${sql_insert_cols%, }
        sql_insert_vals=${sql_insert_vals%, }
        sql_update=${sql_update%, }

        entity_imports="import java.io.Serializable;\n"
        [ "$need_date" = true ] && entity_imports+="import java.sql.Date;\n"
        [ "$need_timestamp" = true ] && entity_imports+="import java.sql.Timestamp;\n"
        [ "$need_time" = true ] && entity_imports+="import java.sql.Time;\n"
        [ "$need_bigdecimal" = true ] && entity_imports+="import java.math.BigDecimal;\n"
        [ "$need_file" = true ] && entity_imports+="import fr.paris.lutece.portal.business.file.File;\n"

        scaffold_generate_entity_class "$plugin_dir" "$entity_name" "$entity_imports" "$fields_decl" "$getters_setters" "$parent_entity"
        scaffold_generate_idao "$plugin_dir" "$entity_name" "$entity_var" "$parent_entity"
        scaffold_generate_dao "$plugin_dir" "$entity_name" "$entity_var" "$entity_lower" "$table_name" \
            "$sql_columns" "$sql_insert_cols" "$sql_insert_vals" "$sql_update" \
            "$dao_set_insert" "$dao_set_update" "$dao_get" "$need_file" "$parent_entity" "$parent_entity_lower"

        if [ "$FEATURE_CACHE" = "true" ]; then
            scaffold_generate_home_with_cache "$plugin_dir" "$entity_name" "$entity_var" "$parent_entity"
        else
            scaffold_generate_home_without_cache "$plugin_dir" "$entity_name" "$entity_var" "$parent_entity"
        fi

        if [ $i -eq 0 ]; then
            scaffold_generate_sql "$plugin_dir" "$entity_lower" "$table_name" "$sql_create_cols" "$parent_entity_lower"
        else
            scaffold_append_sql "$plugin_dir" "$entity_lower" "$table_name" "$sql_create_cols" "$parent_entity_lower"
        fi
    done

    # Generate init SQL with sample data
    scaffold_generate_init_sql "$plugin_dir" "$config_file"
}

scaffold_generate_init_sql() {
    local plugin_dir="$1"
    local config_file="$2"

    local init_file="$plugin_dir/src/sql/plugins/$PLUGIN_NAME/plugin/init_db_${PLUGIN_NAME}.sql"

    # Header
    cat > "$init_file" << 'INITHEADER'
--liquibase formatted sql
--changeset PLUGIN_NAME:init_db_PLUGIN_NAME.sql
--preconditions onFail:MARK_RAN onError:WARN

INITHEADER
    sed -i "s/PLUGIN_NAME/$PLUGIN_NAME/g" "$init_file"

    local entity_count=$(jq '.entities | length' "$config_file")

    # Generate DELETE statements in reverse order (children first)
    echo "--" >> "$init_file"
    echo "-- Clear existing sample data" >> "$init_file"
    echo "--" >> "$init_file"
    for ((i=entity_count-1; i>=0; i--)); do
        local table_name=$(jq -r ".entities[$i].tableName" "$config_file")
        echo "DELETE FROM $table_name;" >> "$init_file"
    done
    echo "" >> "$init_file"

    # Sample data arrays for generating fake data
    local names=("Alpha" "Beta" "Gamma" "Delta" "Epsilon")
    local descriptions=("First item for testing" "Second sample entry" "Third demo record" "Fourth test data" "Fifth example item")
    local authors=("alice" "bob" "charlie" "david" "eve")
    local titles=("Initial Task" "Review Phase" "Development" "Testing" "Deployment")

    local id_counter=1
    local parent_ids=""
    local workflow_id_counter=100  # Matches workflow init SQL

    # Generate INSERT statements for each entity
    for ((i=0; i<entity_count; i++)); do
        local entity_name=$(jq -r ".entities[$i].name" "$config_file")
        local entity_lower=$(echo "$entity_name" | tr '[:upper:]' '[:lower:]')
        local table_name=$(jq -r ".entities[$i].tableName" "$config_file")
        local parent_entity=$(jq -r ".entities[$i].parentEntity // empty" "$config_file")
        local parent_entity_lower=""
        [ -n "$parent_entity" ] && parent_entity_lower=$(echo "$parent_entity" | tr '[:upper:]' '[:lower:]')

        echo "--" >> "$init_file"
        echo "-- Sample data for table $table_name" >> "$init_file"
        echo "--" >> "$init_file"

        # Build columns list
        local columns="id_${entity_lower}"
        local field_count=$(jq ".entities[$i].fields | length" "$config_file")

        # Add id_workflow only for ROOT entities (no parent)
        if [ "$FEATURE_WORKFLOW" == "true" ] && [ -z "$parent_entity_lower" ]; then
            columns+=", id_workflow"
        fi

        # Add parent FK if exists
        if [ -n "$parent_entity_lower" ]; then
            columns+=", id_${parent_entity_lower}"
        fi

        # Add all fields
        for ((f=0; f<field_count; f++)); do
            local field_name=$(jq -r ".entities[$i].fields[$f].name" "$config_file")
            local field_name_snake=$(echo "$field_name" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
            columns+=", $field_name_snake"
        done

        # Generate sample rows (3 for root entities, 2 per parent for children)
        local rows_to_generate=3
        if [ -n "$parent_entity_lower" ]; then
            rows_to_generate=2
        fi

        local start_id=$id_counter
        local parent_count=3
        [ -n "$parent_entity_lower" ] && parent_count=$(echo "$parent_ids" | tr ',' '\n' | grep -c . || echo "0")
        [ "$parent_count" -eq 0 ] && parent_count=1

        echo "INSERT INTO $table_name ($columns) VALUES" >> "$init_file"

        local row_num=0
        local total_rows=$((rows_to_generate * (parent_count > 0 ? parent_count : 1)))
        [ -z "$parent_entity_lower" ] && total_rows=$rows_to_generate

        # Calculate workflow ID: only root entities get a workflow, children get 0
        local workflow_id_for_entity=0
        if [ "$FEATURE_WORKFLOW" == "true" ] && [ -z "$parent_entity_lower" ]; then
            # Root entities get workflow IDs matching the workflow init SQL
            workflow_id_for_entity=$workflow_id_counter
            ((workflow_id_counter++))
        fi

        if [ -z "$parent_entity_lower" ]; then
            # Root entity - generate 3 rows
            for ((r=0; r<rows_to_generate; r++)); do
                local values="$id_counter"

                # Add workflow ID only for ROOT entities
                if [ "$FEATURE_WORKFLOW" == "true" ]; then
                    values+=", $workflow_id_for_entity"
                fi

                for ((f=0; f<field_count; f++)); do
                    local field_type=$(jq -r ".entities[$i].fields[$f].type" "$config_file")
                    local field_name=$(jq -r ".entities[$i].fields[$f].name" "$config_file")

                    case "$field_type" in
                        string)
                            if [[ "$field_name" == *"name"* ]] || [[ "$field_name" == *"Name"* ]]; then
                                values+=", '${names[$r]} $entity_name'"
                            elif [[ "$field_name" == *"title"* ]] || [[ "$field_name" == *"Title"* ]]; then
                                values+=", '${titles[$r]}'"
                            elif [[ "$field_name" == *"author"* ]] || [[ "$field_name" == *"Author"* ]]; then
                                values+=", '${authors[$r]}'"
                            else
                                values+=", 'Sample $field_name $((r+1))'"
                            fi
                            ;;
                        longtext|longText)
                            values+=", '${descriptions[$r]}'"
                            ;;
                        int|integer|number)
                            values+=", $((r+1))"
                            ;;
                        long)
                            values+=", $((r+1))00"
                            ;;
                        boolean)
                            values+=", $((r % 2))"
                            ;;
                        double)
                            values+=", $((r+1)).99"
                            ;;
                        date)
                            values+=", '2024-0$((r+1))-15'"
                            ;;
                        timestamp)
                            values+=", '2024-0$((r+1))-15 10:30:00'"
                            ;;
                        *)
                            values+=", 'Value $((r+1))'"
                            ;;
                    esac
                done

                local separator=","
                [ $r -eq $((rows_to_generate-1)) ] && separator=";"
                echo "($values)$separator" >> "$init_file"

                parent_ids+="$id_counter,"
                ((id_counter++))
            done
        else
            # Child entity - generate 2 rows per parent
            local parent_list=$(echo "$parent_ids" | tr ',' '\n' | grep -v '^$')

            # Count total rows for this entity
            local parent_arr=($parent_list)
            local total_parent_count=${#parent_arr[@]}
            local total_child_rows=$((total_parent_count * rows_to_generate))
            local current_row=0

            for parent_id in $parent_list; do
                for ((r=0; r<rows_to_generate; r++)); do
                    local values="$id_counter"

                    # Child entities don't have id_workflow column
                    values+=", $parent_id"
                    local idx=$((row_num % 5))

                    for ((f=0; f<field_count; f++)); do
                        local field_type=$(jq -r ".entities[$i].fields[$f].type" "$config_file")
                        local field_name=$(jq -r ".entities[$i].fields[$f].name" "$config_file")

                        case "$field_type" in
                            string)
                                if [[ "$field_name" == *"name"* ]] || [[ "$field_name" == *"Name"* ]]; then
                                    values+=", '${names[$idx]} $entity_name'"
                                elif [[ "$field_name" == *"title"* ]] || [[ "$field_name" == *"Title"* ]]; then
                                    values+=", '${titles[$idx]}'"
                                elif [[ "$field_name" == *"author"* ]] || [[ "$field_name" == *"Author"* ]]; then
                                    values+=", '${authors[$idx]}'"
                                else
                                    values+=", 'Sample $field_name $((row_num+1))'"
                                fi
                                ;;
                            longtext|longText)
                                values+=", '${descriptions[$idx]}'"
                                ;;
                            int|integer|number)
                                values+=", $((idx+1))"
                                ;;
                            long)
                                values+=", $((idx+1))00"
                                ;;
                            boolean)
                                values+=", $((row_num % 2))"
                                ;;
                            double)
                                values+=", $((idx+1)).99"
                                ;;
                            date)
                                values+=", '2024-0$((idx+1))-15'"
                                ;;
                            timestamp)
                                values+=", '2024-0$((idx+1))-15 1$idx:30:00'"
                                ;;
                            *)
                                values+=", 'Value $((row_num+1))'"
                                ;;
                        esac
                    done

                    ((row_num++))
                    ((id_counter++))
                    ((current_row++))

                    local separator=","
                    # Check if this is the last row
                    if [ $current_row -eq $total_child_rows ]; then
                        separator=";"
                    fi
                    echo "($values)$separator" >> "$init_file"
                done
            done

            # Store new parent IDs for next level
            parent_ids=""
            for ((p=start_id; p<id_counter; p++)); do
                parent_ids+="$p,"
            done
        fi

        echo "" >> "$init_file"
    done
}
