// toEngine.mjs — v2 分析 → 参考引擎读取的 data/audio.json 与 data/lyrics.json（SONG-00）。
// 引擎要求恒定 BPM 与 8 路包络：缺 bass/other（无分轨）时补零；tempoMap 工程先经人工校正成恒定 BPM。
import { SongError } from '../contract.mjs';

const ENGINE_ENVELOPES = ['rms', 'low', 'mid', 'high', 'vocal', 'drums', 'bass', 'other'];

export function toEngineAudio(analysis) {
  const { rhythm, envelopes, onsets, audio } = analysis;
  if (rhythm.bpm === undefined) throw new SongError('参考引擎需要恒定 BPM；tempoMap 工程请先在人工校正里固定 BPM');
  const frames = envelopes.frames;
  return {
    duration: audio.duration,
    bpm: rhythm.bpm,
    beat_period: rhythm.beatPeriod ?? 60 / rhythm.bpm,
    time_signature: rhythm.meter,
    beats: rhythm.beats,
    downbeats: rhythm.downbeats,
    sections: analysis.sections.map((section) => ({ name: section.name, start: section.start, end: section.end })),
    fps: envelopes.frameRate,
    ...Object.fromEntries(ENGINE_ENVELOPES.map((key) => [key, envelopes[key] ?? new Array(frames).fill(0)])),
    onsets,
    notes: analysis.provenance.audio?.params?.engineNotes ?? '',
  };
}

export function toEngineLyrics(analysis) {
  if (!analysis.lyrics) throw new SongError('器乐工程没有歌词层；不伪造歌词');
  return {
    lines: analysis.lyrics.lines.map((line, index) => ({ i: index, ...line })),
    extras: analysis.lyrics.extras ?? [],
    notes: analysis.provenance.lyrics?.params?.engineNotes ?? '',
  };
}
