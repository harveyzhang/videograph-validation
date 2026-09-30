import { chromium } from 'playwright-core';

const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const errors = [];
page.on('pageerror', (err) => errors.push(err.message));
await page.goto('http://127.0.0.1:5188', { waitUntil: 'load', timeout: 30000 });
await page.waitForTimeout(2200);

const result = { default: {}, pipeline: {}, switchBack: {}, errors };

// 现在应用默认进创意工作区：显式切到 P(DOOM) 教学模式再断言。
await page.getByRole('button', { name: /P\(DOOM\) 教学/ }).click();
await page.waitForTimeout(700);
result.default = await page.evaluate(() => ({
  title: document.title,
  pdoomNodes: document.querySelectorAll('.pdoom-node').length,
  canvasText: document.querySelector('.canvas-title')?.textContent ?? '',
  blackboardPanel: document.querySelector('.blackboard-panel') !== null,
  libraryItems: document.querySelectorAll('.library-item').length,
}));

const run = page.getByRole('button', { name: /运行分析链/ });
if (await run.count()) await run.click();
await page.waitForTimeout(500);
result.pipeline = await page.evaluate(() => ({
  artifacts: document.querySelector('.blackboard-stats-row')?.textContent ?? '',
  events: document.querySelector('.blackboard-actions')?.textContent ?? '',
  artifactRows: document.querySelectorAll('.board-artifact').length,
  hitPolicy: document.querySelector('.cache-policy button.active')?.textContent ?? '',
  cacheLabels: [...document.querySelectorAll('.cache-chip')].slice(0, 8).map((el) => el.textContent),
}));

const toggle = page.getByRole('button', { name: /镜头 Demo/ });
if (await toggle.count()) await toggle.click();
await page.waitForTimeout(500);
result.switchBack = await page.evaluate(() => ({
  canvasText: document.querySelector('.canvas-title')?.textContent ?? '',
  pdoomNodes: document.querySelectorAll('.pdoom-node').length,
  legacyNodes: document.querySelectorAll('.studio-node').length,
}));

await page.screenshot({ path: 'pdoom-audit.png' });
await browser.close();
console.log(JSON.stringify(result, null, 2));
