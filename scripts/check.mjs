import { chromium } from 'playwright-core';

const browser = await chromium.launch({
  headless: true,
  executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
});
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const errors = [];
page.on('pageerror', (err) => errors.push(String(err.message).slice(0, 200)));

await page.goto('http://127.0.0.1:5188', { waitUntil: 'load', timeout: 30000 });
await page.waitForTimeout(2000);

const report = {};
report.base = await page.evaluate(() => ({
  nodes: document.querySelectorAll('.react-flow__node').length,
  libraryItems: document.querySelectorAll('.library-item').length,
  headerUserSelect: getComputedStyle(document.querySelector('.node-header')).userSelect,
}));

const readPreview = () => page.evaluate(() => {
  const label = [...document.querySelectorAll('.preview-label')].map((n) => n.textContent).join('|').slice(0, 90);
  const canvas = document.querySelector('.render-preview canvas');
  let lit = -1;
  if (canvas) {
    const ctx = canvas.getContext('2d');
    if (ctx) {
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      lit = 0;
      for (let i = 0; i < data.length; i += 40) {
        if (data[i] + data[i + 1] + data[i + 2] > 90) lit += 1;
      }
    }
  }
  return { label, litSamples: lit };
});

// A) Canvas 2D 全链路：切技术栈 → 生成 → 渲染 3 秒
await page.selectOption('.studio-node select', 'canvas-2d');
await page.getByRole('button', { name: /运行工作流/ }).click();
await page.waitForTimeout(1200);
await page.getByRole('button', { name: /渲染 3 秒预览/ }).click();
await page.waitForTimeout(4400);
report.canvas2d = await readPreview();

// B) 侧栏拖拽添加 + Delete 删除
await page.evaluate(() => {
  const dt = new DataTransfer();
  dt.setData('application/videograph-node', 'prompt');
  const item = document.querySelector('.library-item');
  item?.dispatchEvent(new DragEvent('dragstart', { dataTransfer: dt, bubbles: true, cancelable: true }));
  const zone = document.querySelector('.flow-canvas');
  const rect = zone?.getBoundingClientRect();
  if (!zone || !rect) return;
  const x = rect.x + 320;
  const y = rect.y + 240;
  zone.dispatchEvent(new DragEvent('dragover', { dataTransfer: dt, bubbles: true, cancelable: true, clientX: x, clientY: y }));
  zone.dispatchEvent(new DragEvent('drop', { dataTransfer: dt, bubbles: true, cancelable: true, clientX: x, clientY: y }));
});
await page.waitForTimeout(600);
const afterDrop = await page.evaluate(() => document.querySelectorAll('.react-flow__node').length);
await page.locator('.react-flow__node').last().locator('.node-header').click();
await page.keyboard.press('Delete');
await page.waitForTimeout(400);
const afterDelete = await page.evaluate(() => document.querySelectorAll('.react-flow__node').length);
report.dragDrop = { afterDrop, afterDelete };

// C) Three/WebGL 全链路（默认栈）：重置 → 生成 → 渲染
await page.getByRole('button', { name: /重置/ }).click();
await page.waitForTimeout(400);
await page.getByRole('button', { name: /运行工作流/ }).click();
await page.waitForTimeout(1200);
await page.getByRole('button', { name: /渲染 3 秒预览/ }).click();
await page.waitForTimeout(4400);
report.threeWebgl = await readPreview();

await page.screenshot({ path: 'check-screenshot.png' });
await browser.close();
console.log(JSON.stringify({ report, errors }, null, 2));
