// 特效箱的格式、校验与检索（浏览器与 Node 共用，无 I/O）。
// 每个动效是 effects/box/<id>.glsl 一个文件：头部 /*@effect {JSON manifest} @effect*/ 注释 + 着色器正文。
// 一个文件一个动效，便于多个 AI 并行批量编写而互不冲突；读取目录的加载器在 src/server/fx/effects.mjs。

export const BOX_VERSION = '2026-10-02';
export const PARAM_TYPES = ['float', 'int', 'bool', 'vec2', 'vec3', 'vec4', 'ivec2', 'color'];
export const BINDING_SOURCES = ['beat', 'kick', 'bar', 'energy'];
export const CATEGORIES = ['印刷与版画', '手绘与绘画', '复古与数字', '胶片与调色', '运动与节拍', '光效与粒子', '几何与图形', '文字与排版', '转场'];

/** 解析一个动效文件；格式错误抛出带文件名的错误。 */
export function parseEffectFile(text, fileName = '') {
  const match = /^\s*\/\*@effect\s*([\s\S]*?)\s*@effect\*\/\s*([\s\S]*)$/.exec(text);
  if (!match) throw new Error(`${fileName}: 缺少 /*@effect {...} @effect*/ 头部`);
  let manifest;
  try { manifest = JSON.parse(match[1]); } catch (error) { throw new Error(`${fileName}: 头部 JSON 无效：${error.message}`); }
  const id = fileName.replace(/^.*[\/]/, '').replace(/\.glsl$/, '');
  if (id && manifest.id !== id) throw new Error(`${fileName}: manifest.id 必须与文件名一致（${id}）`);
  return { version: 1, license: 'MIT', origin: 'videograph', ...manifest, glsl: match[2] };
}

/** 校验一个动效定义；返回问题列表（空 = 合法）。 */
export function validateEffect(effect) {
  const problems = [];
  if (!/^[a-z0-9][a-z0-9-]{1,63}$/.test(effect.id ?? '')) problems.push('id 必须是小写字母数字与连字符');
  if (!['post', 'transition'].includes(effect.kind)) problems.push('kind 为 post | transition');
  if (!effect.name || !effect.summary) problems.push('需要 name 与 summary');
  if (typeof effect.glsl !== 'string' || !effect.glsl.includes(effect.kind === 'transition' ? 'transition(' : 'effect(')) problems.push(`glsl 必须定义 ${effect.kind === 'transition' ? 'vec4 transition(vec2 uv)' : 'vec4 effect(vec2 uv)'}`);
  for (const [name, spec] of Object.entries(effect.params ?? {})) {
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name) || /^(u[A-Z]|fx|gl_)/.test(name)) problems.push(`参数名 ${name} 非法或与保留名冲突`);
    if (!PARAM_TYPES.includes(spec.type ?? 'float')) problems.push(`参数 ${name} 类型无效`);
    if ((spec.type ?? 'float') === 'float' && (typeof spec.default !== 'number' || (spec.min !== undefined && spec.default < spec.min) || (spec.max !== undefined && spec.default > spec.max))) problems.push(`参数 ${name} 默认值越界`);
    if (spec.type === 'color' && !/^#[0-9a-f]{6}$/i.test(spec.default)) problems.push(`参数 ${name} 颜色默认值须为 #RRGGBB`);
  }
  for (const [name, binding] of Object.entries(effect.bindings ?? {})) {
    if (!effect.params?.[name] || (effect.params[name].type ?? 'float') !== 'float') problems.push(`绑定 ${name} 必须指向 float 参数`);
    if (!BINDING_SOURCES.includes(binding.to)) problems.push(`绑定 ${name}.to 为 ${BINDING_SOURCES.join('/')}`);
  }
  return problems;
}

/** 卡片摘要（检索结果用，不含 glsl）。 */
export function effectCard(effect) {
  const { glsl, ...rest } = effect;
  return { id: rest.id, name: rest.name, kind: rest.kind, category: rest.category, tags: rest.tags ?? [], summary: rest.summary, when: rest.when, avoid: rest.avoid,
    params: Object.fromEntries(Object.entries(rest.params ?? {}).map(([name, spec]) => [name, { type: spec.type ?? 'float', default: spec.default, min: spec.min, max: spec.max, label: spec.label ?? name }])),
    bindings: rest.bindings ?? {}, origin: rest.origin, license: rest.license, inspiredBy: rest.inspiredBy ?? [], author: rest.author };
}

/** 关键词检索：名称/标签/类别/用途描述；kind、category 过滤。 */
export function searchEffects(effects, { query = '', kind, category, limit = 60 } = {}) {
  const terms = String(query).toLowerCase().split(/[\s,，、]+/).filter(Boolean);
  return effects
    .filter((effect) => (!kind || effect.kind === kind) && (!category || effect.category === category))
    .map((effect) => {
      const hay = [effect.id, effect.name, effect.category, effect.summary, effect.when, ...(effect.tags ?? [])].join(' ').toLowerCase();
      const score = terms.length ? terms.reduce((sum, term) => sum + (hay.includes(term) ? (effect.tags ?? []).some((tag) => tag.toLowerCase() === term) ? 3 : 1 : 0), 0) : 1;
      return { effect, score };
    })
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score || a.effect.name.localeCompare(b.effect.name))
    .slice(0, limit)
    .map((entry) => effectCard(entry.effect));
}
