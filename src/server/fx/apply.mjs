// apply.mjs — 把特效箱里的动效“冻结”进工程：镜头后期栈（shot.effects）与转场动效（transition.effect）。
// 冻结 = 复制当时的着色器源码、参数规格与取值；之后特效箱更新不会悄悄改变已渲染/已导出的镜头，升级需要重新套用。
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ProjectError } from '../errors.mjs';
import { loadBoxEffects, glTransitionToEffect } from './effects.mjs';
import { loadRegistry, getSource, selectFiles, readCached, fxCacheRoot } from './fetcher.mjs';
import { BINDING_SOURCES } from '../../fx/box/index.mjs';

const sha256 = (value) => createHash('sha256').update(value).digest('hex');
export const MAX_SHOT_EFFECTS = 4;

/** 同步查找（服务的写路径是同步事务）：特效箱文件 + 本机已缓存的 gl-transitions。 */
export function findEffectSync(id) {
  const fromBox = loadBoxEffects().effects.find((effect) => effect.id === id);
  if (fromBox) return fromBox;
  if (String(id).startsWith('gl-')) {
    try {
      const source = getSource(loadRegistry(), 'gl-transitions');
      const treeFile = join(fxCacheRoot(), source.id, source.commit, 'tree.json');
      if (existsSync(treeFile)) {
        for (const entry of selectFiles(source, JSON.parse(readFileSync(treeFile, 'utf8')), 'transitions/')) {
          let code; try { code = readCached(source, entry.path).content.toString('utf8'); } catch { continue; }
          const effect = glTransitionToEffect(entry.path, code);
          if (effect.id === id) return effect;
        }
      }
    } catch { /* 未登记或未下载 */ }
    throw new ProjectError(`本机还没有下载 ${id}：先用 effect_search 查找（会按需下载 gl-transitions）`, 409);
  }
  throw new ProjectError(`特效箱里没有 ${id}；用 effect_search 查找`, 404);
}

function checkValue(name, spec, value) {
  const type = spec.type ?? 'float';
  if (type === 'float' || type === 'int') {
    if (typeof value !== 'number' || !Number.isFinite(value) || (type === 'int' && !Number.isInteger(value))) throw new ProjectError(`参数 ${name} 必须是${type === 'int' ? '整数' : '数字'}`);
    if ((spec.min !== undefined && value < spec.min) || (spec.max !== undefined && value > spec.max)) throw new ProjectError(`参数 ${name} 超出范围 ${spec.min ?? '-∞'}..${spec.max ?? '∞'}`);
  } else if (type === 'bool') { if (typeof value !== 'boolean') throw new ProjectError(`参数 ${name} 必须是 true/false`); }
  else if (type === 'color') { if (!/^#[0-9a-f]{6}$/i.test(String(value))) throw new ProjectError(`参数 ${name} 必须是 #RRGGBB`); }
  else {
    const size = Number(type.slice(-1));
    if (!Array.isArray(value) || value.length !== size || !value.every((v) => Number.isFinite(v))) throw new ProjectError(`参数 ${name} 必须是 ${size} 个数字`);
  }
}
function freezeValues(effect, values = {}) {
  if (!values || typeof values !== 'object' || Array.isArray(values)) throw new ProjectError('params 必须是对象');
  for (const name of Object.keys(values)) if (!effect.params?.[name]) throw new ProjectError(`${effect.id} 没有参数 ${name}`);
  const out = {};
  for (const [name, spec] of Object.entries(effect.params ?? {})) {
    const value = values[name] ?? spec.default;
    checkValue(name, spec, value);
    out[name] = value;
  }
  return out;
}
function freezeBindings(effect, bindings) {
  const merged = { ...(effect.bindings ?? {}), ...(bindings ?? {}) };
  for (const [name, binding] of Object.entries(merged)) {
    if (binding === null) { delete merged[name]; continue; }
    if (!effect.params?.[name] || (effect.params[name].type ?? 'float') !== 'float') throw new ProjectError(`绑定 ${name} 必须指向 float 参数`);
    if (!BINDING_SOURCES.includes(binding.to) || !Number.isFinite(binding.amount)) throw new ProjectError(`绑定 ${name} 需要 to（${BINDING_SOURCES.join('/')}）与数字 amount`);
  }
  return merged;
}
function frozen(effect, values, bindings) {
  return { id: effect.id, name: effect.name, kind: effect.kind, version: effect.version ?? 1, origin: effect.origin, license: effect.license,
    params: freezeValues(effect, values), bindings: freezeBindings(effect, bindings),
    specs: Object.fromEntries(Object.entries(effect.params ?? {}).map(([name, spec]) => [name, { type: spec.type ?? 'float', min: spec.min, max: spec.max }])),
    declaresUniforms: Boolean(effect.declaresUniforms), glsl: effect.glsl, codeHash: sha256(effect.glsl) };
}

/** 镜头后期栈：[{ id, params?, bindings? }]，按顺序叠加，最多 4 层；只接受 kind=post。空数组 = 清除。 */
export function prepareShotEffects(list) {
  if (!Array.isArray(list) || list.length > MAX_SHOT_EFFECTS) throw new ProjectError(`effects 必须是数组，最多 ${MAX_SHOT_EFFECTS} 层`);
  return list.map((entry) => {
    if (!entry || typeof entry.id !== 'string') throw new ProjectError('每层需要 id');
    const effect = findEffectSync(entry.id);
    if (effect.kind !== 'post') throw new ProjectError(`${entry.id} 是转场，不能放进镜头后期栈（用 project_transition_configure mode=effect）`);
    if (effect.unsupported) throw new ProjectError(`${entry.id} 暂不支持：${effect.unsupported}`);
    return frozen(effect, entry.params, entry.bindings);
  });
}
/** 转场动效：mode=effect 时的 effectId + params。 */
export function prepareTransitionEffect(effectId, params) {
  const effect = findEffectSync(effectId);
  if (effect.kind !== 'transition') throw new ProjectError(`${effectId} 不是转场动效`);
  if (effect.unsupported) throw new ProjectError(`${effectId} 暂不支持：${effect.unsupported}`);
  return frozen(effect, params, {});
}
