// casebook.mjs — FX：Code Video Casebook（t01090943940-afk/Videos）的按需检索与阅读。
// 内容不随本仓库分发：第一次用到时从上游固定 commit 下载到 .cache/fx（见 fetcher.mjs 与 effects/sources.json）。
import { loadRegistry, getSource, sourceTree, selectFiles, ensureFiles, readCached, FxError } from './fetcher.mjs';

export const CASEBOOK_ID = 'videos-casebook';
const TEXT_CAP = 12000;
const check = (condition, message) => { if (!condition) throw new FxError(message); };

function context(options) {
  const registry = options.registry ?? loadRegistry();
  const source = getSource(registry, CASEBOOK_ID);
  return { registry, source, root: `${source.root}/` };
}
export function notice(source) {
  return `来源：${source.attribution} @ ${source.commit.slice(0, 10)}；许可：${source.licenseStatus === 'author-grant-pending' ? '作者授权（书面许可待落地，不进入对外发布包）' : source.license}。` +
    '只下载了作者自有的文本/代码与联系表；字体、音乐音效、视频、真人照片等第三方素材未下载。案例中的品牌名、成员信息、二维码属于原项目，做新片时必须换成用户自己的。';
}

/** 下载 references/ 下的全部文本（检索卡、CoExp、FILES、汇总参考、index.json）与联系表；约 4MB。 */
async function ensureReferences(options) {
  const { registry, source, root } = context(options);
  const tree = await sourceTree(registry, source, options);
  const entries = selectFiles(source, tree, `${root}references/`).concat(selectFiles(source, tree, `${root}SKILL.md`));
  const result = await ensureFiles(registry, source, entries, options);
  return { registry, source, root, tree, result };
}
async function ensureCaseSource(caseIds, options) {
  const { registry, source, root } = context(options);
  const tree = await sourceTree(registry, source, options);
  const entries = caseIds.flatMap((id) => selectFiles(source, tree, `${root}assets/cases/${id}/`));
  await ensureFiles(registry, source, entries, options);
  return entries;
}
const readText = (source, path) => readCached(source, path).content.toString('utf8');

export async function casebookList(options = {}) {
  const { source, root } = await ensureReferences(options);
  const index = JSON.parse(readText(source, `${root}references/index.json`));
  const cases = index.cases.map((entry) => ({ id: entry.id, title: entry.title, hasSource: (entry.files ?? []).some((file) => file.kind !== 'font' && file.kind !== 'audio' && file.kind !== 'video'), files: (entry.files ?? []).length }));
  return { notice: notice(source), cases, hint: '先按用途选 1–3 个案例：casebook_case 看检索卡与联系表；需要细节再 casebook_read CoExp 的对应行或源码。' };
}

/** 案例检索卡 + 联系表（preview.jpg）。 */
export async function casebookCase(caseId, options = {}) {
  check(/^[a-z0-9-]+$/.test(String(caseId)), 'caseId 无效');
  const { source, root } = await ensureReferences(options);
  const base = `${root}references/cases/${caseId}/`;
  let card;
  try { card = readText(source, `${base}CARD.md`); } catch { throw new FxError(`没有案例 ${caseId}；用 casebook_list 查看全部 id`); }
  let files = '';
  try { files = readText(source, `${base}FILES.md`); } catch { /* 部分案例只有 CoExp */ }
  let preview = null;
  try { preview = readCached(source, `${base}preview.jpg`).content.toString('base64'); } catch { /* 无联系表 */ }
  return { notice: notice(source), caseId, card: card.slice(0, TEXT_CAP), files: files.slice(0, 4000), preview };
}

/**
 * 全文检索（正则，不区分大小写）。scope：cards（检索卡与汇总参考，默认）| coexp | source（需指定 cases，按需下载源码）| all。
 */
export async function casebookSearch({ query, cases, scope = 'cards', limit = 40 } = {}, options = {}) {
  check(typeof query === 'string' && query.length > 0 && query.length <= 200, 'query 为 1..200 字符');
  check(['cards', 'coexp', 'source', 'all'].includes(scope), 'scope 为 cards | coexp | source | all');
  let pattern;
  try { pattern = new RegExp(query, 'i'); } catch { pattern = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'); }
  const { source, root, tree } = await ensureReferences(options);
  const caseFilter = Array.isArray(cases) && cases.length ? new Set(cases) : null;
  check(!(scope === 'source' || scope === 'all') || caseFilter, '搜索源码时必须指定 cases（会按需下载这些案例的源码）');
  const refs = selectFiles(source, tree, `${root}references/`).filter((entry) => /\.(md|json)$/.test(entry.path));
  let paths = refs.map((entry) => entry.path).filter((path) => {
    const caseId = /references\/cases\/([^/]+)\//.exec(path)?.[1];
    if (caseFilter && caseId && !caseFilter.has(caseId)) return false;
    if (scope === 'coexp') return path.endsWith('CoExp.md');
    if (scope === 'cards') return !path.endsWith('CoExp.md') && !path.endsWith('index.json');
    return scope === 'all'; // source 只搜源码；all 再加上全部参考文本
  });
  if (scope === 'source' || scope === 'all') paths = paths.concat((await ensureCaseSource([...caseFilter], options)).map((entry) => entry.path).filter((path) => !/\.(jpe?g|png)$/i.test(path)));
  const hits = [];
  for (const path of paths) {
    let text;
    try { text = readText(source, path); } catch { continue; }
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length && hits.length < limit; i++) {
      if (lines[i].length > 400) continue; // 跳过内联 base64 等超长行
      if (pattern.test(lines[i])) hits.push(`${path.slice(root.length)}:${i + 1}: ${lines[i].trim().slice(0, 200)}`);
    }
    if (hits.length >= limit) break;
  }
  return { notice: notice(source), query, scope, hits, truncated: hits.length >= limit, hint: '用 casebook_read 的 path + lines（如 "40:120"）读上下文。' };
}

/** 读文件（相对 casebook 根，如 references/cases/oneink/CoExp.md 或 assets/cases/oneink/main.js）。 */
export async function casebookRead({ path, lines } = {}, options = {}) {
  check(typeof path === 'string' && path.length > 0, 'path 必填');
  const { registry, source, root } = context(options);
  const full = `${root}${path.replace(/^\/+/, '')}`;
  const tree = await sourceTree(registry, source, options);
  const entry = selectFiles(source, tree, full).find((item) => item.path === full);
  check(entry, `${path} 不存在，或属于不下载的第三方素材/超大文件`);
  await ensureFiles(registry, source, [entry], options);
  if (/\.(jpe?g|png)$/i.test(full)) return { notice: notice(source), path, image: readCached(source, full).content.toString('base64') };
  const all = readText(source, full).split(/\r?\n/);
  let [from, to] = [1, all.length];
  if (lines) {
    const match = /^(\d+):(\d+)$/.exec(String(lines));
    check(match, 'lines 格式为 "起:止"，如 "40:120"');
    [from, to] = [Math.max(1, +match[1]), Math.min(all.length, +match[2])];
  }
  let text = '';
  let line = from;
  for (; line <= to; line++) {
    const next = `${String(line).padStart(5)}  ${all[line - 1]}\n`;
    if (text.length + next.length > TEXT_CAP) break;
    text += next;
  }
  return { notice: notice(source), path, lines: `${from}:${line - 1}`, totalLines: all.length, truncated: line <= to, text };
}
