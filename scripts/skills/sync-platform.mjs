// sync-platform.mjs — 单一事实源同步：skills/shotcraft/references/platform-videograph.md 的
// 工具速查表由 docs/MCP-GUIDE.md §3 生成；SKILL.md frontmatter 的 toolset 与指南对齐。
// 运行：node scripts/skills/sync-platform.mjs；mcp-guide-sync 测试兜底。
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
const guidePath = join(root, 'docs', 'MCP-GUIDE.md');
const platformPath = join(root, 'skills', 'shotcraft', 'references', 'platform-videograph.md');
const skillPath = join(root, 'skills', 'shotcraft', 'SKILL.md');

const guide = readFileSync(guidePath, 'utf8');
const toolsetDate = /^toolset:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})/m.exec(guide)?.[1];
if (!toolsetDate) throw new Error('MCP-GUIDE.md 缺少 toolset 版本行');

const section3 = guide.split(/^## 3\. 工具参考.*$/m)[1]?.split(/^## \d/m)[0] ?? '';
if (!section3.trim()) throw new Error('MCP-GUIDE.md 找不到 §3 工具参考');
const tools = [...section3.matchAll(/^\| `([a-z_]+)` \|([^|]*)\|(.+?)\|\s*$/gm)].map((m) => ({
  name: m[1], args: m[2].trim(), desc: m[3].trim().replace(/\\\|/g, '|'),
}));
if (tools.length < 10) throw new Error(`§3 工具行解析异常：仅 ${tools.length} 条`);

const section2 = guide.split(/^## 2\. 核心概念.*$/m)[1]?.split(/^## \d/m)[0] ?? '';
const rules = [...section2.matchAll(/^\d+\.\s+(.+?)$/gm)].map((m) => m[1].replace(/\*\*/g, '').split('。')[0] + '。');

const shorten = (text, limit = 72) => text.length <= limit ? text : text.slice(0, limit - 1) + '…';
const block = [
  `**工具速查（自动生成自 \`docs/MCP-GUIDE.md\` §3，toolset ${toolsetDate}；勿手编——更新请跑 \`node scripts/skills/sync-platform.mjs\`）**`,
  '',
  '| 工具 | 参数 | 作用 |',
  '|---|---|---|',
  ...tools.map((tool) => `| \`${tool.name}\` | ${tool.args ? shorten(tool.args, 60) : '—'} | ${shorten(tool.desc)} |`),
  '',
  `硬规则：${rules.join(' ')}`,
].join('\n');

const platform = readFileSync(platformPath, 'utf8');
const begin = '<!-- BEGIN:generated-from-MCP-GUIDE (scripts/skills/sync-platform.mjs 自动生成；勿手编) -->';
const end = '<!-- END:generated-from-MCP-GUIDE -->';
const start = platform.indexOf(begin), stop = platform.indexOf(end);
if (start < 0 || stop < 0 || stop < start) throw new Error('platform-videograph.md 缺少生成标记；请先手工放入 BEGIN/END 注释对');
writeFileSync(platformPath, platform.slice(0, start + begin.length) + '\n\n' + block + '\n' + platform.slice(stop), 'utf8');

const skill = readFileSync(skillPath, 'utf8');
if (!/^toolset: .+$/m.test(skill)) throw new Error('SKILL.md frontmatter 缺少 toolset 行');
writeFileSync(skillPath, skill.replace(/^toolset: .*$/m, `toolset: ${toolsetDate}`), 'utf8');
console.log(`synced: ${tools.length} tools, toolset ${toolsetDate}`);
