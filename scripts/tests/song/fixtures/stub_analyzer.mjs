// stub_analyzer.mjs — analyzer-runner 测试桩（node 直接运行）：读 spec.json，产出最小 v2 JSON 与进度行。
import { writeFileSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';

const specIndex = process.argv.indexOf('--spec');
const spec = JSON.parse(readFileSync(process.argv[specIndex + 1], 'utf8'));
const outDir = spec.outDir;
const emit = (line) => console.log(JSON.stringify(line));
emit({ stage: 't0', status: 'done', duration: 8.0 });
emit({ stage: 't1', status: 'done' });
let lyrics = null;
if (spec.lyricsText && spec.stages.includes('t3')) {
  emit({ stage: 't3', status: 'done', mode: 'align' });
  lyrics = {
    language: spec.language || 'zh', textSource: 'user', humanConfirmed: true,
    lines: spec.lyricsText.split('\n').filter(Boolean).map((line, index) => ({
      text: line, start: index * 1.0, end: index * 1.0 + 1.0,
      words: [{ w: line, start: index * 1.0, end: index * 1.0 + 1.0, conf: 0.9 }],
    })),
  };
}
const prov = (layer) => ({ tool: 'stub', version: 'stub-1', startedAt: 0, confidence: 0.5 });
const analysis = {
  schema: 'videograph-analysis/v2',
  title: spec.title || 'stub',
  audio: { hash: 'f'.repeat(64), duration: 8.0, sampleRate: 44100, channels: 2, decoderOffset: 0.0 },
  rhythm: { bpm: 120.0, beats: [0.0, 0.5, 1.0], downbeats: [0.0], meter: 4, confidence: 0.5 },
  sections: [{ start: 0.0, end: 8.0, label: 'unknown', name: 'stub', confidence: 0.4 }],
  envelopes: { frameRate: 100, frames: 3, rms: [0.0, 0.5, 1.0] },
  onsets: { kick: [[0.0, 1.0]], snare: [[0.5, 0.8]], hat: [[0.25, 0.4]], vocal: [[1.0, 0.5]] },
  overrides: [],
  provenance: Object.fromEntries(['audio', 'rhythm', 'sections', 'envelopes', 'onsets'].map((k) => [k, prov(k)])),
};
if (lyrics) {
  analysis.lyrics = lyrics;
  analysis.provenance.lyrics = prov('lyrics');
}
writeFileSync(join(outDir, 'analysis-v2.json'), JSON.stringify(analysis), 'utf8');
emit({ stage: 'all', status: 'done', file: join(outDir, 'analysis-v2.json') });
