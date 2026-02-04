/**
 * Lutecepowers plugin for OpenCode.ai
 *
 * - Injects Lutece 8 bootstrap context via system prompt transform
 * - Clones reference repositories on first session (via setup-references.sh)
 * - Copies rules to Lutece projects (via lutece-rules-setup.sh)
 * - Skills are discovered via OpenCode's native skill tool from symlinked directory
 */

import path from 'path';
import fs from 'fs';
import os from 'os';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(__dirname, '../..');

const stripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  return match ? match[2].trim() : content;
};

const getSkillContent = (skillName) => {
  const skillPath = path.join(pluginRoot, 'skills', skillName, 'SKILL.md');
  if (!fs.existsSync(skillPath)) return null;
  return stripFrontmatter(fs.readFileSync(skillPath, 'utf8'));
};

const getSkillList = () => {
  const skillsDir = path.join(pluginRoot, 'skills');
  if (!fs.existsSync(skillsDir)) return [];
  return fs.readdirSync(skillsDir, { withFileTypes: true })
    .filter(d => d.isDirectory() && fs.existsSync(path.join(skillsDir, d.name, 'SKILL.md')))
    .map(d => {
      const content = fs.readFileSync(path.join(skillsDir, d.name, 'SKILL.md'), 'utf8');
      const descMatch = content.match(/^description:\s*"?(.+?)"?\s*$/m);
      return { name: d.name, description: descMatch ? descMatch[1] : '' };
    });
};

export const LutecepowersPlugin = async ({ $, directory }) => {
  const refsDir = path.join(os.homedir(), '.lutece-references');
  let refsReady = fs.existsSync(path.join(refsDir, 'lutece-core', '.git'));

  return {
    // On new session: clone references + copy rules if needed
    event: async (event) => {
      if (event.type !== 'session.created') return;

      // Clone/update references if not yet done
      if (!refsReady) {
        const setupScript = path.join(pluginRoot, 'scripts', 'setup-references.sh');
        if (fs.existsSync(setupScript)) {
          try {
            execSync(`bash "${setupScript}"`, { stdio: 'pipe', timeout: 120000 });
            refsReady = true;
          } catch (e) { /* non-blocking */ }
        }
      }

      // Copy rules to Lutece project if applicable
      const rulesSetup = path.join(pluginRoot, 'scripts', 'lutece-rules-setup.sh');
      if (fs.existsSync(rulesSetup)) {
        try {
          execSync(`bash "${rulesSetup}"`, {
            stdio: 'pipe',
            timeout: 5000,
            cwd: directory,
            env: { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot }
          });
        } catch (e) { /* non-blocking */ }
      }
    },

    // Inject Lutece bootstrap into every system prompt
    'experimental.chat.system.transform': async (_input, output) => {
      const patternsContent = getSkillContent('lutece-patterns');
      if (!patternsContent) return;

      const skills = getSkillList();
      const skillList = skills.map(s => `- **${s.name}**: ${s.description}`).join('\n');

      const toolMapping = `**Tool Mapping for OpenCode:**
When skills reference Claude Code tools, substitute OpenCode equivalents:
- \`TodoWrite\` -> \`update_plan\`
- \`Task\` tool with subagents -> Use OpenCode's subagent system (@mention)
- \`Skill\` tool -> OpenCode's native \`skill\` tool
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` -> Your native tools
- \`Grep\`, \`Glob\` -> Use \`bash\` with grep/find commands

**References:** Lutece v8 source repos are in \`~/.lutece-references/\` — use file read tools on these repos for real implementation examples.`;

      const bootstrap = `<LUTECE_CONTEXT>
You are working on a Lutece 8 (Jakarta EE / CDI) project.

${patternsContent}

## Available Skills
${skillList}

Use OpenCode's native skill tool to load any skill when needed.

${toolMapping}
</LUTECE_CONTEXT>`;

      (output.system ||= []).push(bootstrap);
    }
  };
};
