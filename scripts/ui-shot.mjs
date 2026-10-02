// ui-shot.mjs — 给工作台截图（审阅前端美化用）：node scripts/ui-shot.mjs <out.png> [projectName] [width] [height]
import { chromium } from 'playwright-core';

const [out = '.cache/ui.png', projectName = 'THE LAST AUDIT', width = '1680', height = '1000'] = process.argv.slice(2);
const browser = await chromium.launch({ headless: true, executablePath: process.env.EDGE_PATH ?? 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', args: ['--use-angle=d3d11'] });
const page = await browser.newPage({ viewport: { width: Number(width), height: Number(height) } });
const errors = [];
page.on('pageerror', (error) => errors.push(error.message));
page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
await page.goto('http://127.0.0.1:5188/?view=project', { waitUntil: 'networkidle' });
await page.waitForTimeout(1500);
const picker = page.getByLabel('切换工程');
const value = await picker.evaluate((select, name) => [...select.options].find((option) => option.text.includes(name))?.value ?? '', projectName);
if (value) { await picker.selectOption(value); await page.waitForTimeout(3500); }
const shot = process.env.UI_SHOT_SELECT;
if (shot) { await page.locator('.project-shot-list button', { hasText: shot }).first().click(); await page.waitForTimeout(1500); }
const tab = process.env.UI_SHOT_TAB;
if (tab) { await page.getByRole('button', { name: tab, exact: true }).click(); await page.waitForTimeout(4000); }
const card = process.env.UI_SHOT_CARD;
if (card) { await page.getByRole('button', { name: '预览 ' + card }).click(); await page.waitForTimeout(2500); }
await page.screenshot({ path: out });
console.log(JSON.stringify({ out, errors }));
await browser.close();
