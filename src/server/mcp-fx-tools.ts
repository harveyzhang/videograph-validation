// mcp-fx-tools.ts — FX-00：上游来源与 Code Video Casebook 的 MCP 工具。
// 内容不随本仓库分发：第一次调用时从上游固定 commit 下载到本机 .cache/fx（git 哈希校验、逐文件许可），之后走缓存。
// 不需要工程服务；直接在 MCP 进程内执行。
// @ts-ignore — 纯 JS 模块，无类型声明。
import { loadRegistry, cacheStatus } from './fx/fetcher.mjs';
// @ts-ignore — 纯 JS 模块，无类型声明。
import { casebookList, casebookCase, casebookSearch, casebookRead } from './fx/casebook.mjs';
// @ts-ignore — 纯 JS 模块，无类型声明。
import { librarySearch, libraryRead } from './fx/library.mjs';
// @ts-ignore — 纯 JS 模块，无类型声明。
import { allEffects, loadGlTransitions } from './fx/effects.mjs';
// @ts-ignore — 纯 JS 模块，无类型声明。
import { searchEffects, effectCard } from '../fx/box/index.mjs';
// @ts-ignore — 纯 JS 模块，无类型声明。
import { withFxBrowser, renderFilmstrip } from './fx/preview-worker.mjs';

type Content = { type: 'text'; text: string } | { type: 'image'; data: string; mimeType: 'image/jpeg' | 'image/png' };

export const fxToolDefinitions = [
  {
    name: 'fx_sources',
    description: '列出动效库/案例库/提示词库登记的上游来源：类型、仓库、固定 commit、许可状态、署名、是否可下载、本机缓存情况。本仓库不分发这些内容，用到时才从上游下载并校验；许可不明的只登记链接。',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'casebook_list',
    description: '列出 Code Video Casebook 的 31 个真实代码视频案例（产品/组织宣传片、卡点、风格合集、节日片、定格、3D 等）。做新片前先挑 1–3 个最接近的案例参考结构与节奏。首次调用会下载约 4MB 文本。',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'casebook_case',
    description: '读取一个案例的检索卡（一句话、规格、什么时候抄它、架构、最值得抄的做法、坑、CoExp 行号导读）、源码清单与 20 帧联系表图片。',
    inputSchema: { type: 'object', properties: { caseId: { type: 'string', description: 'casebook_list 返回的 id，如 skillshub / shuchenglin / codecosmos' } }, required: ['caseId'] },
  },
  {
    name: 'casebook_search',
    description: '在案例库中全文检索（正则，不区分大小写），返回 path:行号:内容。scope：cards（检索卡与汇总参考，默认）| coexp（作者复盘）| source（案例源码，必须给 cases，会按需下载）| all。',
    inputSchema: { type: 'object', properties: {
      query: { type: 'string' },
      scope: { type: 'string', enum: ['cards', 'coexp', 'source', 'all'] },
      cases: { type: 'array', items: { type: 'string' }, description: '限定案例 id；scope 为 source/all 时必填' },
      limit: { type: 'integer', minimum: 1, maximum: 100 },
    }, required: ['query'] },
  },
  {
    name: 'effect_search',
    description: '在特效箱里找动效（像 AE 的“效果和预设”）。按风格/用途关键词（如 risograph 水彩 glitch 卡点 胶片 热成像）、kind（post 镜头后期 | transition 转场）、category 过滤；返回卡片：一句话、何时用、何时别用、参数与默认节拍绑定。选中后先 effect_preview 看效果，再 project_shot_effects / project_transition_configure(mode=effect) 套用。首次查转场会按需下载 gl-transitions。',
    inputSchema: { type: 'object', properties: { query: { type: 'string' }, kind: { type: 'string', enum: ['post', 'transition'] }, category: { type: 'string' }, limit: { type: 'integer', minimum: 1, maximum: 100 } } },
  },
  {
    name: 'effect_get',
    description: '读取一个动效的完整定义：参数规格、默认节拍绑定、来源与许可、着色器代码，以及可直接复制的套用调用示例。',
    inputSchema: { type: 'object', properties: { id: { type: 'string' } }, required: ['id'] },
  },
  {
    name: 'effect_preview',
    description: '在演示素材上渲染动效的帧序列图（8–12 帧，标注时间与拍相位；转场标注进度），返回图片。source：type 文字海报 | scene 风景 | shapes 几何 | portrait 人像剪影。用来比较几种风格/参数后再决定套用哪一个。',
    inputSchema: { type: 'object', properties: { id: { type: 'string' }, params: { type: 'object' }, source: { type: 'string', enum: ['type', 'scene', 'shapes', 'portrait'] }, frames: { type: 'integer', minimum: 4, maximum: 12 } }, required: ['id'] },
  },
  {
    name: 'fx_library_search',
    description: '在 Opus 视频提示词库中检索（正则，不区分大小写），返回 来源id:路径:行号: 片段。来源包括风格提示词集（lemo-opuscar-styles：43 种影片风格）、创作者原文提示词与案例合集等，见 fx_sources。不给 sources 时只搜已下载的库；给 sources:[id] 时按需下载该库（首次 10–60 秒，超时会分次续传）。提示词里引用的他人原文权利归原作者：只作参考，用自己的话按本平台引擎契约重写。',
    inputSchema: { type: 'object', properties: {
      query: { type: 'string' },
      sources: { type: 'array', items: { type: 'string' }, description: 'fx_sources 中 kind=prompts 的来源 id' },
      limit: { type: 'integer', minimum: 1, maximum: 100 },
    }, required: ['query'] },
  },
  {
    name: 'fx_library_read',
    description: '读提示词库里的一个文件（路径相对该仓库根，如 lemo-opuscar-styles 的 styles/watercolor/STYLE.md），可给 lines "起:止"；单次 ≤12k 字符。',
    inputSchema: { type: 'object', properties: { source: { type: 'string' }, path: { type: 'string' }, lines: { type: 'string' } }, required: ['source', 'path'] },
  },
  {
    name: 'casebook_read',
    description: '读案例库文件（相对 casebook 根，如 references/cases/oneink/CoExp.md、references/techniques.md、assets/cases/ai-rise/main_v2.js），可给 lines "起:止"；单次 ≤12k 字符。字体、音乐、视频、真人照片等第三方素材不在下载范围。',
    inputSchema: { type: 'object', properties: { path: { type: 'string' }, lines: { type: 'string', description: '如 "40:120"' } }, required: ['path'] },
  },
];
export const fxToolNames = new Set(fxToolDefinitions.map((tool) => tool.name));

const json = (value: unknown): Content => ({ type: 'text', text: JSON.stringify(value, null, 2) });

export async function callFxTool(name: string, args: Record<string, unknown>): Promise<{ content: Content[] }> {
  if (name === 'fx_sources') {
    const registry = loadRegistry();
    return { content: [json({ policy: registry.policy, sources: registry.sources.map((source: Record<string, unknown>) => ({
      id: source.id, kind: source.kind ?? 'casebook/effects', title: source.title, repo: source.repo, url: source.url ?? `https://github.com/${source.repo}`, downloadable: source.downloadable !== false,
      commit: source.commit, license: source.license, licenseStatus: source.licenseStatus,
      licenseNote: source.licenseNote, attribution: source.attribution, thirdPartyNotes: source.thirdPartyNotes, cache: cacheStatus(source) })) })] };
  }
  if (name === 'casebook_list') return { content: [json(await casebookList())] };
  if (name === 'casebook_case') {
    const { preview, card, files, ...rest } = await casebookCase(String(args.caseId ?? ''));
    return { content: [json(rest), { type: 'text', text: card }, ...(files ? [{ type: 'text' as const, text: files }] : []),
      ...(preview ? [{ type: 'image' as const, data: preview, mimeType: 'image/jpeg' as const }] : [])] };
  }
  if (name === 'casebook_search') {
    const { hits, ...rest } = await casebookSearch({ query: args.query, scope: args.scope ?? 'cards', cases: args.cases, limit: args.limit ?? 40 });
    return { content: [json(rest), { type: 'text', text: hits.join('\n') || '（无命中）' }] };
  }
  if (name === 'effect_search') {
    const kind = args.kind === 'transition' || args.kind === 'post' ? args.kind : undefined;
    // 要找转场且本机还没有 gl-transitions 时，按需下载（40 秒时限，超时下次续传）。
    if (kind !== 'post') { const cached = await loadGlTransitions(); if (!cached.total) await loadGlTransitions({ download: true, deadline: Date.now() + 40000 }); }
    const { effects } = await allEffects();
    const results = searchEffects(effects.filter((effect: Record<string, unknown>) => !effect.unsupported), { query: args.query ?? '', kind, category: args.category, limit: args.limit ?? 30 });
    return { content: [json({ total: effects.length, count: results.length, results, hint: '先 effect_preview 看效果；镜头后期用 project_shot_effects，转场用 project_transition_configure mode=effect。' })] };
  }
  if (name === 'effect_get') {
    const { effects } = await allEffects();
    const effect = effects.find((entry: Record<string, unknown>) => entry.id === args.id);
    if (!effect) throw new Error(`特效箱里没有 ${String(args.id)}；用 effect_search 查找`);
    const example = effect.kind === 'transition'
      ? { tool: 'project_transition_configure', args: { projectId: '<工程>', transitionId: '<转场>', expectedInputRevision: '<版本>', config: { mode: 'effect', effectId: effect.id, duration: 0.5, params: {} } } }
      : { tool: 'project_shot_effects', args: { projectId: '<工程>', shotId: '<镜头>', expectedInputRevision: '<版本>', effects: [{ id: effect.id, params: {} }] } };
    return { content: [json({ ...effectCard(effect), provenance: effect.provenance, unsupported: effect.unsupported, example }), { type: 'text', text: effect.glsl }] };
  }
  if (name === 'effect_preview') {
    const { effects } = await allEffects();
    const effect = effects.find((entry: Record<string, unknown>) => entry.id === args.id);
    if (!effect) throw new Error(`特效箱里没有 ${String(args.id)}`);
    if (effect.unsupported) throw new Error(`${effect.id} 暂不支持：${effect.unsupported}`);
    const frames = Math.min(12, Math.max(4, Number(args.frames ?? 8)));
    const png = await withFxBrowser((page: unknown) => renderFilmstrip(page, effect, { values: (args.params as Record<string, unknown>) ?? {}, source: (args.source as string) ?? 'type', toSource: 'shapes', frames, duration: effect.kind === 'transition' ? 1 : 1.75, width: 320, columns: 4 }));
    return { content: [json({ id: effect.id, name: effect.name, kind: effect.kind, frames, note: '演示素材上的效果；套用到镜头后用 project_stills / project_filmstrip 看真实画面。' }), { type: 'image', data: png, mimeType: 'image/png' }] };
  }
  if (name === 'fx_library_search') {
    const { hits, ...rest } = await librarySearch({ query: args.query, sources: args.sources, limit: args.limit ?? 40 });
    return { content: [json(rest), { type: 'text', text: hits.join('\n') || '（无命中）' }] };
  }
  if (name === 'fx_library_read') {
    const { text, ...rest } = await libraryRead({ source: args.source, path: args.path, lines: args.lines });
    return { content: [json(rest), { type: 'text', text }] };
  }
  if (name === 'casebook_read') {
    const { text, image, ...rest } = await casebookRead({ path: args.path, lines: args.lines });
    return { content: [json(rest), ...(image ? [{ type: 'image' as const, data: image, mimeType: 'image/jpeg' as const }] : [{ type: 'text' as const, text }])] };
  }
  throw new Error(`unknown fx tool: ${name}`);
}
