// 特效箱：格式解析、校验、gl-transitions 适配（参数解析、全局初始化改写）、冻结进工程与转场配置（不启浏览器）。
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const tmp = mkdtempSync(join(tmpdir(), 'vg-fxbox-'));
mkdirSync(join(tmp, 'box'));
process.env.VIDEOGRAPH_FX_BOX = join(tmp, 'box');
const { parseEffectFile, validateEffect, searchEffects } = await import('../../../src/fx/box/index.mjs');
const { loadBoxEffects, glTransitionToEffect, hoistGlobalInitializers } = await import('../../../src/server/fx/effects.mjs');
const { prepareShotEffects } = await import('../../../src/server/fx/apply.mjs');
test.after(() => rmSync(tmp, { recursive: true, force: true }));

const manifest = { id: 'tint-test', name: '测试染色', kind: 'post', category: '胶片与调色', tags: ['tint'], summary: '染色', when: '测试', avoid: '无',
  params: { amount: { type: 'float', default: 0.5, min: 0, max: 1 }, color: { type: 'color', default: '#ff0000' } }, bindings: { amount: { to: 'kick', amount: 0.3 } } };
const file = (m, body = 'vec4 effect(vec2 uv) { return vec4(mix(srcTex(uv).rgb, color, amount), 1.); }') => `/*@effect\n${JSON.stringify(m)}\n@effect*/\n${body}\n`;

test('解析：头部 JSON + 正文；id 必须等于文件名', () => {
  const effect = parseEffectFile(file(manifest), 'tint-test.glsl');
  assert.equal(effect.id, 'tint-test');
  assert.match(effect.glsl, /vec4 effect/);
  assert.throws(() => parseEffectFile(file(manifest), 'other.glsl'), /必须与文件名一致/);
  assert.throws(() => parseEffectFile('vec4 effect(vec2 uv){}', 'x.glsl'), /缺少/);
});

test('校验：参数越界、保留名、绑定到非 float、缺 effect()', () => {
  assert.deepEqual(validateEffect(parseEffectFile(file(manifest), 'tint-test.glsl')), []);
  const bad = { ...manifest, params: { uTime: { type: 'float', default: 2, min: 0, max: 1 } }, bindings: { missing: { to: 'kick', amount: 1 } } };
  const problems = validateEffect({ ...bad, glsl: 'void main(){}' });
  assert.ok(problems.some((p) => /保留名/.test(p)));
  assert.ok(problems.some((p) => /越界/.test(p)));
  assert.ok(problems.some((p) => /float 参数/.test(p)));
  assert.ok(problems.some((p) => /effect\(vec2 uv\)/.test(p)));
});

test('加载目录：有效文件进箱，无效文件进 problems 而不是让整个箱子失败', () => {
  writeFileSync(join(tmp, 'box', 'tint-test.glsl'), file(manifest));
  writeFileSync(join(tmp, 'box', 'broken.glsl'), '/*@effect {not json} @effect*/');
  const box = loadBoxEffects();
  assert.deepEqual(box.effects.map((e) => e.id), ['tint-test']);
  assert.equal(box.problems[0].file, 'broken.glsl');
  assert.equal(searchEffects(box.effects, { query: 'tint' })[0].id, 'tint-test');
});

test('gl-transitions 适配：参数从 uniform 注释解析；全局非常量初始化改写为 #define', () => {
  const code = '// Author: someone\n// License: MIT\nuniform float smoothness; // = 0.3\nuniform vec2 direction; // = vec2(1.0, -1.0)\nuniform ivec2 size; // = ivec2(10, 10)\nfloat scale = 1.0 + smoothness;\nconst float k = 2.0;\nvec4 transition(vec2 uv) { float inner = 1.0; return mix(getFromColor(uv), getToColor(uv), progress * scale); }';
  const effect = glTransitionToEffect('transitions/MyWipe.glsl', code);
  assert.equal(effect.id, 'gl-my-wipe');
  assert.deepEqual(effect.params.direction.default, [1, -1]);
  assert.deepEqual(effect.params.size.default, [10, 10]);
  assert.equal(effect.params.smoothness.default, 0.3);
  assert.match(effect.glsl, /#define scale \(1\.0 \+ smoothness\)/);
  assert.match(effect.glsl, /const float k = 2\.0;/, 'const 保持不变');
  assert.match(effect.glsl, /float inner = 1\.0;/, '函数内的变量不改写');
  assert.equal(hoistGlobalInitializers('vec4 f() { float a = b; return vec4(a); }'), 'vec4 f() { float a = b; return vec4(a); }');
});

test('冻结进工程：默认值补齐、越界拒绝、未知参数拒绝、层数上限、转场不能进后期栈', () => {
  const [frozen] = prepareShotEffects([{ id: 'tint-test', params: { amount: 0.8 } }]);
  assert.equal(frozen.params.amount, 0.8);
  assert.equal(frozen.params.color, '#ff0000');
  assert.match(frozen.glsl, /vec4 effect/);
  assert.equal(frozen.bindings.amount.to, 'kick');
  assert.ok(frozen.codeHash.length === 64);
  assert.throws(() => prepareShotEffects([{ id: 'tint-test', params: { amount: 3 } }]), /超出范围/);
  assert.throws(() => prepareShotEffects([{ id: 'tint-test', params: { nope: 1 } }]), /没有参数/);
  assert.throws(() => prepareShotEffects([{ id: 'tint-test', params: { color: 'red' } }]), /#RRGGBB/);
  assert.throws(() => prepareShotEffects(Array(5).fill({ id: 'tint-test' })), /最多 4 层/);
  assert.throws(() => prepareShotEffects([{ id: 'does-not-exist' }]), /没有 does-not-exist/);
  const unbound = prepareShotEffects([{ id: 'tint-test', bindings: { amount: null } }])[0];
  assert.deepEqual(unbound.bindings, {});
});
