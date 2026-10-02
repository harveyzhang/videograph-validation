// mcp-fx-tools.ts — FX-00：上游来源与 Code Video Casebook 的 MCP 工具。
// 内容不随本仓库分发：第一次调用时从上游固定 commit 下载到本机 .cache/fx（git 哈希校验、逐文件许可），之后走缓存。
// 不需要工程服务；直接在 MCP 进程内执行。
// @ts-ignore — 纯 JS 模块，无类型声明。
import { loadRegistry, cacheStatus } from './fx/fetcher.mjs';
// @ts-ignore — 纯 JS 模块，无类型声明。
import { casebookList, casebookCase, casebookSearch, casebookRead } from './fx/casebook.mjs';
// @ts-ignore — 纯 JS 模块，无类型声明。
import { librarySearch, libraryRead } from './fx/library.mjs';

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
