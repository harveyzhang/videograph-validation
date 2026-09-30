// 通过 MCP 获取冻结预览，在真实引擎中抽检每镜头并生成可视化验收图。
import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { chromium } from 'playwright-core';
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const projectId = process.argv[2];
if (!projectId) throw new Error('usage: node scripts/project-contact-sheet.mjs <projectId>');
const root = fileURLToPath(new URL('..', import.meta.url));
const client = new Client({ name: 'videograph-visual-audit', version: '1.0.0' });
const transport = new StdioClientTransport({ command: process.execPath, args: ['--experimental-strip-types', '--no-warnings', 'src/pdoom/mcp-server.ts'], cwd: root, stderr: 'pipe' });
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', args: ['--use-angle=d3d11', '--ignore-gpu-blocklist'] });
async function call(name, args) {
  const response = await client.callTool({ name, arguments: args });
  const text = response.content.filter((item) => item.type === 'text').map((item) => item.text).join('\n');
  if (response.isError) throw new Error(text);
  return JSON.parse(text);
}
try {
  await client.connect(transport);
  const project = await call('project_get', { projectId });
  const preview = await call('project_preview', { projectId });
  assert.equal(preview.revision, project.revision, 'project changed while opening preview; retry against a consistent revision');
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto(preview.url + '/?export=1');
  await page.waitForFunction(() => window.__pdoom?.ready || window.__pdoom?.error, null, { timeout: 120000 });
  const result = await page.evaluate(async (shots) => {
    const p = window.__pdoom;
    if (p.error) throw new Error(p.error);
    const sheet = document.createElement('canvas');
    const cw = 384, ch = 216, label = 28, pad = 8, cols = 4;
    sheet.width = cols * (cw + pad) + pad;
    sheet.height = Math.ceil(shots.length / cols) * (ch + label + pad) + pad;
    const ctx = sheet.getContext('2d');
    ctx.fillStyle = '#151517'; ctx.fillRect(0, 0, sheet.width, sheet.height);
    const source = document.getElementById('c');
    let checked = 0;
    for (let i = 0; i < shots.length; i++) {
      const shot = shots[i];
      for (const ratio of [0, .25, .45, .75, .99]) { p.still(shot.start + (shot.end - shot.start) * ratio, 1, .2); checked++; }
      if (p.errors.length) throw new Error(p.errors.join('\n'));
      p.still(shot.start + (shot.end - shot.start) * .45, 1, .2);
      await p.engine.readPixelsAsync();
      const x = pad + (i % cols) * (cw + pad), y = pad + Math.floor(i / cols) * (ch + label + pad);
      ctx.drawImage(source, x, y + label, cw, ch);
      ctx.fillStyle = '#EEE9DF'; ctx.font = '14px Arial'; ctx.fillText(`${String(i + 1).padStart(2, '0')} ${shot.title}`, x + 3, y + 20, cw - 6);
    }
    return { png: sheet.toDataURL('image/png').split(',')[1], checked, errors: p.errors };
  }, project.shots);
  assert.equal(result.checked, project.shots.length * 5);
  assert.deepEqual(result.errors, []);
  assert.deepEqual(errors, []);
  const dir = join(root, '.cache'); mkdirSync(dir, { recursive: true });
  const file = join(dir, `contact-${projectId}-r${project.revision}.png`);
  writeFileSync(file, Buffer.from(result.png, 'base64'), { flag: 'wx' });
  console.log(JSON.stringify({ ok: true, projectId, revision: project.revision, shots: project.shots.length, framesChecked: result.checked, file, errors }, null, 2));
} finally { await browser.close(); await client.close(); }
