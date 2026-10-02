// render-examples.mjs — 给特效箱的动效渲染示例：每个动效一张帧序列图 + 一张总览图。
// 用法：node scripts/fx/render-examples.mjs [--only id1,id2] [--include-gl] [--out .cache/fx-examples] [--source type|scene|shapes|portrait]
// 输出：<out>/<id>.png（8 帧，标注时间/拍相位或转场进度）、<out>/_overview.png（每个动效 1 帧）。
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { loadBoxEffects, loadGlTransitions } from '../../src/server/fx/effects.mjs';
import { withFxBrowser, renderFilmstrip } from '../../src/server/fx/preview-worker.mjs';

const args = process.argv.slice(2);
const opt = (name, fallback) => (args.includes(name) ? args[args.indexOf(name) + 1] : fallback);
const only = args.includes('--only') ? new Set(opt('--only').split(',')) : null;
const out = opt('--out', '.cache/fx-examples');
const forcedSource = opt('--source', null);
mkdirSync(out, { recursive: true });
let effects = loadBoxEffects().effects;
if (args.includes('--include-gl')) effects = effects.concat((await loadGlTransitions()).effects.filter((effect) => !effect.unsupported));
if (only) effects = effects.filter((effect) => only.has(effect.id));
// 每类动效用最能看出效果的演示素材
const sourceFor = (effect) => forcedSource ?? ({ '手绘与绘画': 'scene', '印刷与版画': 'portrait', '胶片与调色': 'scene', '复古与数字': 'shapes', '运动与节拍': 'type' }[effect.category] ?? 'type');

await withFxBrowser(async (page) => {
  for (const effect of effects) {
    const png = await renderFilmstrip(page, effect, { source: sourceFor(effect), toSource: 'shapes', frames: 8, duration: effect.kind === 'transition' ? 1 : 1.75, width: 320, columns: 4 });
    writeFileSync(join(out, `${effect.id}.png`), Buffer.from(png, 'base64'));
    process.stdout.write(`${effect.id} `);
  }
  // 总览：每个动效 1 帧（转场取 50%），6 列
  const overview = await page.evaluate(async ({ effects, sources }) => {
    const fx = window.__fx;
    const w = 240, h = 135, cols = 6, label = 20, gap = 6;
    const canvas = document.createElement('canvas'); canvas.width = w; canvas.height = h;
    const previewer = new fx.EffectPreviewer(canvas);
    const rows = Math.ceil(effects.length / cols);
    const sheet = document.createElement('canvas'); sheet.width = cols * (w + gap) + gap; sheet.height = rows * (h + label + gap) + gap;
    const ctx = sheet.getContext('2d'); ctx.fillStyle = '#111317'; ctx.fillRect(0, 0, sheet.width, sheet.height);
    effects.forEach((effect, i) => {
      previewer.render(effect, { t: 1.0, source: sources[i], toSource: 'shapes', progress: effect.kind === 'transition' ? .5 : undefined });
      const x = gap + (i % cols) * (w + gap), y = gap + Math.floor(i / cols) * (h + label + gap);
      ctx.drawImage(canvas, x, y);
      ctx.fillStyle = '#d6d9df'; ctx.font = '12px "Microsoft YaHei", sans-serif'; ctx.textBaseline = 'top'; ctx.fillText(effect.name.slice(0, 20), x + 2, y + h + 3);
    });
    return sheet.toDataURL('image/png').split(',')[1];
  }, { effects, sources: effects.map(sourceFor) });
  writeFileSync(join(out, '_overview.png'), Buffer.from(overview, 'base64'));
});
console.log(`\n已渲染 ${effects.length} 个动效示例到 ${out}`);
