import { chromium } from 'playwright-core';
import assert from 'node:assert/strict';

// 多卡工坊验收：内置规划 → 22 卡 → 批量生成（模板）→ dock 预览/播放 → 改提示词 → 待重算。
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const page = await browser.newPage({ viewport: { width: 1600, height: 950 } });
const errors = [];
page.on('pageerror', (err) => errors.push(err.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push(`${m.text()} ${m.location().url ?? ''}`.trim()); });
page.on('response', (response) => { if (response.status() >= 400) errors.push(`HTTP ${response.status()} ${response.url()}`); });
await page.goto('http://127.0.0.1:5188/?view=shot', { waitUntil: 'load', timeout: 30000 });
await page.waitForTimeout(2000);

const result = { boot: {}, plan: {}, generate: {}, dock: {}, edit: {}, errors };

result.boot = await page.evaluate(() => ({
  director: document.querySelectorAll('.plan-director').length,
  contexts: document.querySelectorAll('.shot-context').length,
  cards: document.querySelectorAll('.plan-card').length,
  noLlmHint: document.querySelector('.plan-director .shot-lint')?.textContent?.slice(0, 30) ?? '',
}));

await page.getByRole('button', { name: /内置参考规划/ }).click();
await page.waitForFunction(() => document.querySelectorAll('.plan-card').length >= 20, null, { timeout: 10000 });
await page.waitForTimeout(600);
result.plan = await page.evaluate(() => {
  const cards = [...document.querySelectorAll('.plan-card')];
  const chips = cards.map((c) => c.querySelector('.cache-chip')?.textContent?.trim());
  const titles = cards.slice(0, 4).map((c) => c.querySelector('.node-heading strong')?.textContent);
  const last = cards[cards.length - 1]?.querySelector('.node-heading strong')?.textContent;
  return {
    cardCount: cards.length,
    allPlanned: chips.every((t) => /规划/.test(t ?? '')),
    firstTitles: titles,
    lastTitle: last,
    progress: document.querySelector('.plan-progress span')?.textContent ?? '',
  };
});

await page.getByRole('button', { name: /本地模板生成（不等待）/ }).click();
await page.waitForFunction(() => {
  const chips = [...document.querySelectorAll('.plan-card .cache-chip')].map((c) => c.textContent ?? '');
  return chips.length > 0 && chips.every((t) => /就绪|出错/.test(t));
}, null, { timeout: 120000 });
result.generate = await page.evaluate(() => {
  const cards = [...document.querySelectorAll('.plan-card')];
  const ready = cards.filter((c) => (c.querySelector('.cache-chip')?.textContent ?? '').includes('就绪')).length;
  const thumbs = cards.filter((c) => c.querySelector('.plan-card-thumb')?.tagName === 'IMG').length;
  const motifs = new Set(cards.map((c) => c.querySelector('.node-footer span')?.textContent?.split('·')[1]?.trim()).filter(Boolean));
  return { ready, thumbs, distinctMotifs: motifs.size, footerSample: cards[2]?.querySelector('.node-footer span')?.textContent };
});

await page.locator('.plan-card').nth(1).click();
await page.waitForSelector('.shot-dock', { timeout: 5000 });
await page.waitForTimeout(800);
result.dock = await page.evaluate(() => {
  const canvas = document.querySelector('.shot-dock-canvas');
  const ctx = canvas.getContext('2d');
  const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
  let lit = 0;
  for (let i = 0; i < data.length; i += 160) { if (data[i] + data[i + 1] + data[i + 2] > 90) lit++; }
  return {
    title: document.querySelector('.shot-dock-head strong')?.textContent ?? '',
    meta: document.querySelector('.shot-dock-meta')?.textContent ?? '',
    canvasLit: lit,
    promptLen: document.querySelector('.shot-dock .shot-prompt')?.value.length ?? 0,
  };
});

await page.locator('.shot-dock .mini-button', { hasText: '播放这一段' }).click();
await page.waitForTimeout(2500);
const playState = await page.evaluate(() => ({
  btn: [...document.querySelectorAll('.shot-dock .mini-button')].map((b) => b.textContent).find((t) => /暂停|播放这一段/.test(t)) ?? '',
}));
await page.locator('.shot-dock .mini-button', { hasText: '暂停' }).click().catch(() => {});
result.dock.playButton = playState.btn;

await page.locator('.shot-dock .shot-prompt').fill('改成一个极简版本：只留中央一根垂直线随节拍伸缩，其余全黑。');
await page.waitForTimeout(600);
result.edit = await page.evaluate(() => {
  const sel = document.querySelector('.plan-card.is-selected .cache-chip')?.textContent?.trim();
  return { selectedChip: sel };
});

const bb = await page.evaluate(() => ({
  artifacts: document.querySelectorAll('.board-artifact').length,
  stats: document.querySelector('.blackboard-stats-row')?.textContent ?? '',
}));
result.blackboard = bb;

await page.screenshot({ path: 'shot-demo-audit.png' });
await browser.close();
console.log(JSON.stringify(result, null, 2));
assert.equal(result.plan.cardCount, 22);
assert.equal(result.plan.allPlanned, true);
assert.equal(result.generate.ready, 22);
assert.equal(result.generate.thumbs, 22);
assert.ok(result.generate.distinctMotifs >= 4);
assert.ok(result.dock.canvasLit > 0);
assert.match(result.dock.playButton, /暂停/);
assert.equal(result.edit.selectedChip, '待重算');
assert.deepEqual(errors, [], 'browser errors must fail the audit');
