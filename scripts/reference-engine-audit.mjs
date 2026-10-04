import assert from 'node:assert/strict';
import { chromium } from 'playwright-core';
import { startReferenceServer } from '../src/server/reference-server.mjs';
import { browserPath, angleArgs } from '../src/server/browser.mjs';

const server = await startReferenceServer();
const browser = await chromium.launch({ headless: true, executablePath: browserPath(), args: [...angleArgs(), '--ignore-gpu-blocklist', '--enable-gpu-rasterization'] });
try {
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto(`${server.url}/?export=1&only=open`);
  await page.waitForFunction(() => window.__pdoom?.ready || window.__pdoom?.error, null, { timeout: 120000 });
  const status = await page.evaluate(async () => {
    const p = window.__pdoom;
    if (p.error) return { error: p.error };
    p.still(4, 1, 0.2);
    const pixels = await p.engine.readPixelsAsync();
    let light = 0;
    for (let i = 0; i < pixels.length; i += 400) if (pixels[i] + pixels[i + 1] + pixels[i + 2] > 160) light++;
    const gl = p.engine.renderer.getContext();
    const debug = gl.getExtension('WEBGL_debug_renderer_info');
    return { width: p.width, height: p.height, shots: p.timeline.length, errors: p.errors, light,
      renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER) };
  });
  await page.screenshot({ path: 'reference-engine-audit.png' });
  console.log(JSON.stringify({ status, errors }, null, 2));
  assert.equal(status.error, undefined);
  assert.equal(status.shots, 22);
  assert.ok(status.light > 0);
  assert.deepEqual(status.errors, []);
  assert.deepEqual(errors, []);
} finally {
  await browser.close();
  await server.close();
}
