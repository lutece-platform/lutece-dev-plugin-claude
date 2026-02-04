# Installing Lutecepowers for OpenCode

## Prerequisites

- [OpenCode](https://opencode.ai) installed
- Git installed
- Node.js 20.6+

## Installation

### 1. Clone Lutecepowers

```bash
git clone https://github.com/lutece-platform/lutecepowers.git ~/.config/opencode/lutecepowers
```

### 2. Register the plugin

Create a symlink so OpenCode discovers the plugin:

```bash
mkdir -p ~/.config/opencode/plugins
ln -sf ~/.config/opencode/lutecepowers/.opencode/plugins/lutecepowers.js ~/.config/opencode/plugins/lutecepowers.js
```

### 3. Symlink skills

Create a symlink so OpenCode's native skill tool discovers Lutece skills:

```bash
mkdir -p ~/.config/opencode/skills
ln -sf ~/.config/opencode/lutecepowers/skills ~/.config/opencode/skills/lutecepowers
```

### 4. Pre-clone references (optional)

The plugin clones reference repos automatically on first session start, but you can pre-clone them:

```bash
bash ~/.config/opencode/lutecepowers/scripts/setup-references.sh
```

### 5. Restart OpenCode

The plugin will automatically:
- Inject Lutece 8 architecture context into every session
- Clone reference repositories on first session
- Copy rules to Lutece projects when detected

## Usage

### Loading a skill

```
use skill tool to load lutecepowers/lutece-migration-v8
```

### Available skills

- **lutece-patterns** — Architecture patterns and conventions (auto-injected)
- **lutece-dao** — DAO and Home layer patterns
- **lutece-scaffold** — Plugin scaffold generator
- **lutece-migration-v8** — v7 to v8 migration guide
- **lutece-workflow** — Workflow module patterns
- **lutece-rbac** — RBAC implementation
- **lutece-cache** — Cache service patterns
- **lutece-lucene-indexer** — Lucene search indexer
- **lutece-solr-indexer** — Solr search indexer
- **lutece-elasticdata** — Elasticsearch DataSource
- **lutece-site** — Site generator

### Tool mapping

When skills reference Claude Code tools:
- `TodoWrite` -> `update_plan`
- `Task` with subagents -> `@mention` syntax
- `Skill` tool -> OpenCode's native `skill` tool
- `Read`, `Write`, `Edit`, `Bash` -> your native tools

## Updating

```bash
cd ~/.config/opencode/lutecepowers && git pull
```

## Troubleshooting

### Plugin not loading

1. Check symlink: `ls -l ~/.config/opencode/plugins/lutecepowers.js`
2. Check source: `ls ~/.config/opencode/lutecepowers/.opencode/plugins/lutecepowers.js`
3. Check OpenCode logs for errors

### Skills not found

1. Check symlink: `ls -l ~/.config/opencode/skills/lutecepowers`
2. Verify target: `ls ~/.config/opencode/lutecepowers/skills/`

### References not cloned

Run manually: `bash ~/.config/opencode/lutecepowers/scripts/setup-references.sh`
