// effects.mjs — 特效箱的服务端加载：本仓库 effects/box/*.glsl（自写/批量编写的动效）+ 上游 gl-transitions（按需下载、不分发）。
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseEffectFile, validateEffect, searchEffects, effectCard } from '../../fx/box/index.mjs';
import { loadRegistry, getSource, sourceTree, selectFiles, ensureFiles, readCached, cacheStatus } from './fetcher.mjs';

const productRoot = fileURLToPath(new URL('../../..', import.meta.url));
export const boxDir = () => process.env.VIDEOGRAPH_FX_BOX ?? join(productRoot, 'effects/box');

let boxCache = { key: '', effects: [], problems: [] };
/** 读取并校验 effects/box；按文件 mtime 缓存。无效文件不进箱，问题单独返回（供 check 脚本与 fx_box_problems）。 */
export function loadBoxEffects() {
  const dir = boxDir();
  const files = existsSync(dir) ? readdirSync(dir).filter((name) => name.endsWith('.glsl')).sort() : [];
  const key = files.map((name) => `${name}:${statSync(join(dir, name)).mtimeMs}`).join('|');
  if (key === boxCache.key) return boxCache;
  const effects = [], problems = [];
  for (const name of files) {
    try {
      const effect = parseEffectFile(readFileSync(join(dir, name), 'utf8'), name);
      const issues = validateEffect(effect);
      if (issues.length) problems.push({ file: name, problems: issues }); else effects.push(effect);
    } catch (error) { problems.push({ file: name, problems: [String(error.message ?? error)] }); }
  }
  boxCache = { key, effects, problems };
  return boxCache;
}

// ------------------------------------------------------------------ gl-transitions 适配
const glType = { float: 'float', int: 'int', bool: 'bool', vec2: 'vec2', vec3: 'vec3', vec4: 'vec4', ivec2: 'ivec2' };
function parseDefault(type, raw) {
  const text = String(raw ?? '').trim().replace(/;$/, '');
  if (type === 'bool') return text === 'true';
  if (type === 'float' || type === 'int') { const n = Number(text.replace(/[^\d.eE+-]/g, '')); return Number.isFinite(n) ? n : 0; }
  const size = Number(type.slice(-1));
  const args = (/\((.*)\)/.exec(text)?.[1] ?? '').split(',').map((part) => Number(part.trim())).filter(Number.isFinite);
  return Array.from({ length: size }, (_, i) => args.length === 1 ? args[0] : args[i] ?? 0);
}
/**
 * GLSL ES 3.00 不允许全局变量用非常量表达式初始化（gl-transitions 部分文件依赖 GLSL 1.0 驱动的宽容）。
 * 把全局作用域的 `type name = expr;`（非 const、引用了 uniform/函数）改写为 `#define name (expr)`，语义等价。
 */
export function hoistGlobalInitializers(code) {
  let depth = 0;
  return code.split('\n').map((line) => {
    const atGlobal = depth === 0;
    for (const ch of line.replace(/\/\/.*$/, '')) { if (ch === '{') depth++; else if (ch === '}') depth = Math.max(0, depth - 1); }
    if (!atGlobal) return line;
    const match = /^\s*(?:float|int|bool|vec[234]|ivec[234])\s+(\w+)\s*=\s*(.+?);\s*(\/\/.*)?$/.exec(line);
    if (!match || /^\s*const/.test(line)) return line;
    return `#define ${match[1]} (${match[2]})${match[3] ? ' ' + match[3] : ''}`;
  }).join('\n');
}

/** 把一个 gl-transitions 文件转成特效箱的转场定义（参数来自 `uniform T name; // = default` 注释）。 */
export function glTransitionToEffect(path, rawCode) {
  const code = hoistGlobalInitializers(rawCode);
  const file = path.split('/').pop().replace(/\.glsl$/, '');
  const id = `gl-${file.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/_/g, '-').toLowerCase()}`;
  const params = {}, unsupported = [];
  for (const match of code.matchAll(/^\s*uniform\s+(\w+)\s+(\w+)\s*;\s*(?:\/\/\s*=\s*(.+))?$/gm)) {
    const [, type, name, def] = match;
    if (!glType[type]) { unsupported.push(`${type} ${name}`); continue; }
    params[name] = { type, default: parseDefault(type, def), label: name };
  }
  const author = /^\/\/\s*Author:\s*(.+?)\s*$/m.exec(code)?.[1] ?? 'unknown';
  const license = /^\/\/\s*License:\s*(.+?)\s*$/m.exec(code)?.[1] ?? 'unknown';
  return { id, name: file, kind: 'transition', category: '转场', tags: ['gl-transitions', 'transition'], version: 1,
    summary: `gl-transitions 转场 “${file}”（作者 ${author}）。`, when: '镜头之间的过渡；先用 effect_preview 看效果再选。', avoid: '每个切点都用花哨转场（大多数切点应是节拍硬切）。',
    params, bindings: {}, declaresUniforms: true, unsupported: unsupported.length ? `需要额外贴图/类型：${unsupported.join(', ')}` : undefined,
    origin: 'gl-transitions', license, author, provenance: `上游 gl-transitions/${path}，用户机器按需下载，本仓库不分发。`, glsl: code };
}

/** 已下载的 gl-transitions（不触发下载）；download=true 时按需下载（受 deadline 限制）。 */
export async function loadGlTransitions({ download = false, deadline } = {}) {
  let registry, source;
  try { registry = loadRegistry(); source = getSource(registry, 'gl-transitions'); } catch { return { effects: [], cached: 0, total: 0 }; }
  if (download || cacheStatus(source).treeCached) {
    const tree = await sourceTree(registry, source);
    const entries = selectFiles(source, tree, 'transitions/');
    if (download) await ensureFiles(registry, source, entries, { deadline });
    const effects = [];
    for (const entry of entries) {
      try { effects.push(glTransitionToEffect(entry.path, readCached(source, entry.path).content.toString('utf8'))); } catch { /* 未下载或被许可规则拒绝 */ }
    }
    return { effects, cached: effects.length, total: entries.length };
  }
  return { effects: [], cached: 0, total: 0 };
}

export async function allEffects(options) {
  const box = loadBoxEffects();
  const gl = await loadGlTransitions(options);
  return { effects: [...box.effects, ...gl.effects], problems: box.problems, glTransitions: { cached: gl.cached, total: gl.total } };
}
export async function findEffect(id) {
  const { effects } = await allEffects();
  const effect = effects.find((entry) => entry.id === id);
  if (!effect) throw Object.assign(new Error(`特效箱里没有 ${id}；用 effect_search 查找`), { status: 404 });
  return effect;
}
export async function searchBox(query) {
  const { effects, glTransitions } = await allEffects();
  return { results: searchEffects(effects, query), total: effects.length, glTransitions };
}
export { effectCard };
