---
name: lutece-xdoc-generator
description: Use this skill when the user asks to generate XDOC documentation for Lutece Java plugins. Triggers include requests to create documentation, generate xdoc files, document a Lutece plugin, or analyze Java source code from Lutece repositories (github.com/lutece-secteur-public). This skill analyzes Java classes, configuration files, SQL scripts, and Spring contexts to produce structured XDOC documentation in French and English following the official Lutece plugin documentation format.
license: MIT
---

# Lutece XDOC Generator

## Overview

This skill automates the generation of XDOC documentation files for Lutece plugins by analyzing Java source code, configuration files, SQL scripts, and Spring contexts. It produces two complete XDOC files (French and English) following the official Lutece documentation structure.

## When to Use This Skill

Use this skill when:
- User requests XDOC documentation generation for a Lutece plugin
- User provides a GitHub repository URL from lutece-secteur-public organization
- User asks to document a Java plugin with specific sections (Introduction, Configuration, Usage)
- User needs bilingual (French/English) documentation for a Lutece project

## XDOC Structure

The generated XDOC must follow this exact structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<document>
    <properties>
        <title>Plugin {PLUGIN_NAME}</title>
    </properties>
    <head>
        <meta name="keywords" content="{KEYWORD_A},{KEYWORD_B},{KEYWORD_C}"/>
    </head>
    <body>
        <section name="Plugin {PLUGIN_NAME}">
            <subsection name="Introduction">
                <p>...</p>
            </subsection>
            <subsection name="Configuration">
                <p>...</p>
            </subsection>
            <subsection name="Usage">
                <p>...</p>          
            </subsection>
        </section>
    </body>
</document>
```

### CRITICAL FORMATTING RULES

- **NEVER use HTML heading tags** (`<h1>`, `<h2>`, `<h3>`, etc.) - these are not valid in XDOC
- Use `<section>` and `<subsection>` elements only
- Use `<p>`, `<ul>`, `<li>`, `<code>`, `<strong>`, `<em>` for content formatting
- Keep structure flat - no nested subsections

## Analysis Workflow

### Step 1: Extract Repository Content

```bash
# If user provides a ZIP file
unzip -q /mnt/user-data/uploads/plugin-name.zip
cd plugin-name

# Otherwise, attempt to access the repository via web
# Note: Direct cloning may not work due to network restrictions
```

### Step 2: Identify Key Files

```bash
# Find all Java source files
find . -type f -name "*.java"

# Find configuration files
find . -type f \( -name "*.properties" -o -name "*.sql" -o -name "*context.xml" -o -name "pom.xml" \)

# Find specific patterns
find . -name "*Daemon*.java"    # Daemon classes
find . -name "*Cache*.java"     # Cache classes
find . -name "*Task*.java"      # Workflow tasks
find . -name "*RBAC*.java"      # RBAC resources
```

### Step 3: Analyze Project Components

#### POM.xml Analysis
Extract:
- `<artifactId>`: Plugin name
- `<name>`: Plugin description
- `<dependencies>`: Required dependencies

#### Properties Files
Extract all properties from:
- `webapp/WEB-INF/conf/plugins/{plugin}.properties`

#### Spring Context
Extract bean definitions from:
- `webapp/WEB-INF/conf/plugins/{plugin}_context.xml`

Look for:
- DAO beans (`@Inject` annotations or Spring bean IDs)
- Service beans
- REST service beans

#### SQL Scripts
Analyze files in `src/sql/`:
- `core/init_core_{plugin}.sql`: Admin rights, roles, workgroups
- `plugin/create_db_{plugin}.sql`: Database structure

Extract:
- `CORE_ADMIN_RIGHT` entries: Admin rights
- `CORE_ADMIN_ROLE` entries: Roles
- `CORE_ADMIN_ROLE_RESOURCE` entries: Role-resource mappings
- `CORE_ADMIN_WORKGROUP` entries: Workgroups

#### Java Classes Analysis

**Service Classes** (in package `.service` or containing "Service"):
- Extract all public methods with parameters and return types
- Include JavaDoc comments if present
- Note singleton pattern usage (getInstance())

**REST API Classes** (in package `.rs` or containing "Rest"):
- Extract HTTP methods: `@GET`, `@POST`, `@PUT`, `@DELETE`, `@PATCH`
- Extract paths: `@Path` annotations
- Extract parameters: `@QueryParam`, `@PathParam`, `@HeaderParam`
- Extract request/response types: `@Consumes`, `@Produces`
- Document required headers (e.g., CLIENT_CODE, Authorization)
- Document response codes: `@ApiResponse`, `@ApiResponses`

**Daemon Classes** (containing "Daemon"):
- List class names to activate

**Cache Classes** (extending `AbstractCacheableService` or containing "Cache"):
- List cache names to activate

**Task Classes** (containing "Task" in workflow package):
- List workflow task names

**RBAC Resources** (extending `RBACResource`):
- List resource types

## Content Generation Guidelines

### Keywords

Generate 5-7 relevant keywords in the document's language:

**French examples**: `notification, push, mobile, appareil, enregistrement, token, gru, workflow, authentication, cms, identité`

**English examples**: `notification, push, mobile, device, registration, token, gru, workflow, authentication, cms, identity`

### Introduction Section

Provide:
1. **Purpose**: What problem does the plugin solve?
2. **Key Features**: Main functionalities (2-4 sentences)
3. **Integration**: How it fits in the Lutece ecosystem
4. **Use Cases**: Typical scenarios (optional)

Keep concise but informative (3-5 paragraphs maximum).

### Configuration Section

Document in this order:

1. **Properties** (if any exist):
```xml
<p><strong>Propriétés disponibles</strong></p>
<p>Le fichier de configuration <code>{plugin}.properties</code> contient les propriétés suivantes :</p>
<ul>
    <li><code>property.name</code> : Description (valeur par défaut : xxx)</li>
</ul>
```

2. **Spring Beans** (always present):
```xml
<p><strong>Beans Spring à injecter</strong></p>
<p>Les beans suivants doivent être configurés dans le contexte Spring :</p>
<ul>
    <li><code>bean.id</code> : Description (classe : full.class.name)</li>
</ul>
```

3. **Daemons** (if any exist):
```xml
<p><strong>Classes Daemon</strong></p>
<ul>
    <li><code>ClassName</code> : Description</li>
</ul>
```
Or if none: `<p>Ce plugin ne contient aucune classe Daemon à activer.</p>`

4. **Caches** (if any exist):
```xml
<p><strong>Caches</strong></p>
<ul>
    <li><code>CacheName</code> : Description</li>
</ul>
```
Or if none: `<p>Ce plugin ne nécessite aucun cache à activer.</p>`

### Usage Section

Document in this order (omit sections that don't exist):

1. **Admin Rights** (from SQL):
```xml
<p><strong>Droits d'administration</strong></p>
<ul>
    <li><code>RIGHT_ID</code> : Description (niveau X) - Accès via l'URL : ...</li>
</ul>
```

2. **RBAC Resources** (if any exist)

3. **Roles** (from SQL if any exist)

4. **Workgroups** (from SQL if any exist)

5. **Java Services** (always present):
```xml
<p><strong>Services Java exposés</strong></p>
<p><em>ServiceClassName</em> (singleton)</p>
<ul>
    <li><code>methodName(Type param1, Type param2)</code> : Description from JavaDoc</li>
</ul>
```

6. **REST APIs** (if any exist):
```xml
<p><strong>API REST</strong></p>
<p>Le plugin expose les API REST suivantes (base path : <code>/rest/{plugin}/v1</code>) :</p>

<p><em>GET /rest/{plugin}/v1/resource</em></p>
<ul>
    <li>Description : What it does</li>
    <li>Query Parameters : <code>param1</code> (required/optional), <code>param2</code> (optional)</li>
    <li>Headers requis : <code>HEADER_NAME</code> (obligatoire) - Description</li>
    <li>Réponse 200 : Success description (ResponseType)</li>
    <li>Réponse 400 : Error description</li>
    <li>Content-Type : application/json</li>
</ul>
```

7. **Workflow Tasks** (if any exist)

## Language-Specific Content

### French Version
- Use formal "vous" form
- Technical terms: "appareil" (device), "enregistrement" (registration), "jeton" (token)
- Headers: "Droits d'administration", "Services Java exposés", "API REST"
- Descriptions should be clear and professional

### English Version
- Use clear, concise technical English
- Headers: "Administration Rights", "Exposed Java Services", "REST API"
- Maintain parallel structure with French version

## Output Files

Generate two files:
1. `plugin-{name}_fr.xdoc` - French documentation
2. `plugin-{name}_en.xdoc` - English documentation

Save both files to `/mnt/user-data/outputs/` and present them to the user.

### File Placement in Project Structure

The generated XDOC files are intended to be placed in the following locations within the Lutece plugin project:

```
plugin-{name}/
├── src/
│   └── site/
│       ├── xdoc/
│       │   └── index.xml          ← English XDOC (plugin-{name}_en.xdoc renamed)
│       └── fr/
│           └── xdoc/
│               └── index.xml      ← French XDOC (plugin-{name}_fr.xdoc renamed)
```

**File naming convention:**
- The English version `plugin-{name}_en.xdoc` should be renamed to `index.xml` and placed in `src/site/xdoc/`
- The French version `plugin-{name}_fr.xdoc` should be renamed to `index.xml` and placed in `src/site/fr/xdoc/`

### README Generation

After placing the XDOC files in their respective directories, the following Maven command should be executed at the project root to generate README.md files:

```bash
mvn fr.paris.lutece.tools:xdoc2md-maven-plugin:readme
```

This command:
- Reads the XDOC files from `src/site/xdoc/index.xml` and `src/site/fr/xdoc/index.xml`
- Converts them to Markdown format
- Generates two README files:
  - `README.md` (English) at the project root
  - `README_fr.md` (French) at the project root

**Complete workflow:**
```bash
# 1. Generate XDOC files (this skill)
# Output: plugin-{name}_en.xdoc and plugin-{name}_fr.xdoc

# 2. User places files in project structure:
cp plugin-{name}_en.xdoc plugin-{name}/src/site/xdoc/index.xml
cp plugin-{name}_fr.xdoc plugin-{name}/src/site/fr/xdoc/index.xml

# 3. User generates README files:
cd plugin-{name}
mvn fr.paris.lutece.tools:xdoc2md-maven-plugin:readme

# Result: README.md and README_fr.md at project root
```

## Example Workflow

```bash
# 1. Extract and explore
cd /home/claude/plugin-directory
find . -name "*.java" | head -20

# 2. Analyze key files
view pom.xml
view webapp/WEB-INF/conf/plugins/*.properties
view webapp/WEB-INF/conf/plugins/*_context.xml
view src/sql/*/init_core_*.sql

# 3. Examine Java classes
view src/java/*/rs/*Rest.java          # REST APIs
view src/java/*/service/*Service.java   # Services
view src/java/*/business/*DAO.java      # DAOs

# 4. Generate XDOC files
create_file /home/claude/plugin-name_fr.xdoc
create_file /home/claude/plugin-name_en.xdoc

# 5. Copy to outputs and present
cp *.xdoc /mnt/user-data/outputs/
present_files ["/mnt/user-data/outputs/plugin-name_fr.xdoc", "/mnt/user-data/outputs/plugin-name_en.xdoc"]
```

## Common Patterns in Lutece Plugins

### Service Singleton Pattern
```java
private static ServiceName instance;
public static ServiceName getInstance() {
    if (instance == null) {
        instance = new ServiceName();
    }
    return instance;
}
```

### REST API Annotations
```java
@Path(RestConstants.BASE_PATH + Constants.PLUGIN_PATH + Constants.VERSION_PATH_V1)
@GET
@Path("/resource")
@Produces(MediaType.APPLICATION_JSON)
@ApiOperation(value = "Description")
public Response getResource(
    @QueryParam("param") String param,
    @HeaderParam("CLIENT_CODE") String clientCode
)
```

### Spring Bean Injection
```java
@Inject
private IServiceDAO _dao;

// Or via SpringContextService
IServiceDAO dao = SpringContextService.getBean("bean.id");
```

## Quality Checklist

Before generating the final XDOC:
- ✅ Plugin name correctly identified from pom.xml
- ✅ All keywords are relevant and in the correct language
- ✅ Introduction explains purpose and features clearly
- ✅ All Spring beans from context.xml are documented
- ✅ Properties file content is included (if exists)
- ✅ Admin rights from SQL are documented (if exist)
- ✅ All public service methods are listed
- ✅ REST APIs include all HTTP methods, paths, and parameters
- ✅ No HTML heading tags (`<h1>`, `<h2>`, etc.) are used
- ✅ XML is well-formed and valid
- ✅ Both French and English versions are consistent
- ✅ Files are saved to /mnt/user-data/outputs/

**Post-generation reminder for user:**
Inform the user that the generated XDOC files should be:
1. Renamed to `index.xml`
2. Placed in the appropriate directories:
   - English: `src/site/xdoc/index.xml`
   - French: `src/site/fr/xdoc/index.xml`
3. Used to generate README files with: `mvn fr.paris.lutece.tools:xdoc2md-maven-plugin:readme`

## Troubleshooting

**Cannot access repository URL**: Ask user to download and upload the ZIP file

**Missing SQL files**: Document as "No admin rights defined"

**No REST APIs found**: Document as "Ce plugin n'expose aucune API REST" (or English equivalent)

**Complex service methods**: Include method signature and brief description from JavaDoc

**Validation errors**: Ensure XML structure matches the template exactly, with proper nesting
