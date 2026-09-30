import { chromium } from 'playwright-core';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

// MCP 队列闭环验收：前端入队 → (本脚本扮演 agent) 写 res 文件 → 前端轮询消费 → 卡片带落地。
const QUEUE = 'F:/aicg/video-graph-demo/.queue';
const base = 'http://127.0.0.1:5188';

const pendingRequests = () =>
  readdirSync(QUEUE).filter((n) => n.startsWith('req-') && n.endsWith('.json'))
    .map((n) => JSON.parse(readFileSync(join(QUEUE, n), 'utf8')));

const submit = (id, content, model = 'audit-agent') =>
  writeFileSync(join(QUEUE, `res-${id}.json`), JSON.stringify({ id, status: 'done', content, model, submittedAt: Date.now() }, null, 1));

const PLAN_JSON = JSON.stringify([
  { id: 'testloss', title: '测试 · 骤降', anchorLine: 'There was a sudden drop', endLine: 'ChatGPT, please', prompt: '对数 loss 曲线俯冲，火花画线，逐词卡拉OK。' },
  { id: 'testpre', title: '测试 · 恳求', anchorLine: "ChatGPT, please", endLine: "I'm upping", prompt: 'prompt 输入框逐 token 打出，下一词分布条，回车闪进。' },
  { id: 'testhook', title: '测试 · HOOK', anchorLine: "I'm upping", prompt: '一词一拍满屏大字，数字放大滚过。' },
]);

const sceneCode = (title) => '```ts\nexport function draw(ctx, f, api) {\n  const W = f.W, H = f.H, P = api.palette;\n  ctx.fillStyle = P.ink; ctx.fillRect(0, 0, W, H);\n  ctx.strokeStyle = P.signal; ctx.lineWidth = Math.max(2, H * 0.006);\n  ctx.beginPath();\n  ctx.arc(W / 2, H * 0.55, H * (0.2 + 0.12 * f.audio.rms + 0.08 * f.audio.downbeat), 0, Math.PI * 2 * f.p);\n  ctx.stroke();\n  const line = f.lyric.lines[0];\n  if (line) {\n    ctx.font = ' + "'600 ' + Math.round(H * 0.05) + 'px Arial, sans-serif'" + ';\n    ctx.textAlign = "center";\n    for (const w of line.words) {\n      const wp = api.wordProgress(w, f.t);\n      ctx.fillStyle = wp > 0 && wp < 1 ? P.signal : P.bone;\n      ctx.globalAlpha = wp === 0 ? 0.3 : 1;\n      ctx.fillText(w.w, W / 2, H * 0.2);\n    }\n    ctx.globalAlpha = 1;\n    ctx.textAlign = "left";\n  }\n}\n```\nSUMMARY: ' + title + ' 的 MCP agent 测试场景（圆弧进度 + 逐词卡拉OK）。';

const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const page = await browser.newPage({ viewport: { width: 1600, height: 950 } });
const errors = [];
page.on('pageerror', (err) => errors.push(err.message));
await page.goto(`${base}/?view=shot`, { waitUntil: 'load', timeout: 30000 });
await page.waitForTimeout(1800);

const result = { plan: {}, generate: {}, hotMerge: {}, errors };

// ① 规划请求入队 → agent 提交 → 前端铺卡片带
await page.getByRole('button', { name: /AI 规划全曲（MCP 队列）/ }).click();
await page.waitForFunction(() => fetch('/queue/list').then((r) => r.json()).then((d) => d.requests.some((q) => q.kind === 'plan')), null, { timeout: 8000 });
const planReq = pendingRequests().find((q) => q.kind === 'plan');
result.plan.requestQueued = { id: planReq.id, promptChars: planReq.prompt.system.length + planReq.prompt.user.length, hasSchema: planReq.prompt.system.includes('anchorLine') };
submit(planReq.id, PLAN_JSON);
await page.waitForFunction(() => document.querySelectorAll('.plan-card').length >= 3, null, { timeout: 15000 });
await page.waitForTimeout(400);
result.plan.consumed = await page.evaluate(() => ({
  cards: document.querySelectorAll('.plan-card').length,
  chip: document.querySelector('.plan-director .cache-chip')?.textContent?.trim(),
  titles: [...document.querySelectorAll('.plan-card .node-heading strong')].map((el) => el.textContent),
}));

// ② 批量生成（MCP）→ 3 个 codegen 请求 → agent 逐个提交 → 卡片就绪
await page.getByRole('button', { name: /批量生成（MCP 队列）/ }).click();
await page.waitForFunction(() => fetch('/queue/list').then((r) => r.json()).then((d) => d.requests.filter((q) => q.kind === 'codegen').length >= 3), null, { timeout: 8000 });
const codegenReqs = pendingRequests().filter((q) => q.kind === 'codegen');
result.generate.queued = codegenReqs.map((q) => ({ id: q.id, cardId: q.cardId, promptHasContract: q.prompt.system.includes('引擎契约') }));
for (const req of codegenReqs) submit(req.id, sceneCode(req.cardTitle ?? req.cardId));
await page.waitForFunction(() => {
  const chips = [...document.querySelectorAll('.plan-card .cache-chip')].map((c) => c.textContent ?? '');
  return chips.length >= 3 && chips.every((t) => /就绪|出错/.test(t));
}, null, { timeout: 20000 });
result.generate.consumed = await page.evaluate(() => {
  const cards = [...document.querySelectorAll('.plan-card')];
  return {
    ready: cards.filter((c) => (c.querySelector('.cache-chip')?.textContent ?? '').includes('就绪')).length,
    mcpFooter: cards[0]?.querySelector('.node-footer span')?.textContent,
    thumbs: cards.filter((c) => c.querySelector('.plan-card-thumb')?.tagName === 'IMG').length,
  };
});

// ③ 卡片快照热合并：agent（MCP shot_cards_update_prompt）改第一张卡提示词
// 注意：必须等"生成完成后的最终快照"（rev>=1）落盘再注入，否则会被 debounce 保存覆盖（竞态）
await page.waitForFunction(() => fetch('/queue/state').then((r) => r.json()).then((d) => d.cards?.length >= 3 && d.cards.every((c) => c.rev >= 1)), null, { timeout: 12000 });
await page.waitForTimeout(1200); // debounce 保存彻底结束
const before = await page.evaluate(() => document.querySelectorAll('.plan-card')[0]?.querySelector('.plan-card-prompt')?.textContent ?? '');
const snap = JSON.parse(await page.evaluate(() => fetch('/queue/state').then((r) => r.text())));
snap.cards[0].prompt = '【MCP 改写】极简版：中央一条水平线随节拍上下跳动，其他全黑，只有逐词卡拉OK。';
snap.savedAt = Date.now() + 9000; // 保证被前端判定为外部修改
writeFileSync(join(QUEUE, 'cards.json'), JSON.stringify(snap, null, 1));
await page.waitForFunction(() => {
  const p = document.querySelectorAll('.plan-card')[0]?.querySelector('.plan-card-prompt')?.textContent ?? '';
  return p.includes('MCP 改写');
}, null, { timeout: 25000 });
const after = await page.evaluate(() => document.querySelectorAll('.plan-card')[0]?.querySelector('.plan-card-prompt')?.textContent ?? '');
result.hotMerge = { before: before.slice(0, 24), after: after.slice(0, 40), ok: after.includes('MCP 改写') };

// ④ 队列应已被前端 ack 清理
await page.waitForTimeout(1000);
result.queueClean = readdirSync(QUEUE).filter((n) => n.startsWith('req-')).length === 0;
result.queueFiles = readdirSync(QUEUE).filter((n) => n !== 'cards.json');

await page.screenshot({ path: 'shot-mcp-audit.png' });
await browser.close();
console.log(JSON.stringify(result, null, 2));
assert.equal(result.plan.requestQueued.hasSchema, true);
assert.equal(result.plan.consumed.cards, 3);
assert.equal(result.generate.queued.length, 3);
assert.equal(result.generate.consumed.ready, 3);
assert.equal(result.generate.consumed.thumbs, 3);
assert.equal(result.hotMerge.ok, true);
assert.equal(result.queueClean, true);
assert.deepEqual(errors, []);
