import assert from 'node:assert/strict';
import { chromium } from 'playwright-core';

// 真实浏览器驱动工坊；API 与队列用本地路由夹具，不发送真实模型请求、不修改用户队列。
const base = process.env.AUDIT_URL ?? 'http://127.0.0.1:5188';
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const good = 'export function draw(ctx,f,api){ctx.fillStyle=api.palette.ink;ctx.fillRect(0,0,f.W,f.H);ctx.fillStyle=api.palette.signal;ctx.fillRect(f.W*.2,f.H*.3,f.W*.6,f.H*.4);}';
const late = 'export function draw(ctx,f,api){if(f.p>.6)throw new Error("late-frame-test");ctx.fillRect(0,0,f.W,f.H);}';
const fence = (code) => '```ts\n' + code + '\n```\nSUMMARY: audit scene';
const result = {};

async function fixture(provider = false) {
  const context = await browser.newContext({ viewport: { width: 1600, height: 1000 } });
  if (provider) await context.addInitScript(() => localStorage.setItem('videograph.providers.v1', JSON.stringify({
    activeId: 'audit-provider', providers: [{ id: 'audit-provider', name: 'Audit', kind: 'openai', baseUrl: 'https://example.invalid/v1', apiKey: 'not-a-real-key', model: 'audit-model' }],
  })));
  const page = await context.newPage();
  const pageErrors = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));
  const requests = [];
  const pending = new Map();
  const acked = [];
  let state = { savedAt: 0, cards: [] };
  let answer = (request) => ({ status: 'done', content: fence(good), model: 'audit-mcp' });
  let failPoll = false;
  await page.route('**/queue/**', async (route) => {
    const url = new URL(route.request().url());
    const body = route.request().method() === 'POST' ? route.request().postDataJSON() : null;
    let data;
    if (url.pathname === '/queue/request') {
      requests.push(body);
      pending.set(body.id, body);
      data = { ok: true, id: body.id };
    } else if (url.pathname === '/queue/poll') {
      if (failPoll) { await route.fulfill({ status: 503, body: 'offline-test' }); return; }
      data = { results: url.searchParams.get('ids').split(',').map((id) => ({ id, ...(pending.has(id) ? answer(pending.get(id)) : null) ?? { status: 'pending' } })) };
    } else if (url.pathname === '/queue/ack') {
      for (const id of body.ids) { acked.push(id); pending.delete(id); }
      data = { ok: true };
    } else if (url.pathname === '/queue/state') {
      if (body) state = { savedAt: Date.now(), cards: body.cards };
      data = state;
    } else data = { requests: [...pending.values()] };
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify(data) });
  });
  return { context, page, pageErrors, requests, pending, acked, setAnswer: (fn) => { answer = fn; }, setOffline: (value) => { failPoll = value; } };
}

async function openShot(f) {
  await f.page.goto(`${base}/?view=shot`);
  await f.page.getByRole('button', { name: '内置参考规划', exact: true }).click();
  await f.page.waitForFunction(() => document.querySelectorAll('.plan-card').length === 22);
  await f.page.locator('.plan-card').nth(1).click();
  await f.page.waitForSelector('.shot-dock');
}
const generate = (page) => page.getByRole('button', { name: '生成场景代码', exact: true }).click();
const waitChip = (page, label) => page.waitForFunction((text) => document.querySelector('.plan-card.is-selected .cache-chip')?.textContent?.includes(text), label, { timeout: 25000 });

try {
  const f = await fixture();
  await f.page.goto(`${base}/?view=shot`);
  result.contract = await f.page.evaluate(async ({ good, late }) => {
    const { validateShotScene } = await import('/src/shot/validation.ts');
    const { ShotGenerationController } = await import('/src/shot/generation.ts');
    const { FULL_SONG } = await import('/src/shot/engine.ts');
    const { builtinPlan } = await import('/src/shot/planner.ts');
    const { builtinSceneForCard } = await import('/src/shot/builtinScenes.ts');
    const { compileShotScene, drawShotFrame, makeShotCtx } = await import('/src/shot/runtime.ts');
    const checks = {};
    const w = { start: 10, end: 14 };
    const valid = validateShotScene(good, w);
    checks.fiveSamples = valid.ok && valid.samples === 5;
    const bad = validateShotScene(late, w);
    checks.lateFailure = !bad.ok && bad.issue.stage === 'render' && bad.issue.t === 13 && bad.samples === 3;
    checks.empty = !validateShotScene('', w).ok;
    checks.syntax = validateShotScene('export function draw( {', w).issue.stage === 'compile';
    checks.missingExport = validateShotScene('export const a=1;', w).issue.stage === 'compile';
    checks.lint = validateShotScene('export function draw(){Math.random()}', w).issue.stage === 'lint';
    checks.darkIsValid = validateShotScene('export function draw(ctx,f){ctx.fillStyle="#0A0A0B";ctx.fillRect(0,0,f.W,f.H)}', w).ok;
    checks.allTemplates = builtinPlan().every((card) => validateShotScene(builtinSceneForCard(card).code, card.window).ok);
    const canvas = document.createElement('canvas'); canvas.width = 200; canvas.height = 100;
    const draw = compileShotScene('export function draw(ctx,f){ctx.translate(20,0);ctx.fillStyle="red";ctx.fillRect(0,0,30,30);}');
    const ctx = makeShotCtx(w);
    drawShotFrame(ctx, draw, canvas, 11); const before = canvas.toDataURL();
    drawShotFrame(ctx, draw, canvas, 11); checks.canvasReset = before === canvas.toDataURL();

    const card = { id: 'a', title: 'A', anchor: 'test', prompt: 'original', window: w };
    const controller = new ShotGenerationController(FULL_SONG);
    controller.replacePlan([card]);
    let calls = 0;
    const executor = { source: 'llm', parallel: false, async generate(_card, _signal, repair) {
      calls++;
      if (repair && (repair.issue.t !== 13 || repair.code !== late)) throw new Error('repair lost diagnostic');
      return { code: calls === 1 ? late : good, summary: 'fixed' };
    } };
    await controller.generate(['a'], executor);
    let entry = controller.getSnapshot()[0];
    checks.repair = calls === 2 && entry.status === 'ready' && entry.validation.attempt === 1 && entry.rev === 1;
    const artifact = entry.artifact;
    calls = 0;
    await controller.generate(['a'], { ...executor, async generate() { calls++; return { code: late, summary: 'bad' }; } });
    entry = controller.getSnapshot()[0];
    checks.bounded = calls === 3 && entry.status === 'error' && entry.validation.failures.length === 3;
    checks.keepGoodArtifact = entry.artifact === artifact && entry.rev === 1;
    calls = 0;
    await controller.generate(['a'], { ...executor, async generate() { calls++; throw new Error('HTTP 401'); } });
    checks.noTransportRetry = calls === 1 && controller.getSnapshot()[0].error.includes('401');

    let release;
    const held = { ...executor, generate: () => new Promise((resolve) => { release = resolve; }) };
    const task = controller.generate(['a'], held);
    controller.editPrompt('a', 'new intent');
    release({ code: good, summary: 'obsolete' }); await task;
    entry = controller.getSnapshot()[0];
    checks.editFence = entry.status === 'stale' && entry.card.prompt === 'new intent' && entry.inputRevision === 1 && entry.rev === 1;
    const task2 = controller.generate(['a'], held);
    controller.replacePlan([card]);
    release({ code: good, summary: 'old plan' }); await task2;
    entry = controller.getSnapshot()[0];
    checks.replanFence = entry.status === 'planned' && !entry.artifact && entry.rev === 0;
    return checks;
  }, { good, late });
  for (const [name, passed] of Object.entries(result.contract)) assert.equal(passed, true, name);
  assert.deepEqual(f.pageErrors, []);
  await f.context.close();

  const mcp = await fixture();
  mcp.setAnswer((request) => ({ status: 'done', content: fence(request.prompt.user.includes('自动修复 1/2') ? good : late), model: 'audit-mcp' }));
  await openShot(mcp);
  await generate(mcp.page);
  await waitChip(mcp.page, '就绪');
  assert.equal(mcp.requests.length, 2);
  assert.ok(mcp.requests[1].prompt.user.includes('late-frame-test'));
  assert.ok(mcp.requests[1].prompt.user.includes('上一版失败代码'));
  assert.ok(mcp.requests[1].prompt.system.includes('引擎契约'));
  assert.match(await mcp.page.locator('.shot-validation').textContent(), /已通过 5 帧抽检/);
  result.mcpRepair = { requests: mcp.requests.length, diagnostic: true };

  mcp.setAnswer(() => ({ status: 'done', content: fence(late), model: 'audit-mcp' }));
  await mcp.page.locator('.shot-dock textarea').fill('limit-test');
  await generate(mcp.page);
  await waitChip(mcp.page, '出错');
  assert.equal(mcp.requests.length, 5);
  assert.match(await mcp.page.locator('.shot-dock').textContent(), /已用完 2 次自动修复/);
  assert.equal(await mcp.page.getByRole('button', { name: '播放这一段', exact: true }).isDisabled(), true);
  result.mcpLimit = true;

  mcp.setAnswer(() => ({ status: 'error', error: 'agent 拒绝测试' }));
  await generate(mcp.page);
  await waitChip(mcp.page, '出错');
  assert.equal(mcp.requests.length, 6);
  assert.match(await mcp.page.locator('.shot-dock').textContent(), /agent 拒绝测试/);
  result.mcpReject = true;

  mcp.setAnswer(() => ({ status: 'pending' }));
  await generate(mcp.page);
  await waitChip(mcp.page, '生成中');
  await mcp.page.waitForTimeout(100);
  await mcp.page.locator('.shot-dock textarea').fill('changed-during-request');
  await waitChip(mcp.page, '待重算');
  mcp.setAnswer(() => ({ status: 'done', content: fence(good), model: 'too-late' }));
  await mcp.page.waitForTimeout(3000);
  await waitChip(mcp.page, '待重算');
  result.mcpCancelledEdit = true;
  assert.equal(mcp.pending.size, 0);
  assert.deepEqual(mcp.pageErrors, []);
  await mcp.page.screenshot({ path: 'shot-validation-mcp.png' });
  await mcp.context.close();

  const api = await fixture(true);
  const apiRequests = [];
  await api.page.route('**/llm-proxy/**', async (route) => {
    const body = route.request().postDataJSON();
    apiRequests.push(body);
    const user = body.messages.find((m) => m.role === 'user').content;
    if (user.includes('deny-test')) { await route.fulfill({ status: 401, body: 'audit unauthorized' }); return; }
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify({ choices: [{ message: { content: fence(apiRequests.length === 1 ? late : good) } }] }) });
  });
  await openShot(api);
  await generate(api.page);
  await waitChip(api.page, '就绪');
  assert.equal(apiRequests.length, 2);
  assert.ok(apiRequests[1].messages.some((message) => message.content.includes('自动修复 1/2')));
  await generate(api.page);
  await waitChip(api.page, '就绪');
  assert.equal(apiRequests.length, 2, 'exact repair requests should use cache');
  result.apiRepairAndCache = true;
  await api.page.getByRole('button', { name: '关闭镜头预览', exact: true }).click();
  await api.page.getByRole('button', { name: '批量生成场景', exact: true }).click();
  await api.page.waitForFunction(() => [...document.querySelectorAll('.plan-card .cache-chip')].every((chip) => chip.textContent.includes('就绪')), null, { timeout: 20000 });
  assert.equal(apiRequests.length, 23, 'bulk API must not route to templates');
  const footers = await api.page.locator('.plan-card .node-footer').allTextContents();
  assert.ok(footers.every((footer) => footer.includes('LLM')));
  result.apiBulk = { calls: apiRequests.length, ready: 22 };
  await api.page.locator('.react-flow__controls-fitview').click();
  await api.page.screenshot({ path: 'shot-validation-api-bulk.png' });
  await api.page.locator('.plan-card').nth(1).click();
  await api.page.locator('.shot-dock textarea').fill('deny-test');
  await generate(api.page);
  await waitChip(api.page, '出错');
  assert.equal(apiRequests.length, 24);
  assert.match(await api.page.locator('.shot-dock').textContent(), /401/);
  result.apiNoAuthRetry = true;
  assert.deepEqual(api.pageErrors, []);
  await api.page.screenshot({ path: 'shot-validation-api.png' });
  await api.context.close();

  const offline = await fixture();
  offline.setOffline(true);
  await openShot(offline);
  await generate(offline.page);
  await offline.page.getByRole('status').filter({ hasText: '503' }).waitFor({ timeout: 12000 });
  await waitChip(offline.page, '生成中');
  offline.setOffline(false);
  await waitChip(offline.page, '就绪');
  result.pollRecovery = true;
  assert.deepEqual(offline.pageErrors, []);
  await offline.context.close();
  console.log(JSON.stringify({ ok: true, ...result }, null, 2));
} finally {
  await browser.close();
}
