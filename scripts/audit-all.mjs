import { existsSync, readFileSync, readdirSync, writeFileSync, unlinkSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('..', import.meta.url));
const queue = join(root, '.queue');
const fixtureFiles = ['req-mcptest-1.json', 'res-mcptest-1.json'].map((name) => join(queue, name));
if (existsSync(queue) && readdirSync(queue).some((name) => name.startsWith('req-') || name.startsWith('res-'))) {
  throw new Error('队列已有工作，请等待处理完成再运行回归；验收不会覆盖已有请求。');
}
const snapshotPath = join(queue, 'cards.json');
const snapshot = existsSync(snapshotPath) ? readFileSync(snapshotPath) : null;
const allScripts = ['shot-validation-audit', 'shot-mcp-audit', 'shot-demo-audit', 'mcp-server-test', 'pdoom-audit', 'creative-audit'];
const scripts = process.argv.length > 2 ? process.argv.slice(2) : allScripts;
if (scripts.some((script) => !allScripts.includes(script))) throw new Error('unknown audit script');
const failed = [];
try {
  for (const script of scripts) {
    console.log(`\n=== ${script} ===`);
    const result = spawnSync(process.execPath, [`scripts/${script}.mjs`], { cwd: root, stdio: 'inherit', timeout: 180000 });
    if (result.status !== 0) { failed.push(script); console.error(result.error?.message ?? `exit ${result.status}`); }
  }
} finally {
  if (snapshot) writeFileSync(snapshotPath, snapshot);
  else if (existsSync(snapshotPath)) unlinkSync(snapshotPath);
  // 开始时已确认不存在；只清理本轮 stdio 测试创建的这两个固定 fixture。
  for (const file of fixtureFiles) if (existsSync(file)) unlinkSync(file);
}
if (failed.length) { console.error(`FAILED: ${failed.join(', ')}`); process.exitCode = 1; }
else console.log(`PASS: ${scripts.length} audits`);
