import { chromium } from 'playwright-core';
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const errors = [];
page.on('pageerror', (err) => errors.push(err.message));
await page.goto('http://127.0.0.1:5188', { waitUntil: 'load', timeout: 30000 });
await page.waitForTimeout(1800);
const result = { creative: {}, pdoom: {}, legacy: {}, errors };
result.creative = await page.evaluate(() => ({
  title: document.querySelector('.canvas-title')?.textContent ?? '',
  nodes: document.querySelectorAll('.creative-node').length,
  assetBrief: document.querySelector('.creative-asset-brief')?.textContent?.slice(0, 120) ?? '',
  missingBadge: document.querySelector('.source-missing') !== null,
  library: document.querySelectorAll('.library-item').length,
}));
await page.getByRole('button', { name: /P\(DOOM\) 教学/ }).click();
await page.waitForTimeout(500);
result.pdoom = await page.evaluate(() => ({ title: document.querySelector('.canvas-title')?.textContent ?? '', nodes: document.querySelectorAll('.pdoom-node').length, blackboard: document.querySelector('.blackboard-panel') !== null }));
await page.getByRole('button', { name: /镜头 Demo/ }).click();
await page.waitForTimeout(500);
result.legacy = await page.evaluate(() => ({ title: document.querySelector('.canvas-title')?.textContent ?? '', nodes: document.querySelectorAll('.studio-node').length }));
await page.screenshot({ path: 'creative-audit.png' });
await browser.close();
console.log(JSON.stringify(result, null, 2));
