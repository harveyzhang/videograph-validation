import assert from 'node:assert/strict';
import { chromium } from 'playwright-core';
import { fileURLToPath } from 'node:url';

const projectId = process.argv[2];
if (!projectId) throw new Error('usage: node scripts/project-view-audit.mjs <projectId>');
const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', args: ['--autoplay-policy=no-user-gesture-required', '--use-angle=d3d11'] });
try {
  const page = await browser.newPage({ viewport: { width: 1680, height: 1000 } });
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(`http://127.0.0.1:5188/?view=project&project=${encodeURIComponent(projectId)}`);
  await page.waitForSelector('.project-shot-node', { timeout: 30000 });
  assert.equal(await page.locator('.project-shot-node').count(), 22);
  await page.reload();
  await page.waitForSelector('.project-shot-node', { timeout: 30000 });
  assert.equal(await page.locator('.project-shot-node').count(), 22);
  await page.getByRole('button', { name: '查看 / 修改真实源码' }).click();
  const code = await page.locator('.project-source-modal textarea').inputValue();
  assert.ok(code.includes('export default class'));
  await page.getByRole('button', { name: '关闭源码', exact: true }).click();
  await page.getByRole('button', { name: '预览此镜头', exact: true }).click();
  const frame = page.frameLocator('iframe[title="真实镜头播放器"]');
  await frame.locator('#info').filter({ hasText: 'beat' }).waitFor({ timeout: 60000 });
  await frame.locator('#c').click({ position: { x: 200, y: 150 } });
  await page.waitForTimeout(1500);
  const player = await frame.locator('#info').textContent();
  assert.match(player, /beat/);
  assert.ok(parseFloat(player) > 0.5, 'audio-clock playback must advance');
  await page.screenshot({ path: fileURLToPath(new URL('../project-reproduction-ui.png', import.meta.url)) });
  await page.getByRole('button', { name: '关闭引擎预览', exact: true }).click();
  const shotButton = page.locator('.project-shot-list button').nth(3);
  const expectedTitle = await shotButton.locator('strong').textContent();
  await shotButton.click();
  // BUG-01 修复：断言目标取自工程真实数据，不再硬编码某个工程的镜头文案。
  await page.waitForFunction((t) => document.querySelector('.project-inspector .sidebar-title')?.textContent?.includes(t), expectedTitle);
  const completed = page.getByRole('link', { name: /打开成片/ }).first();
  await completed.waitFor({ timeout: 15000 });
  const url = await completed.getAttribute('href');
  const videoPage = await browser.newPage();
  await videoPage.goto(url, { waitUntil: 'domcontentloaded' });
  await videoPage.waitForSelector('video');
  const media = await videoPage.evaluate(async () => {
    const v = document.querySelector('video');
    if (v.readyState < 1) await new Promise((resolve, reject) => { v.onloadedmetadata = resolve; v.onerror = reject; });
    await v.play();
    await new Promise((resolve) => setTimeout(resolve, 1000));
    return { width: v.videoWidth, height: v.videoHeight, duration: v.duration, time: v.currentTime, error: v.error?.message ?? null };
  });
  assert.equal(media.width, 1920);
  assert.equal(media.height, 1080);
  assert.ok(media.duration > 156 && media.duration < 157);
  assert.ok(media.time > 0);
  assert.equal(media.error, null);
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({ ok: true, projectId, shots: 22, refreshed: true, sourceReadable: true, enginePlayback: player, media, errors }, null, 2));
} finally { await browser.close(); }
