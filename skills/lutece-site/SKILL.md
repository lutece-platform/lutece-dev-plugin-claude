---
name: lutece-site
description: "Interactive Lutece 8 site generator. Creates a site with database configuration and optional plugin dependencies."
---

# Lutece 8 Site Generator

Generate a Lutece 8 site through interactive questioning. A site is the deployable application that assembles lutece-core and plugins.

## Process Overview

```
Phase 1: Site Info       → Name, description, output directory
Phase 2: Database        → MySQL credentials (mandatory confirmation)
Phase 3: Plugins         → Plugin/module dependencies (optional)
Phase 3b: Compatibility  → Verify Lutece 8 compatibility via GitHub
Phase 4: Generation      → Execute script, generate site
```

## Phase 1: Site Info

Ask one question at a time:
1. Site name? (lowercase with hyphens, e.g., "site-taskmanager")
2. Site description? (e.g., "Test site for the taskmanager plugin")
3. Output directory? (where to generate)

## Phase 2: Database

**Display the default credentials table and ask for confirmation:**

```
Database configuration for the site:

| Parameter | Value |
|-----------|--------|
| Host      | localhost |
| Port      | 3306 |
| Database  | lutece_{siteName} (hyphens → underscores) |
| User      | root |
| Password  | ??? |

Are these values correct? (yes/no or specify changes)
```

**IMPORTANT:**
- ALWAYS display this table BEFORE generating
- WAIT for explicit user confirmation
- If the user says "no" or specifies changes, update the values
- NEVER generate without credentials confirmation

## Phase 3: Plugins (optional)

- "Do you want to add plugins to the site?"
- If **no**: bare site (lutece-core only)
- If **yes**: the user can provide plugins in any format:

### Input formats

The user can give a plugin name at any level of precision:

| User input | Action |
|------------|--------|
| `forms` | **Search** GitHub for repos matching "forms", present results, let user pick |
| `plugin-forms` | Direct artifactId, apply smart defaults |
| `plugin-forms:4.0.0-SNAPSHOT` | ArtifactId with explicit version |
| `fr.paris.lutece.plugins:plugin-forms:[4.0.0-SNAPSHOT,):lutece-plugin` | Full Maven coordinates |

### Search by keyword

When the user provides just a keyword (no `plugin-` or `module-` prefix), **search GitHub** to find matching repos:

```bash
# Search both orgs
curl -s "https://api.github.com/search/repositories?q=org:lutece-platform+{keyword}+in:name&per_page=10" | jq -r '.items[] | "\(.name) — \(.description // "no desc")"'
curl -s "https://api.github.com/search/repositories?q=org:lutece-secteur-public+{keyword}+in:name&per_page=10" | jq -r '.items[] | "\(.name) — \(.description // "no desc")"'
```

Then present the results and let the user pick:

```
Found plugins matching "forms":

  1. plugin-forms — Complete and flexible form management system (lutece-platform)
  2. module-workflow-forms — Workflow module for Forms (lutece-platform)
  3. module-forms-solr — Search module for forms (lutece-platform)

Which one(s)? (number or comma-separated)
```

**Extracting the artifactId from the repo name:** strip the category prefix.
- `lutece-form-plugin-forms` → `plugin-forms`
- `lutece-wf-module-workflow-forms` → `module-workflow-forms`
- Pattern: repo name is `lutece-{category}-{artifactId}`, strip `lutece-{category}-`

### Smart defaults

For resolved plugins:
- `groupId` = `fr.paris.lutece.plugins`
- `version` = resolved from `develop_core8` pom.xml in Phase 3b (fallback: `[1.0.0-SNAPSHOT,)`)
- `type` = `lutece-plugin`

After each plugin: "Another plugin?"

## Phase 3b: Lutece 8 Compatibility Check

After collecting all plugins, verify each one for Lutece 8 compatibility by checking the **parent POM version** on GitHub.

### Strategy

The only reliable way to confirm Lutece 8 compatibility is to check the `<parent><version>` in `pom.xml`. The branch name alone is NOT sufficient:
- Some plugins use `develop_core8` for v8
- Some newer plugins are v8-only and use `develop` directly
- Some plugins have been migrated to v8 on `develop`

For each plugin added by the user:

1. **Find the repository** - Search both GitHub organizations using `curl` (no auth required):
   - `lutece-platform` (core platform)
   - `lutece-secteur-public` (public sector)
   - `curl -s "https://api.github.com/search/repositories?q=org:{org}+{artifactId}+in:name&per_page=3" | jq -r '.items[].name'`
   - The repo name is NOT predictable from the artifactId (e.g., `plugin-forms` → `lutece-form-plugin-forms`)

2. **Find the v8 branch** - Check branches in priority order:
   - List branches: `curl -s "https://api.github.com/repos/{org}/{repo}/branches?per_page=100" | jq -r '.[].name'`
   - Check in this order:
     1. `develop_core8` (explicit v8 branch)
     2. `develop` (may be v8 for newer/migrated plugins)
     3. `master` / `main` (last resort)

3. **Read pom.xml and check parent version** - This is the **only reliable check**:
   - `curl -s "https://raw.githubusercontent.com/{org}/{repo}/{branch}/pom.xml"`
   - Extract parent `<version>`: if `8.0.0-SNAPSHOT` → **Lutece 8 confirmed**
   - Extract plugin `<version>` for the dependency version
   - If `develop_core8` has parent `8.0.0-SNAPSHOT` → use this branch
   - If `develop_core8` doesn't exist, check `develop` pom.xml → if parent is `8.0.0-SNAPSHOT` → v8 on develop
   - If neither branch has parent `8.0.0-SNAPSHOT` → **NOT v8 compatible**

4. **Report results** - Display a compatibility summary table:

```
Lutece 8 compatibility check:

| Plugin | Repo | Branch | Parent POM | Version | Status |
|--------|------|--------|------------|---------|--------|
| plugin-forms | lutece-form-plugin-forms | develop_core8 | 8.0.0-SNAPSHOT | 4.0.0-SNAPSHOT | OK |
| plugin-workflow | lutece-wf-plugin-workflow | develop_core8 | 8.0.0-SNAPSHOT | 7.0.0-SNAPSHOT | OK |
| plugin-myapp | lutece-tech-plugin-myapp | develop | 8.0.0-SNAPSHOT | 1.0.0-SNAPSHOT | OK (v8 on develop) |
| plugin-announce | lutece-collab-plugin-announce | develop | 7.0.2 | 3.1.4-SNAPSHOT | NOT v8 |
```

### Handling results

- **All OK**: Proceed to Phase 4, use the detected versions
- **NOT v8 compatible**: Warn the user. Ask whether to:
  - Remove the incompatible plugin
  - Keep it anyway (user knows it works or plans to migrate)
  - Skip (user will handle it later)
- **Repo not found**: The plugin may be local/custom. Skip check, keep user-provided version.

### Version resolution

When a v8-compatible branch is found, **use the version from its pom.xml** instead of the generic `[1.0.0-SNAPSHOT,)`. This ensures the correct v8 version range:
- `plugin-forms` on v8 → `[4.0.0-SNAPSHOT,)` (not `[1.0.0-SNAPSHOT,)`)
- `plugin-workflow` on v8 → `[7.0.0-SNAPSHOT,)` (not `[1.0.0-SNAPSHOT,)`)

If the user already provided an explicit version, keep theirs.

If the user already provided an explicit version, keep theirs.

### Reference: Branch conventions

| Branch | Lutece version | Parent POM |
|--------|---------------|------------|
| `develop_core8` | Lutece 8 | `8.0.0-SNAPSHOT` |
| `develop` | Lutece 7 | `7.x.x` |
| `master` | Stable release (usually v7) | varies |

## Phase 4: Generation

1. Build JSON config from answers
2. Write config to `/tmp/{siteName}-config.json`
3. Run: `bash {lutecepowers_scripts_dir}/lutece-site.sh <config> <output>`
4. Show summary

### JSON Config Format

```json
{
  "siteName": "site-taskmanager",
  "siteDescription": "Test site for taskmanager",
  "database": {
    "name": "lutece_site_taskmanager",
    "user": "root",
    "password": "root",
    "host": "localhost",
    "port": 3306
  },
  "plugins": [
    {
      "groupId": "fr.paris.lutece.plugins",
      "artifactId": "plugin-taskmanager",
      "version": "[1.0.0-SNAPSHOT,)",
      "type": "lutece-plugin"
    },
    {
      "groupId": "fr.paris.lutece.plugins",
      "artifactId": "plugin-workflow",
      "version": "[7.0.0-SNAPSHOT,)",
      "type": "lutece-plugin"
    }
  ]
}
```

### Generated Files

```
{siteName}/
├── pom.xml                                          # Maven config (lutece-site packaging)
├── README.md                                        # Build/run instructions
└── src/conf/default/WEB-INF/conf/
    └── db.properties                                # MySQL connection
```

## Example Flow

```
User: /lutece-site
Assistant: Site name?
User: site-taskmanager
Assistant: Site description?
User: Test site for the taskmanager plugin
Assistant: Output directory?
User: /home/user/sites
Assistant:
Database configuration for the site:

| Parameter | Value |
|-----------|--------|
| Host      | localhost |
| Port      | 3306 |
| Database  | lutece_site_taskmanager |
| User      | root |
| Password  | ??? |

Are these values correct?
User: yes, password = root
Assistant: Do you want to add plugins to the site?
User: yes, forms, workflow
Assistant:
Found plugins matching "forms":
  1. plugin-forms — Complete and flexible form management system (lutece-platform)
  2. module-workflow-forms — Workflow module for Forms (lutece-platform)
  3. module-forms-solr — Search module for forms (lutece-platform)

Which one(s)?
User: 1, 2
Assistant:
Found plugins matching "workflow":
  1. plugin-workflow — Workflow engine for other Lutece plugins (lutece-platform)
  2. module-workflow-forms — Workflow module for Forms (already added)
  3. library-workflow-core — Library Workflow Core (lutece-platform)

Which one(s)?
User: 1
Assistant: Another plugin?
User: no
Assistant:
Checking Lutece 8 compatibility...

| Plugin | Repo | Branch | Version | Status |
|--------|------|--------|---------|--------|
| plugin-forms | lutece-form-plugin-forms | develop_core8 | 4.0.0-SNAPSHOT | OK |
| module-workflow-forms | lutece-wf-module-workflow-forms | develop_core8 | 4.0.0-SNAPSHOT | OK |
| plugin-workflow | lutece-wf-plugin-workflow | develop_core8 | 7.0.0-SNAPSHOT | OK |

All plugins OK. Proceeding with generation.

Site generated!
  Directory: /home/user/sites/site-taskmanager
  Database: lutece_site_taskmanager
  Plugins: 3

Next steps:
  1. cd /home/user/sites/site-taskmanager
  2. mvn lutece:site-assembly
  3. cd target/site-taskmanager-1.0.0-SNAPSHOT/WEB-INF/sql && ant
  4. cd ../../../.. && mvn liberty:dev
  5. Open http://localhost:9080/site-taskmanager-1.0.0-SNAPSHOT/
```

## Key Principles

- **One question at a time** - Don't overwhelm the user
- **Accept shortcuts** - "plugin-forms" is enough, smart defaults for the rest
- **Credentials confirmation** - MANDATORY before generation
- **Bare site possible** - No plugins required
