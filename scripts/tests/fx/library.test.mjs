// FX 提示词库：离线测试（假 GitHub）。只登记链接的来源不下载；不指定来源时只搜已下载的库；下载有时限可续传；长行给片段。
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const tmp = mkdtempSync(join(tmpdir(), 'vg-fx-lib-'));
process.env.VIDEOGRAPH_FX_CACHE = join(tmp, 'cache');
const fx = await import('../../../src/server/fx/fetcher.mjs');
const lib = await import('../../../src/server/fx/library.mjs');
test.after(() => rmSync(tmp, { recursive: true, force: true }));

const longPrompt = JSON.stringify({ prompt: `${'Make a cinematic piece. '.repeat(40)}Use a risograph two-color print look with misregistration.${' Keep it calm.'.repeat(30)}` });
const files = {
  'styles/riso/STYLE.md': '# Risograph\nTwo inks, grain, misregistration.\n',
  'data/prompts.json': longPrompt,
  'demo/clip.mp4': 'MP4',
};
const tree = Object.entries(files).map(([path, content]) => ({ path, type: 'blob', sha: fx.gitBlobSha(Buffer.from(content)), size: Buffer.byteLength(content) }));
const fakeFetch = (log = []) => async (url) => {
  log.push(url);
  const parsed = new URL(url);
  if (parsed.hostname === 'api.github.com') return new Response(JSON.stringify({ tree, truncated: false }));
  const path = decodeURIComponent(parsed.pathname.split('/').slice(4).join('/'));
  return path in files ? new Response(files[path]) : new Response('missing', { status: 404 });
};
const base = { kind: 'prompts', root: '', commit: 'c'.repeat(40), include: ['**'], exclude: ['**/*.mp4'], extensions: ['md', 'json'], maxFileBytes: 100000, licenseOverrides: [] };
const registry = {
  schema: 1, policy: { spdxAllow: ['MIT'], licenseRefAllow: [], hosts: ['api.github.com', 'raw.githubusercontent.com'] },
  sources: [
    { ...base, id: 'styles', repo: 'o/styles', license: 'MIT', attribution: 'styles (MIT)', licenseNote: 'MIT。' },
    { ...base, id: 'other', repo: 'o/other', license: 'MIT', attribution: 'other (MIT)', licenseNote: 'MIT。' },
    { ...base, id: 'nolicense', repo: 'o/none', license: 'LicenseRef-none', downloadable: false, attribution: 'none', licenseNote: '无许可证。', url: 'https://github.com/o/none' },
  ],
};

test('只登记链接的来源：不联网、直接拒绝', async () => {
  const log = [];
  await assert.rejects(fx.sourceTree(registry, registry.sources[2], { fetchImpl: fakeFetch(log) }), /只登记链接/);
  assert.equal(log.length, 0);
});

test('下载时限：到时停止取新文件并报告剩余，下次续传', async () => {
  const source = { ...registry.sources[0], id: 'styles-slow' };
  const entries = fx.selectFiles(source, tree);
  await fx.sourceTree(registry, source, { fetchImpl: fakeFetch() });
  const first = await fx.ensureFiles(registry, source, entries, { fetchImpl: fakeFetch(), concurrency: 1, deadline: Date.now() - 1 });
  assert.equal(first.fetched.length, 1, '已在途的一个文件照常落盘');
  assert.equal(first.pending, entries.length - 1);
  const second = await fx.ensureFiles(registry, source, entries, { fetchImpl: fakeFetch() });
  assert.equal(second.fetched.length, entries.length - 1);
  assert.equal(second.pending, 0);
});

test('检索：指定来源时按需下载；长 JSON 行只返回命中片段；媒体不下载', async () => {
  const result = await lib.librarySearch({ query: 'misregistration', sources: ['styles'] }, { registry, fetchImpl: fakeFetch() });
  assert.equal(result.hits.length, 2);
  const jsonHit = result.hits.find((hit) => hit.includes('data/prompts.json'));
  assert.ok(jsonHit.length < 400 && jsonHit.includes('risograph'), jsonHit);
  assert.ok(!fx.selectFiles(registry.sources[0], tree).some((entry) => entry.path.endsWith('.mp4')));
});

test('检索：不指定来源时只搜已下载的库，未下载与无许可的列入 skipped', async () => {
  const result = await lib.librarySearch({ query: 'Risograph' }, { registry, fetchImpl: fakeFetch() });
  assert.ok(result.hits.some((hit) => hit.startsWith('styles:')));
  assert.ok(result.skipped.some((entry) => entry.id === 'other' && /尚未下载/.test(entry.reason)));
  assert.ok(result.skipped.some((entry) => entry.id === 'nolicense' && /只登记链接/.test(entry.reason)));
});

test('读取：按行读取并附许可说明；非提示词来源拒绝', async () => {
  const read = await lib.libraryRead({ source: 'styles', path: 'styles/riso/STYLE.md', lines: '2:2' }, { registry, fetchImpl: fakeFetch() });
  assert.match(read.text, /Two inks/);
  assert.match(read.notice, /styles \(MIT\)/);
  await assert.rejects(lib.libraryRead({ source: 'styles', path: 'demo/clip.mp4' }, { registry, fetchImpl: fakeFetch() }), /不下载的媒体/);
});
