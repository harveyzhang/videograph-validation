// check-box.mjs — 特效箱质量闸门：每个 effects/box/*.glsl 必须通过 结构校验 → 着色器编译 → 渲染合理性 → 闪烁上限。
// 用法：node scripts/fx/check-box.mjs [--only id1,id2] [--include-gl] [--json out.json]
// 批量由其他 AI 编写的动效，合并前必须跑这个脚本并全部通过；失败项给出原因，可直接退回给作者修改。
import { writeFileSync } from 'node:fs';
import { loadBoxEffects, loadGlTransitions } from '../../src/server/fx/effects.mjs';
import { withFxBrowser, checkEffect } from '../../src/server/fx/preview-worker.mjs';

const args = process.argv.slice(2);
const only = args.includes('--only') ? new Set(args[args.indexOf('--only') + 1].split(',')) : null;
const jsonOut = args.includes('--json') ? args[args.indexOf('--json') + 1] : null;
const box = loadBoxEffects();
let effects = box.effects;
if (args.includes('--include-gl')) effects = effects.concat((await loadGlTransitions()).effects.filter((effect) => !effect.unsupported));
if (only) effects = effects.filter((effect) => only.has(effect.id));

const results = await withFxBrowser(async (page) => {
  const out = [];
  for (const effect of effects) {
    const result = await checkEffect(page, effect);
    out.push(result);
    process.stdout.write(`${result.ok ? '✓' : '✕'} ${effect.id.padEnd(30)} ${result.ok ? '' : result.problems.join('；')}\n`);
  }
  return out;
});
const fileProblems = box.problems.map((entry) => ({ id: entry.file, ok: false, problems: entry.problems }));
for (const entry of fileProblems) process.stdout.write(`✕ ${entry.id.padEnd(30)} ${entry.problems.join('；')}\n`);
const failed = [...results, ...fileProblems].filter((result) => !result.ok);
console.log(`\n特效箱检查：${results.length + fileProblems.length} 个，通过 ${results.length - results.filter((r) => !r.ok).length}，失败 ${failed.length}`);
if (jsonOut) writeFileSync(jsonOut, JSON.stringify({ results, fileProblems }, null, 2));
process.exitCode = failed.length ? 1 : 0;
