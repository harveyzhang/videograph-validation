// SONG-00 适配器测试：pdoom 真实数据往返 ≤1e-6（硬指标）、器乐 toFullSong、格式兼容性。
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { fromPdoom } from '../../../src/song/adapters/fromPdoom.mjs';
import { toEngineAudio, toEngineLyrics } from '../../../src/song/adapters/toEngine.mjs';
import { toFullSong } from '../../../src/song/adapters/toFullSong.mjs';
import { validateAnalysis, isInstrumental } from '../../../src/song/contract.mjs';

const productRoot = dirname(dirname(dirname(dirname(fileURLToPath(import.meta.url)))));
const pdoomData = join(productRoot, '..', 'pdoom-video', 'data');
const pdoomAudio = join(productRoot, '..', 'pdoom-video', 'audio', 'pdoom.mp3');
const work = mkdtempSync(join(tmpdir(), 'videograph-song-adapters-'));
after(() => rmSync(work, { recursive: true, force: true }));
const pdoomAvailable = existsSync(join(pdoomData, 'audio.json')) && existsSync(pdoomAudio);
const skipPdoom = pdoomAvailable ? false : '本机缺少 ../pdoom-video 参考数据';

const close = (actual, expected, label, epsilon = 1e-6) => {
  if (Array.isArray(expected)) {
    assert.equal(actual.length, expected.length, `${label} 长度`);
    for (let i = 0; i < expected.length; i++) close(actual[i], expected[i], `${label}[${i}]`, epsilon);
    return;
  }
  if (typeof expected === 'number') assert.ok(Math.abs(actual - expected) <= epsilon, `${label}: ${actual} vs ${expected}`);
  else assert.equal(actual, expected, label);
};

test('pdoom 数据 → v2 → 引擎格式：数值往返一致（≤1e-6）', { skip: skipPdoom }, () => {
  const originalAudio = JSON.parse(readFileSync(join(pdoomData, 'audio.json'), 'utf8'));
  const originalLyrics = JSON.parse(readFileSync(join(pdoomData, 'lyrics.json'), 'utf8'));
  const analysis = fromPdoom({ dataDir: pdoomData, audioPath: pdoomAudio, title: "I'm Upping My P(doom) (Claude-Pop)" });
  const engineAudio = toEngineAudio(analysis);
  for (const key of ['duration', 'bpm', 'beat_period', 'time_signature', 'fps', 'notes']) close(engineAudio[key], originalAudio[key], `audio.${key}`);
  close(engineAudio.beats, originalAudio.beats, 'audio.beats');
  close(engineAudio.downbeats, originalAudio.downbeats, 'audio.downbeats');
  for (const key of ['rms', 'low', 'mid', 'high', 'vocal', 'drums', 'bass', 'other']) close(engineAudio[key], originalAudio[key], `audio.${key}`);
  for (const key of ['kick', 'snare', 'hat', 'vocal']) close(engineAudio.onsets[key], originalAudio.onsets[key], `onsets.${key}`);
  assert.deepEqual(engineAudio.sections, originalAudio.sections);
  const engineLyrics = toEngineLyrics(analysis);
  assert.equal(engineLyrics.lines.length, originalLyrics.lines.length);
  originalLyrics.lines.forEach((line, index) => {
    assert.equal(engineLyrics.lines[index].i, line.i, `line ${index} i`);
    assert.equal(engineLyrics.lines[index].text, line.text);
    close(engineLyrics.lines[index].start, line.start, `line ${index} start`);
    close(engineLyrics.lines[index].end, line.end, `line ${index} end`);
    assert.equal(engineLyrics.lines[index].words.length, line.words.length);
    line.words.forEach((word, w) => {
      assert.equal(engineLyrics.lines[index].words[w].w, word.w);
      close(engineLyrics.lines[index].words[w].start, word.start, `line ${index} word ${w} start`);
      close(engineLyrics.lines[index].words[w].end, word.end, `line ${index} word ${w} end`);
      close(engineLyrics.lines[index].words[w].conf ?? 1, word.conf ?? 1, `line ${index} word ${w} conf`);
    });
  });
  assert.deepEqual(engineLyrics.extras, originalLyrics.extras);
  assert.equal(engineLyrics.notes, originalLyrics.notes);
});
test('v2 契约自检：fromPdoom 结果通过校验且标记 reference-import', { skip: skipPdoom }, () => {
  const analysis = fromPdoom({ dataDir: pdoomData, audioPath: pdoomAudio });
  assert.equal(analysis.schema, 'videograph-analysis/v2');
  assert.equal(analysis.provenance.audio.tool, 'pdoom-video/analysis');
  assert.equal(analysis.provenance.audio.version, 'reference-import');
  assert.equal(analysis.lyrics.humanConfirmed, true, 'pdoom 歌词是人工逐行核验过的');
  assert.equal(isInstrumental(analysis), false);
});
test('toFullSong：兼容旧工坊格式；节拍/歌词/段落/onset 原样；包络重采样对齐引擎索引', { skip: skipPdoom }, () => {
  const analysis = fromPdoom({ dataDir: pdoomData, audioPath: pdoomAudio, title: "I'm Upping My P(doom) (Claude-Pop)" });
  const song = toFullSong(analysis);
  assert.equal(song.song, "I'm Upping My P(doom) (Claude-Pop)");
  assert.equal(song.bpm, analysis.rhythm.bpm);
  assert.equal(song.envFps, 30);
  assert.deepEqual(song.beats, analysis.rhythm.beats);
  assert.deepEqual(song.downbeats, analysis.rhythm.downbeats);
  assert.deepEqual(song.kick, analysis.onsets.kick);
  assert.deepEqual(song.snare, analysis.onsets.snare);
  assert.deepEqual(song.sections, analysis.sections.map((s) => ({ name: s.name, start: s.start, end: s.end })));
  assert.equal(song.lines.length, analysis.lyrics.lines.length);
  for (const [index, line] of song.lines.entries()) {
    assert.equal(line.text, analysis.lyrics.lines[index].text);
    assert.deepEqual(Object.keys(line.words[0]), ['w', 'start', 'end'], '旧格式词不带 conf');
  }
  const frames = Math.floor(analysis.audio.duration * 30) + 1;
  assert.equal(song.rms.length, frames);
  const srcFps = analysis.envelopes.frameRate;
  const frame = Math.round(45.678 * 30);
  const frameTime = frame / 30;
  const x = frameTime * srcFps, i0 = Math.floor(x), frac = x - i0;
  const expected = analysis.envelopes.rms[i0] * (1 - frac) + analysis.envelopes.rms[i0 + 1] * frac;
  assert.ok(Math.abs(song.rms[frame] - expected) < 1e-9, '包络帧值与源数据按帧中心线性插值一致');
});
test('器乐分析可走完整链路且不伪造歌词', () => {
  const instrumental = validateAnalysis({
    schema: 'videograph-analysis/v2',
    audio: { hash: 'c'.repeat(64), duration: 8, sampleRate: 48000, channels: 2, decoderOffset: 0.023 },
    rhythm: { bpm: 100, beats: [0, 0.6, 1.2, 1.8, 2.4], downbeats: [0, 2.4], meter: 4, confidence: 0.7 },
    sections: [{ start: 0, end: 8, name: 'intro', confidence: 0.5 }],
    envelopes: { frameRate: 50, rms: [0, 0.2, 0.8, 0.2], low: [0, 0.1, 0.3, 0.1], mid: [0, 0.1, 0.2, 0.1], high: [0, 0.05, 0.1, 0.05] },
    onsets: { kick: [[0, 0.9]], snare: [[0.6, 0.6]], hat: [[0.3, 0.2]], vocal: [[0.1, 0.1]] },
    overrides: [],
    provenance: {
      audio: { tool: 'test-analyzer', version: '0.1', startedAt: 0, confidence: 0.7 },
      rhythm: { tool: 'test-analyzer', version: '0.1', startedAt: 0, confidence: 0.7 },
      sections: { tool: 'test-analyzer', version: '0.1', startedAt: 0, confidence: 0.5 },
      envelopes: { tool: 'test-analyzer', version: '0.1', startedAt: 0, confidence: 0.7 },
      onsets: { tool: 'test-analyzer', version: '0.1', startedAt: 0, confidence: 0.7 },
    },
  });
  assert.equal(isInstrumental(instrumental), true);
  const song = toFullSong(instrumental);
  assert.deepEqual(song.lines, [], '器乐工程不伪造歌词');
  assert.equal(song.vocal.length, Math.floor(8 * 30) + 1);
  assert.throws(() => toEngineLyrics(instrumental), /不伪造歌词/);
  const engineAudio = toEngineAudio(instrumental);
  assert.deepEqual(engineAudio.bass, engineAudio.rms.map(() => 0), '无分轨时 bass 补零');
  assert.equal(engineAudio.notes, '');
});
