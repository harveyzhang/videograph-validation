// FX-00 MCP 端到端（离线）：先用假上游把缓存填好，再起真实 stdio MCP server，验证案例库工具全部走缓存、不联网。
import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const root = fileURLToPath(new URL('../../..', import.meta.url));
const tmp = mkdtempSync(join(tmpdir(), 'vg-fx-mcp-'));
process.env.VIDEOGRAPH_FX_CACHE = join(tmp, 'cache');
process.env.VIDEOGRAPH_FX_REGISTRY = join(tmp, 'sources.json');
const fx = await import('../../../src/server/fx/fetcher.mjs');
let client;

const R = 'skills/code-video-casebook/';
const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1]);
const files = {
  [`${R}SKILL.md`]: '# Casebook\n',
  [`${R}references/index.json`]: JSON.stringify({ name: 'casebook', cases: [{ id: 'demo', title: '示例宣传片', files: [{ path: 'main.js', kind: 'text' }] }] }),
  [`${R}references/techniques.md`]: '# 技法\n| 拍脉冲 exp(-phase*k) | demo |\n',
  [`${R}references/cases/demo/CARD.md`]: '---\nid: "demo"\n---\n一句话：示例\n',
  [`${R}references/cases/demo/CoExp.md`]: '第一行\n侧链压缩 0.25+0.75x\n第三行\n',
  [`${R}references/cases/demo/FILES.md`]: '| main.js | 3 行 |\n',
  [`${R}references/cases/demo/preview.jpg`]: jpeg,
  [`${R}assets/cases/demo/main.js`]: 'const beatPulse = (p) => Math.exp(-p * 8);\n',
  [`${R}assets/cases/demo/bgm.mp3`]: 'MP3',
};
const tree = Object.entries(files).map(([path, content]) => ({ path, type: 'blob', sha: fx.gitBlobSha(Buffer.from(content)), size: Buffer.byteLength(content) }));
const registry = {
  schema: 1,
  policy: { spdxAllow: ['MIT'], licenseRefAllow: ['LicenseRef-author-grant'], hosts: ['api.github.com', 'raw.githubusercontent.com'] },
  sources: [{ id: 'videos-casebook', title: 'casebook', repo: 'o/book', commit: 'b'.repeat(40), root: 'skills/code-video-casebook', license: 'LicenseRef-author-grant',
    licenseStatus: 'author-grant-pending', attribution: 'casebook by friend', include: [`${R}**`], exclude: ['**/*.mp3'], extensions: ['md', 'json', 'js', 'jpg'],
    imageAllow: ['**/references/cases/*/preview.jpg'], maxFileBytes: 100000, licenseOverrides: [] }],
};
const fakeFetch = async (url) => {
  const parsed = new URL(url);
  if (parsed.hostname === 'api.github.com') return new Response(JSON.stringify({ tree, truncated: false }));
  const path = decodeURIComponent(parsed.pathname.split('/').slice(4).join('/'));
  return path in files ? new Response(files[path]) : new Response('missing', { status: 404 });
};

before(async () => {
  writeFileSync(process.env.VIDEOGRAPH_FX_REGISTRY, JSON.stringify(registry));
  await fx.ensurePrefix(fx.loadRegistry(), 'videos-casebook', '', { fetchImpl: fakeFetch });
  client = new Client({ name: 'vg-fx-test', version: '1.0' });
  // 不给工程服务：FX 工具不依赖它；把网络代理指向不存在的地址，任何联网都会失败。
  await client.connect(new StdioClientTransport({ command: process.execPath, args: ['--experimental-strip-types', '--no-warnings', 'src/pdoom/mcp-server.ts'], cwd: root,
    env: { ...process.env, HTTPS_PROXY: 'http://127.0.0.1:9', VIDEOGRAPH_SERVICE_URL: 'http://127.0.0.1:9' }, stderr: 'pipe' }));
});
after(async () => { await client?.close().catch(() => {}); rmSync(tmp, { recursive: true, force: true }); });

async function call(name, args = {}) {
  const response = await client.callTool({ name, arguments: args });
  const texts = response.content.filter((item) => item.type === 'text').map((item) => item.text);
  if (response.isError) throw new Error(texts.join('\n'));
  return { value: JSON.parse(texts[0]), texts: texts.slice(1), images: response.content.filter((item) => item.type === 'image') };
}

test('注册：FX 工具列出，fx_sources 显示许可状态与缓存', async () => {
  const names = (await client.listTools()).tools.map((tool) => tool.name);
  for (const name of ['fx_sources', 'casebook_list', 'casebook_case', 'casebook_search', 'casebook_read']) assert.ok(names.includes(name), name);
  const { value } = await call('fx_sources');
  assert.equal(value.sources[0].licenseStatus, 'author-grant-pending');
  assert.ok(value.sources[0].cache.files >= 8);
});

test('casebook_list / casebook_case：走缓存，返回检索卡与联系表图片，并带许可说明', async () => {
  const list = await call('casebook_list');
  assert.deepEqual(list.value.cases.map((entry) => entry.id), ['demo']);
  assert.match(list.value.notice, /书面许可待落地/);
  const card = await call('casebook_case', { caseId: 'demo' });
  assert.match(card.texts[0], /一句话：示例/);
  assert.equal(card.images.length, 1);
  assert.equal(card.images[0].mimeType, 'image/jpeg');
});

test('casebook_search / casebook_read：检索 CoExp 与源码，按行读取；第三方音频不可读', async () => {
  const coexp = await call('casebook_search', { query: '侧链', scope: 'coexp' });
  assert.match(coexp.texts[0], /references\/cases\/demo\/CoExp\.md:2:/);
  const source = await call('casebook_search', { query: 'beatPulse', scope: 'source', cases: ['demo'] });
  assert.match(source.texts[0], /assets\/cases\/demo\/main\.js:1:/);
  const read = await call('casebook_read', { path: 'references/cases/demo/CoExp.md', lines: '2:3' });
  assert.match(read.texts[0], /侧链压缩/);
  assert.equal(read.value.lines, '2:3');
  const blocked = await client.callTool({ name: 'casebook_read', arguments: { path: 'assets/cases/demo/bgm.mp3' } });
  assert.equal(blocked.isError, true);
  const sourceNoCases = await client.callTool({ name: 'casebook_search', arguments: { query: 'x', scope: 'source' } });
  assert.equal(sourceNoCases.isError, true);
});

test('提示词库工具经真实 MCP server 可调用（防模块语法/接线错误）', async () => {
  const names = (await client.listTools()).tools.map((tool) => tool.name);
  for (const name of ['fx_library_search', 'fx_library_read']) assert.ok(names.includes(name), name);
  const result = await call('fx_library_search', { query: 'anything' });
  assert.ok(Array.isArray(result.value.skipped));
  assert.equal(result.texts[0], '（无命中）');
});
