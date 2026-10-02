// library.mjs — FX：提示词/知识库（kind: prompts 的登记来源）的按需检索与阅读。
// 与 casebook.mjs 相同：内容不随本仓库分发，第一次用到某个来源时从上游固定 commit 下载文本到 .cache/fx。
import { loadRegistry, getSource, sourceTree, selectFiles, ensureFiles, readCached, cacheStatus, FxError } from './fetcher.mjs';

const DOWNLOAD_BUDGET_MS = 40000;

const TEXT_CAP = 12000;
const check = (condition, message) => { if (!condition) throw new FxError(message); };

export function librarySources(registry = loadRegistry()) {
  return registry.sources.filter((source) => source.kind === 'prompts');
}
export function libraryNotice(source) {
  return `来源：${source.attribution} @ ${source.commit.slice(0, 10)}。${source.licenseNote}`;
}

/** 下载某来源允许的全部文本（首次较慢，之后走缓存）。 */
async function ensureSource(registry, source, options, deadline) {
  const tree = await sourceTree(registry, source, options);
  const entries = selectFiles(source, tree, source.root ?? '');
  const { pending } = await ensureFiles(registry, source, entries, { ...options, deadline });
  return { entries, pending };
}

/** 命中行的片段：短行原样返回；长行（常见于 JSON 里一整条提示词）只截取命中点前后。 */
function snippet(line, match) {
  if (line.length <= 240) return line.trim();
  const at = Math.max(0, match.index - 100);
  return `${at > 0 ? '…' : ''}${line.slice(at, match.index + match[0].length + 140).trim()}…`;
}

/**
 * 跨提示词库检索（正则，不区分大小写）。sources 省略 = 全部可下载的提示词来源；首次会下载这些来源的文本。
 * 返回 { hits: ["来源id:路径:行号: 片段"], skipped: [{ id, reason }] }。
 */
export async function librarySearch({ query, sources, limit = 40 } = {}, options = {}) {
  check(typeof query === 'string' && query.length > 0 && query.length <= 200, 'query 为 1..200 字符');
  let pattern;
  try { pattern = new RegExp(query, 'i'); } catch { pattern = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'); }
  const registry = options.registry ?? loadRegistry();
  const all = librarySources(registry);
  const explicit = Array.isArray(sources) && sources.length > 0;
  const wanted = explicit ? sources.map((id) => getSource(registry, id)) : all;
  const hits = [], skipped = [];
  const deadline = Date.now() + (options.budgetMs ?? DOWNLOAD_BUDGET_MS);
  for (const source of wanted) {
    if (source.downloadable === false) { skipped.push({ id: source.id, reason: '许可不明，只登记链接', url: source.url }); continue; }
    // 不指定来源时只搜已下载的库，避免一次下载全部来源超过 MCP 请求超时。
    if (!explicit && cacheStatus(source).files === 0) { skipped.push({ id: source.id, reason: '尚未下载：用 sources:[id] 指定后首次下载（约 10–60 秒，可分次续传）' }); continue; }
    let entries;
    try {
      const ready = await ensureSource(registry, source, options, deadline);
      entries = ready.entries;
      if (ready.pending) skipped.push({ id: source.id, reason: `下载未完成，还剩 ${ready.pending} 个文件：再调用一次继续（本次只搜已下载部分）` });
    } catch (error) { skipped.push({ id: source.id, reason: String(error.message ?? error) }); continue; }
    for (const entry of entries) {
      let text;
      try { text = readCached(source, entry.path).content.toString('utf8'); } catch { continue; }
      const lines = text.split(/\r?\n/);
      for (let i = 0; i < lines.length && hits.length < limit; i++) {
        if (lines[i].length > 4000 && !/\s/.test(lines[i].slice(0, 400))) continue; // 内联 base64 等
        const match = pattern.exec(lines[i]);
        if (match) hits.push(`${source.id}:${entry.path}:${i + 1}: ${snippet(lines[i], match)}`);
      }
      if (hits.length >= limit) break;
    }
    if (hits.length >= limit) break;
  }
  return { query, hits, truncated: hits.length >= limit, skipped,
    notice: '提示词库里引用的他人提示词权利归原作者：只作参考与灵感，结合本平台引擎契约用自己的话重写；引用时注明原作者。',
    hint: '用 fx_library_read 的 source + path + lines（如 "40:120"）读上下文。' };
}

/** 读提示词库里的一个文件（路径相对仓库根）。 */
export async function libraryRead({ source: sourceId, path, lines } = {}, options = {}) {
  check(typeof sourceId === 'string' && typeof path === 'string' && path.length > 0, 'source 与 path 必填');
  const registry = options.registry ?? loadRegistry();
  const source = getSource(registry, sourceId);
  check(source.kind === 'prompts', `${sourceId} 不是提示词库来源（案例库请用 casebook_read）`);
  const tree = await sourceTree(registry, source, options);
  const entry = selectFiles(source, tree, path).find((item) => item.path === path);
  check(entry, `${path} 不存在，或属于不下载的媒体/超大文件`);
  await ensureFiles(registry, source, [entry], options);
  const all = readCached(source, path).content.toString('utf8').split(/\r?\n/);
  let [from, to] = [1, all.length];
  if (lines) {
    const match = /^(\d+):(\d+)$/.exec(String(lines));
    check(match, 'lines 格式为 "起:止"，如 "40:120"');
    [from, to] = [Math.max(1, +match[1]), Math.min(all.length, +match[2])];
  }
  let text = '', line = from;
  for (; line <= to; line++) {
    const next = `${String(line).padStart(5)}  ${all[line - 1]}\n`;
    if (text.length + next.length > TEXT_CAP) break;
    text += next;
  }
  return { source: sourceId, path, lines: `${from}:${line - 1}`, totalLines: all.length, truncated: line <= to, notice: libraryNotice(source), text };
}
