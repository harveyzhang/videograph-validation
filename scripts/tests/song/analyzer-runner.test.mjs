// SONG-01 runner 测试：用 stub 解释器验证缓存键、原子发布、缓存命中与摘要；不依赖真实 Python 环境。
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { analysisCacheKey, runAnalysis, analysisSummary, ANALYZER_VERSION } from '../../../src/song/analyzer-runner.mjs';

const root = dirname(dirname(dirname(dirname(fileURLToPath(import.meta.url)))));
const stubPython = join(root, 'scripts', 'tests', 'song', 'fixtures', 'stub_analyzer.mjs');
const work = mkdtempSync(join(tmpdir(), 'videograph-song-runner-'));
const audio = join(work, 'song.mp3');
writeFileSync(audio, 'fake audio bytes');
const cache = join(work, 'cache');
after(() => rmSync(work, { recursive: true, force: true }));

test('缓存键由 audioHash+stages+参数+版本决定；参数不同键不同', () => {
  const hash = 'a'.repeat(64);
  const base = analysisCacheKey(hash, ['t0', 't1'], { language: null, gpu: true, hasLyrics: false });
  assert.equal(base, analysisCacheKey(hash, ['t0', 't1'], { language: null, gpu: true, hasLyrics: false }));
  assert.notEqual(base, analysisCacheKey(hash, ['t0', 't1'], { language: 'zh', gpu: true, hasLyrics: false }));
  assert.notEqual(base, analysisCacheKey(hash, ['t0', 't1', 't3'], { language: null, gpu: true, hasLyrics: false }));
  assert.notEqual(base, analysisCacheKey(hash, ['t0', 't1'], { language: null, gpu: true, hasLyrics: false }, 'other-version'));
  assert.equal(ANALYZER_VERSION, 'song01-v1');
});
test('stub 解释器跑通全链路，二次调用命中缓存', async () => {
  const progress = [];
  const first = await runAnalysis({ audioPath: audio, stages: ['t0', 't1'], python: process.execPath, analyzerScript: stubPython, t3Python: process.execPath, cacheRoot: cache, title: 'Stub Song', onProgress: (line) => progress.push(line) });
  assert.equal(first.cached, false);
  assert.equal(first.analysis.title, 'Stub Song');
  assert.equal(first.analysis.schema, 'videograph-analysis/v2');
  assert.ok(progress.some((line) => line.stage === 't0' && line.status === 'done'));
  assert.ok(existsSync(first.file));
  const second = await runAnalysis({ audioPath: audio, stages: ['t0', 't1'], python: process.execPath, analyzerScript: stubPython, t3Python: process.execPath, cacheRoot: cache, title: 'Stub Song' });
  assert.equal(second.cached, true);
  assert.equal(second.analysis.title, first.analysis.title);
});
test('带歌词文本的 T3 桩链路产出 lyrics 层；摘要不携带绝对路径', async () => {
  const result = await runAnalysis({ audioPath: audio, stages: ['t0', 't1', 't3'], python: process.execPath, analyzerScript: stubPython, t3Python: process.execPath, cacheRoot: cache, lyricsText: '你好\n世界', language: 'zh' });
  assert.equal(result.analysis.lyrics.lines.length, 2);
  assert.equal(result.analysis.lyrics.humanConfirmed, true);
  const summary = analysisSummary(result.analysis);
  assert.equal(summary.instrumental, false);
  assert.equal(summary.lyrics.humanConfirmed, true);
  assert.doesNotMatch(JSON.stringify(summary), /[A-Za-z]:[\\/]/, '摘要不得含本机绝对路径');
});
test('缺音频或解释器时错误清晰', async () => {
  await assert.rejects(() => runAnalysis({ audioPath: join(work, 'missing.mp3'), python: process.execPath, analyzerScript: stubPython, t3Python: process.execPath }), /音频不存在/);
  await assert.rejects(() => runAnalysis({ audioPath: audio, python: join(work, 'no-python.exe') }), /解释器不存在/);
});
