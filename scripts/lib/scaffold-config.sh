#!/bin/bash

scaffold_generate_pom() {
    local plugin_dir="$1"

    echo "[2/9] Generating pom.xml..."

    local file_upload_deps=""
    if [ "$PLUGIN_HAS_FILE_FIELDS" = true ]; then
        file_upload_deps="        <dependency>
            <groupId>fr.paris.lutece.plugins</groupId>
            <artifactId>plugin-asynchronousupload</artifactId>
            <version>[2.0.0-SNAPSHOT,)</version>
            <type>lutece-plugin</type>
        </dependency>
        <dependency>
            <groupId>fr.paris.lutece.plugins</groupId>
            <artifactId>plugin-genericattributes</artifactId>
            <version>[3.0.0-SNAPSHOT,)</version>
            <type>lutece-plugin</type>
        </dependency>"
    fi

    cat > "$plugin_dir/pom.xml" << POMEOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>plugin-${PLUGIN_NAME}</artifactId>
    <packaging>lutece-plugin</packaging>
    <version>1.0.0-SNAPSHOT</version>
    <name>Lutece ${PLUGIN_NAME} plugin</name>

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
$file_upload_deps
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

scaffold_generate_beans_xml() {
    local plugin_dir="$1"

    echo "[3/9] Generating beans.xml (CDI)..."

    cat > "$plugin_dir/src/main/resources/META-INF/beans.xml" << 'BEANSEOF'
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0"
       bean-discovery-mode="annotated">
</beans>
BEANSEOF
}

scaffold_generate_plugin_xml() {
    local plugin_dir="$1"
    local config_file="$2"

    echo "[5/9] Generating plugin.xml..."

    local admin_features=""
    admin_features+="        <admin-feature>\n"
    admin_features+="            <feature-id>${PLUGIN_NAME^^}_MANAGEMENT</feature-id>\n"
    admin_features+="            <feature-title>${PLUGIN_NAME}.adminFeature.manage${FIRST_ENTITY}s.name</feature-title>\n"
    admin_features+="            <feature-description>${PLUGIN_NAME}.adminFeature.manage${FIRST_ENTITY}s.description</feature-description>\n"
    admin_features+="            <feature-level>1</feature-level>\n"
    admin_features+="            <feature-url>jsp/admin/plugins/${PLUGIN_NAME}/Manage${FIRST_ENTITY}s.jsp</feature-url>\n"
    admin_features+="            <feature-icon-url>images/admin/skin/feature_icon_default.png</feature-icon-url>\n"
    admin_features+="        </admin-feature>"

    local xpage_section=""
    if [ "$FEATURE_XPAGE" = "true" ]; then
        local xpage_name_val=${FEATURE_XPAGE_NAME:-$PLUGIN_NAME}
        xpage_section="\n    <applications>\n        <application>\n            <application-id>${xpage_name_val}</application-id>\n        </application>\n    </applications>"
    fi

    local rbac_section=""
    if [ "$FEATURE_RBAC" = "true" ]; then
        local plugin_upper=$(echo "$PLUGIN_NAME" | sed 's/.*/\u&/')
        rbac_section="\n    <rbac-resource-types>\n        <rbac-resource-type>\n            <rbac-resource-type-class>\n                ${PACKAGE_BASE}.service.${plugin_upper}ResourceIdService\n            </rbac-resource-type-class>\n        </rbac-resource-type>\n    </rbac-resource-types>"
    fi

    cat > "$plugin_dir/webapp/WEB-INF/plugins/${PLUGIN_NAME}.xml" << PLUGINEOF
<?xml version="1.0" encoding="UTF-8"?>
<plug-in>
    <name>$PLUGIN_NAME</name>
    <class>fr.paris.lutece.portal.service.plugin.PluginDefaultImplementation</class>
    <version>1.0.0-SNAPSHOT</version>
    <documentation/>
    <installation/>
    <changes/>
    <user-guide/>
    <description>${PLUGIN_NAME}.plugin.description</description>
    <provider>${PLUGIN_NAME}.plugin.provider</provider>
    <provider-url>http://lutece.paris.fr</provider-url>
    <icon-url>images/admin/skin/feature_default_icon.png</icon-url>
    <copyright>Copyright (c) 2025</copyright>
    <db-pool-required>1</db-pool-required>

    <core-version-dependency>
        <min-core-version>8.0.0</min-core-version>
        <max-core-version/>
    </core-version-dependency>

    <admin-features>
$(echo -e "$admin_features")
    </admin-features>
$(echo -e "$xpage_section")
$(echo -e "$rbac_section")
</plug-in>
PLUGINEOF
}

scaffold_generate_claude_md() {
    local plugin_dir="$1"

    echo "[9/9] Generating CLAUDE.md..."

    cat > "$plugin_dir/CLAUDE.md" << CLAUDEEOF
# Lutece Plugin: $PLUGIN_NAME

## IMPORTANT: Workflow de développement

**AVANT de coder une feature, tu DOIS:**
1. Consulter les sources lutece-core pour trouver des patterns similaires
2. Écrire un plan dans \`docs/plans/YYYY-MM-DD-<feature>.md\`
3. Faire valider le plan avant d'implémenter

## Lutece Core Sources

**Chemin:** \`~/.lutece-references/lutece-core\`

### Où trouver quoi dans lutece-core:

| Besoin | Chemin dans lutece-core |
|--------|-------------------------|
| **Macros Freemarker** | \`webapp/WEB-INF/templates/commons_macros.html\` |
| **Composants Tabler** | \`webapp/WEB-INF/templates/admin/themes/tabler/\` |
| **Layout (row, columns)** | \`webapp/WEB-INF/templates/admin/themes/tabler/layout/page/\` |
| **Forms (select, radio)** | \`webapp/WEB-INF/templates/admin/themes/tabler/forms/\` |
| **Table, pagination** | \`webapp/WEB-INF/templates/admin/themes/tabler/components/\` |
| **DAOUtil (types SQL)** | \`src/java/fr/paris/lutece/util/sql/DAOUtil.java\` |
| **MVCAdminJspBean** | \`src/java/fr/paris/lutece/portal/util/mvc/admin/MVCAdminJspBean.java\` |
| **Exemple JSPBean** | \`src/java/fr/paris/lutece/portal/web/workgroup/AdminWorkgroupJspBean.java\` |
| **Exemple DAO/Home** | \`src/java/fr/paris/lutece/portal/business/workgroup/\` |
| **Exemple Service** | \`src/java/fr/paris/lutece/portal/service/workgroup/AdminWorkgroupService.java\` |
| **XPage base** | \`src/java/fr/paris/lutece/portal/web/xpages/XPageApplication.java\` |
| **RBAC** | \`src/java/fr/paris/lutece/portal/service/rbac/RBACService.java\` |
| **Templates admin** | \`webapp/WEB-INF/templates/admin/workgroup/\` |
| **DateTimePicker** | \`webapp/WEB-INF/templates/admin/util/calendar/macro_datetimepicker.html\` |

## Règles Lutece

1. **i18n**: Clés préfixées dans Java/templates, PAS dans les .properties
2. **Templates**: Vérifier les paths des includes par rapport à la position du template
3. **Populate**: Regarder \`BeanUtil.populate\` dans lutece-core
4. **Macros**: Utiliser @row, @columns, @table, @aButton, @form, etc.

## Structure du plugin

\`\`\`
src/java/$PACKAGE_PATH/
├── business/    # Entity, IDAO, DAO, Home
├── service/     # Services métier
├── web/         # JSPBean, XPage
└── resources/   # i18n properties

webapp/WEB-INF/
├── templates/admin/plugins/$PLUGIN_NAME/  # Templates admin
├── templates/skin/plugins/$PLUGIN_NAME/   # Templates front
└── plugins/$PLUGIN_NAME.xml               # Config plugin
\`\`\`

## Conventions de nommage

| Type | Préfixe | Exemple |
|------|---------|---------|
| String | _str | _strName |
| int | _n | _nId |
| long | _l | _lCount |
| boolean | _b | _bActive |
| double | _d | _dPrice |
| Timestamp | _ts | _tsCreation |
| Date | _date | _dateStart |
| List | _list | _listItems |

## Checklist avant commit

- [ ] Patterns vérifiés dans lutece-core
- [ ] Clés i18n préfixées correctement
- [ ] Paths templates corrects
- [ ] Macros Lutece utilisées
- [ ] Pas de réinvention de la roue
CLAUDEEOF
}
