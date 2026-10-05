// 独立实例的真实 MCP + GPU + UI 验收。只创建测试工程，不改已有工程。
import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { chromium } from 'playwright-core';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
const root = fileURLToPath(new URL('..', import.meta.url));
const studio = process.env.AUDIT_STUDIO_URL ?? 'http://127.0.0.1:5288';
if (!process.env.VIDEOGRAPH_SERVICE_URL || !process.env.VIDEOGRAPH_SERVICE_TOKEN_FILE) throw new Error('必须显式选择独立验证服务和令牌文件');
const client = new Client({ name: 'videograph-transition-audit', version: '1.0' });
const transport = new StdioClientTransport({ command: process.execPath, args: ['--experimental-strip-types', '--no-warnings', 'src/pdoom/mcp-server.ts'], cwd: root, env: process.env, stderr: 'pipe' });
let browser;
async function invoke(name, args, expectError = false) {
  const response = await client.callTool({ name, arguments: args });
  const text = response.content.filter((item) => item.type === 'text').map((item) => item.text).join('\n');
  if (expectError) { assert.equal(response.isError, true, text); return text; }
  if (response.isError) throw new Error(text);
  return JSON.parse(text);
}
const colorScene = (r, g, b) => `import { Scene } from '../engine/scene';
import { FSPass } from '../engine/gl';
import { browserPath, angleArgs } from '../src/server/browser.mjs';
export default class TestScene extends Scene {
 pass = new FSPass('void main(){fragColor=vec4(${r},${g},${b},1.);}');
 render(f,out){this.pass.render(this.ctx.renderer,out);return {bloom:0,halation:0,grain:0,ca:0,vignette:0,hud:0,frame:0,pdoom:0};}
 dispose(){this.pass.mat.dispose();}
}`;
try {
  await client.connect(transport);
  let project = await invoke('project_create_from_bgm', { audioPath: join(root, '../pdoom-video/audio/pdoom.mp3'), name: `转场集成验收 ${Date.now()}` });
  const projectId = project.id;
  const left = project.shots[0], right = project.shots[1];
  project = await invoke('project_shot_submit', { projectId, shotId: left.id, expectedInputRevision: left.inputRevision, code: colorScene('.25', '0.', '0.'), summary: '测试用红色场，不是创作产物' });
  project = await invoke('project_shot_submit', { projectId, shotId: right.id, expectedInputRevision: right.inputRevision, code: colorScene('0.', '0.', '.25'), summary: '测试用蓝色场，不是创作产物' });
  const transitionId = project.transitions[0].id;
  const errors = [];
  browser = await chromium.launch({ headless: true, executablePath: browserPath(), args: [...angleArgs(), '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1680, height: 1000 } });
  page.on('pageerror', (error) => errors.push(error.message));
  const checks = [];
  for (const mode of ['dissolve', 'wipe', 'dip', 'cut']) {
    const tr = project.transitions.find((entry) => entry.id === transitionId);
    project = await invoke('project_transition_configure', { projectId, transitionId, expectedInputRevision: tr.inputRevision, config: { mode, duration: mode === 'cut' ? 0 : .3, easing: 'linear', direction: 'left' } });
    const preview = await invoke('project_preview', { projectId, transitionId });
    await page.goto(`${preview.url}/?export=1&only=${left.id},${right.id}`);
    await page.waitForFunction(() => window.__pdoom?.ready || window.__pdoom?.error, null, { timeout: 60000 });
    const sampled = await page.evaluate(async ({ boundary, mode }) => {
      const p = window.__pdoom;
      if (p.error || p.errors.length) throw new Error(p.error || p.errors.join('\n'));
      const sample = async (t) => {
        p.still(t, 1, .2); const pixels = await p.engine.readPixelsAsync();
        return [.1, .5, .9].map((x) => { const k = (Math.floor(p.height / 2) * p.width + Math.floor(x * p.width)) * 4; return [...pixels.slice(k, k + 3)]; });
      };
      return { before: await sample(boundary - .02), start: await sample(boundary), middle: await sample(boundary + .15), end: await sample(boundary + .3), errors: p.errors };
    }, { boundary: Math.round(right.start * 30) / 30, mode });
    console.log(JSON.stringify({ mode, sampled }));
    const isRed = (rgb) => rgb[0] > 100 && rgb[2] < 10;
    const isBlue = (rgb) => rgb[2] > 100 && rgb[0] < 10;
    assert.ok(isRed(sampled.before[1]), `${mode}: previous scene missing`);
    assert.ok(isBlue(sampled.end[1]), `${mode}: next scene missing`);
    if (mode === 'cut') assert.ok(isBlue(sampled.start[1]));
    else assert.ok(isRed(sampled.start[1]), `${mode}: transition must start after the cut`);
    if (mode === 'dissolve') assert.ok(sampled.middle[1][0] > 50 && sampled.middle[1][2] > 50);
    if (mode === 'wipe') { assert.ok(isBlue(sampled.middle[0])); assert.ok(isRed(sampled.middle[2])); }
    if (mode === 'dip') assert.ok(sampled.middle[1].every((value) => value < 25));
    assert.deepEqual(sampled.errors, []);
    checks.push({ mode, middle: sampled.middle });
    await page.goto('about:blank');
  }
  const tr = project.transitions.find((entry) => entry.id === transitionId);
  await invoke('project_transition_configure', { projectId, transitionId, expectedInputRevision: tr.inputRevision - 1, config: { mode: 'cut' } }, true);
  await invoke('project_transition_configure', { projectId, transitionId, expectedInputRevision: tr.inputRevision, config: { mode: 'dissolve', duration: 99 } }, true);
  const job = await invoke('project_transition_validate', { projectId, transitionId });
  let finished;
  const deadline = Date.now() + 90000;
  while (Date.now() < deadline) {
    finished = await invoke('project_job_get', { projectId, jobId: job.id });
    if (['done', 'error', 'cancelled'].includes(finished.status)) break;
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  assert.equal(finished.status, 'done', finished.error);
  assert.equal(finished.result.reports[0].samples, 5);
  const context = await invoke('project_shot_lyrics', { projectId, shotId: project.shots[2].id });
  await invoke('project_shot_update', { projectId, shotId: project.shots[2].id, expectedInputRevision: project.shots[2].inputRevision,
    patch: { lyricPlan: { summary: 'invalid quote', elements: [{ name: 'wrong', quote: 'this is not a lyric', meaning: 'x', treatment: 'x' }] } } }, true);
  assert.ok(context.lines.length > 0);
  await page.goto(`${studio}/?view=project&project=${projectId}`);
  await page.waitForSelector('.timeline-transition', { timeout: 30000 });
  assert.equal(await page.locator('.timeline-shot').count(), 22);
  assert.equal(await page.locator('.timeline-transition').count(), 21);
  await page.locator('.project-transition-nav summary').click();
  await page.locator('.project-transition-nav button').first().click();
  await page.getByRole('button', { name: '预览这段转场', exact: true }).click();
  await page.frameLocator('iframe').locator('#info').filter({ hasText: 'beat' }).waitFor({ timeout: 60000 });
  const screenshot = join(root, '.cache', `transition-ui-${Date.now()}.png`);
  await page.screenshot({ path: screenshot });
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({ ok: true, projectId, checks, validatedJob: job.id, nodes: 21, screenshot, errors }, null, 2));
} finally { await browser?.close(); await client.close(); }
