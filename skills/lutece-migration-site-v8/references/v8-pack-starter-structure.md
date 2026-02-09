# Structure d'un site Lutece V8 "Pack Starter"

Ce document décrit la structure d'un site Lutece V8 utilisant le pattern "pack starter", basé sur l'analyse du site `site-deontologie`.

## Caractéristiques

Un site "pack starter" est un site V8 **minimaliste** qui :
- Utilise un **starter** (forms-starter, appointment-starter, etc.) au lieu de déclarer chaque plugin
- N'a **aucun template local** — tout est fourni par les plugins/starters
- N'a **aucun fichier JS/CSS local** — le thème est externe
- N'a **aucun fichier SQL local** — Liquibase dans les plugins gère la DB
- Se concentre uniquement sur la **configuration**

## Structure des fichiers

```
site-xxx/
├── pom.xml                                    # Dépendances (starter + plugins additionnels)
├── README.md
├── .gitignore
├── src/
│   └── main/
│       └── liberty/
│           └── config/
│               ├── server.xml                 # Config Liberty (features, DB, ports)
│               ├── server.env                 # Variables env (OpenTelemetry)
│               ├── bootstrap.properties       # Bootstrap (peut être vide)
│               └── jvm.options                # Options JVM (peut être vide)
└── webapp/
    └── WEB-INF/
        ├── conf/
        │   ├── caches.dat                     # Cache config (généré au runtime)
        │   └── override/
        │       ├── profiles-config.properties # Liquibase config
        │       └── plugins/
        │           └── mylutece.properties    # Overrides par plugin
        └── plugins/
            └── plugins.dat                    # Index plugins (généré au runtime)
```

## POM.xml type

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <parent>
        <artifactId>lutece-site-pom</artifactId>
        <groupId>fr.paris.lutece.tools</groupId>
        <version>8.0.0-SNAPSHOT</version>
    </parent>

    <groupId>fr.paris.lutece</groupId>
    <artifactId>site-xxx</artifactId>
    <packaging>lutece-site</packaging>
    <version>1.0.0-SNAPSHOT</version>

    <repositories>
        <repository>
            <id>lutece</id>
            <url>https://dev.lutece.paris.fr/maven_repository</url>
        </repository>
        <repository>
            <id>luteceSnapshot</id>
            <url>https://dev.lutece.paris.fr/snapshot_repository</url>
            <snapshots><enabled>true</enabled></snapshots>
        </repository>
    </repositories>

    <dependencyManagement>
        <dependencies>
            <!-- Lutece BOM pour gestion centralisée des versions -->
            <dependency>
                <groupId>fr.paris.lutece.starters</groupId>
                <artifactId>lutece-bom</artifactId>
                <version>8.0.0-SNAPSHOT</version>
                <scope>import</scope>
                <type>pom</type>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <dependencies>
        <!-- Starter principal -->
        <dependency>
            <groupId>fr.paris.lutece.starters</groupId>
            <artifactId>forms-starter</artifactId>
            <version>8.0.0-SNAPSHOT</version>
        </dependency>

        <!-- Plugins additionnels non inclus dans le starter -->
        <dependency>
            <groupId>fr.paris.lutece.plugins</groupId>
            <artifactId>module-workflow-unittree</artifactId>
            <type>lutece-plugin</type>
        </dependency>

        <!-- Thème externe -->
        <dependency>
            <groupId>fr.paris.lutece.themes</groupId>
            <artifactId>site-theme-parisfr</artifactId>
            <version>[3.0.0-SNAPSHOT]</version>
            <type>lutece-site</type>
        </dependency>
    </dependencies>
</project>
```

## server.xml type

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<server description="lutece server">
    <featureManager>
        <feature>persistence-3.1</feature>
        <feature>beanValidation-3.0</feature>
        <feature>jndi-1.0</feature>
        <feature>jdbc-4.2</feature>
        <feature>localConnector-1.0</feature>
        <feature>cdi-4.0</feature>
        <feature>servlet-6.0</feature>
        <feature>pages-3.1</feature>
        <feature>mpConfig-3.1</feature>
        <feature>mail-2.1</feature>
        <feature>xmlBinding-4.0</feature>
        <feature>concurrent-3.0</feature>
        <feature>restfulWS-3.1</feature>
        <feature>mpHealth-4.0</feature>
        <feature>mpTelemetry-2.0</feature>
    </featureManager>

    <variable defaultValue="9090" name="http.port"/>
    <variable defaultValue="9443" name="https.port"/>

    <applicationManager autoExpand="true"/>
    <httpEndpoint host="*" httpPort="${http.port}" httpsPort="${https.port}" id="defaultHttpEndpoint"/>
    <mpTelemetry source="message, trace, ffdc"/>

    <application context-root="lutece" location="lutece.war" name="lutece" type="war"/>
    <applicationMonitor dropinsEnabled="false" updateTrigger="disabled"/>

    <library id="jdbcLib">
        <fileset dir="/config/apps/expanded/lutece.war/WEB-INF/lib/" includes="*.jar"/>
    </library>

    <!-- Variables DB - à personnaliser -->
    <variable defaultValue="lutece" name="portal.user"/>
    <variable defaultValue="password" name="portal.password"/>
    <variable defaultValue="3306" name="portal.port"/>
    <variable defaultValue="core" name="portal.dbname"/>
    <variable defaultValue="mariadb" name="portal.serverName"/>

    <dataSource jndiName="jdbc/portal">
        <jdbcDriver libraryRef="jdbcLib"/>
        <properties databaseName="${portal.dbname}" password="${portal.password}"
                    portNumber="${portal.port}" serverName="${portal.serverName}"
                    user="${portal.user}"/>
    </dataSource>
</server>
```

## server.env type

```
# OpenTelemetry
OTEL_SDK_DISABLED=false
OTEL_SDK_NAME=LUTECE
# OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317
```

## profiles-config.properties type

```properties
# Liquibase
liquibase.enabled.at.startup=true
liquibase.accept.snapshot.versions=true
```

## Starters disponibles

| Starter | Description | Plugins principaux inclus |
|---------|-------------|--------------------------|
| `forms-starter` | Gestion de formulaires dynamiques | forms, workflow, genericattributes, unittree, accesscontrol, lucene, rest |
| `appointment-starter` | Gestion de rendez-vous | appointment, workflow, genericattributes |
| `editorial-starter` | Gestion de contenu éditorial | document, htmldocs |
| `lutece-starter` | Application complète | Tous les modules communs |

## Avantages du pattern pack starter

1. **Maintenance simplifiée** — Une seule dépendance à mettre à jour
2. **Cohérence** — Les versions des plugins sont testées ensemble
3. **Déploiement rapide** — Moins de configuration manuelle
4. **Containerisation native** — Prêt pour Docker/Kubernetes avec Liberty

## Migration V7 → V8 pack starter

Si un site V7 peut être converti en pack starter :
1. Identifier le starter correspondant au cas d'usage
2. Remplacer les dépendances individuelles par le starter
3. Vérifier si des plugins spécifiques sont manquants et les ajouter
4. Supprimer les templates locaux si le starter/thème les fournit
5. Migrer les fichiers JS custom vers vanilla JS ou les supprimer

## Référence

Site exemple : `~/Documents/Formation/GitLab/site-deontologie`
