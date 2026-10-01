// install.mjs — 把仓库内 skills/shotcraft 安装给 agent 使用。
// 默认项目级 .claude/skills/shotcraft；--user 显式指定才写用户目录 ~/.zcode/skills/shotcraft。
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const root = fileURLToPath(new URL('../..', import.meta.url));
const source = join(root, 'skills', 'shotcraft');
const args = process.argv.slice(2);
const userMode = args.includes('--user');
if (args.some((arg) => arg !== '--user') || args.length > (userMode ? 1 : 0)) {
  console.error('用法：node scripts/skills/install.mjs [--user]');
  process.exit(2);
}
if (!existsSync(join(source, 'SKILL.md'))) { console.error('仓库缺少 skills/shotcraft/SKILL.md'); process.exit(1); }
const target = userMode ? join(homedir(), '.zcode', 'skills', 'shotcraft') : join(root, '.claude', 'skills', 'shotcraft');
rmSync(target, { recursive: true, force: true });
mkdirSync(dirname(target), { recursive: true });
cpSync(source, target, { recursive: true });
const count = (dir) => readdirSync(dir, { withFileTypes: true }).reduce((sum, entry) => sum + (entry.isDirectory() ? count(join(dir, entry.name)) : 1), 0);
console.log(`已安装 shotcraft → ${target}（${count(target)} 个文件${userMode ? '，用户级' : '，项目级'}）`);
