// fromPdoom.mjs — 参考工程适配器：pdoom-video/data/*.json → videograph-analysis/v2（SONG-00）。
// 明确标记 reference-import：这是字节指纹命中的已提交分析，不是本次重新分析。
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ANALYSIS_SCHEMA, validateAnalysis } from '../contract.mjs';

export function fromPdoom({ dataDir, audioPath, title, language = 'en', sampleRate = 44100, channels = 2, startedAt = Date.now() }) {
  const audio = JSON.parse(readFileSync(join(dataDir, 'audio.json'), 'utf8'));
  const lyrics = JSON.parse(readFileSync(join(dataDir, 'lyrics.json'), 'utf8'));
  const audioHash = createHash('sha256').update(readFileSync(audioPath)).digest('hex');
  const engineNote = (text) => (typeof text === 'string' && text.trim() ? { engineNotes: text } : {});
  const source = (extra = {}) => ({
    tool: 'pdoom-video/analysis', version: 'reference-import', startedAt, confidence: 1, ...extra,
  });
  const note = audio.notes ?? '';
  return validateAnalysis({
    schema: ANALYSIS_SCHEMA,
    ...(title ? { title } : {}),
    audio: { hash: audioHash, duration: audio.duration, sampleRate, channels, decoderOffset: 0 },
    rhythm: { bpm: audio.bpm, beatPeriod: audio.beat_period, beats: audio.beats, downbeats: audio.downbeats, meter: audio.time_signature, confidence: 1 },
    sections: audio.sections.map((section) => ({ start: section.start, end: section.end, name: section.name })),
    envelopes: {
      frameRate: audio.fps, rms: audio.rms, low: audio.low, mid: audio.mid, high: audio.high,
      vocal: audio.vocal, drums: audio.drums, bass: audio.bass, other: audio.other,
    },
    onsets: audio.onsets,
    lyrics: {
      language, textSource: 'asr', humanConfirmed: true,
      lines: lyrics.lines.map(({ i, ...line }) => line),
      ...(Array.isArray(lyrics.extras) ? { extras: lyrics.extras } : {}),
    },
    overrides: [],
    provenance: {
      audio: source({ params: { referenceNote: '字节指纹命中参考工程已提交分析；非本次重新分析。', ...engineNote(note) } }),
      rhythm: source({ params: engineNote(note) }),
      sections: source(),
      envelopes: source({ params: engineNote(note) }),
      onsets: source({ params: engineNote(note) }),
      lyrics: source({ params: { humanVerified: true, ...engineNote(lyrics.notes ?? '') } }),
    },
  });
}
