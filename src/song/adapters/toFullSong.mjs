// toFullSong.mjs — v2 分析 → 旧工坊 full-song.json 兼容格式（SONG-00）。
// 包络按引擎索引约定 Math.round(t*envFps) 以帧中心线性重采样；历史 full-song.json 来自早期管线，
// 格式兼容但包络数值不必与历史文件逐位一致（硬指标 ≤1e-6 只约束引擎数据往返，见 adapters 测试）。
import { SongError } from '../contract.mjs';

function resample(values, srcFps, duration, envFps) {
  const frames = Math.floor(duration * envFps) + 1;
  const out = new Array(frames);
  for (let i = 0; i < frames; i++) {
    const x = (i / envFps) * srcFps;
    const i0 = Math.min(Math.floor(x), values.length - 1);
    const i1 = Math.min(i0 + 1, values.length - 1);
    const frac = Math.min(Math.max(x - i0, 0), 1);
    out[i] = values[i0] + (values[i1] - values[i0]) * frac;
  }
  return out;
}

export function toFullSong(analysis, { envFps = 30, title } = {}) {
  const { rhythm, envelopes, onsets, audio } = analysis;
  if (rhythm.bpm === undefined) throw new SongError('旧工坊格式需要恒定 BPM；tempoMap 工程请先经人工校正');
  const srcFps = envelopes.frameRate;
  const channel = (key) => resample(envelopes[key] ?? envelopes.rms.map(() => 0), srcFps, audio.duration, envFps);
  return {
    song: title ?? analysis.title ?? 'Untitled',
    bpm: rhythm.bpm,
    duration: audio.duration,
    envFps,
    lines: analysis.lyrics?.lines.map(({ text, start, end, words }) => ({
      text, start, end,
      words: words.map(({ w, start: ws, end: we }) => ({ w, start: ws, end: we })),
    })) ?? [],
    sections: analysis.sections.map((section) => ({ name: section.name, start: section.start, end: section.end })),
    beats: rhythm.beats,
    downbeats: rhythm.downbeats,
    kick: onsets.kick,
    snare: onsets.snare,
    rms: channel('rms'),
    low: channel('low'),
    mid: channel('mid'),
    high: channel('high'),
    vocal: channel('vocal'),
    drums: channel('drums'),
  };
}
