// engine.ts — engine-mini 契约（借鉴 pdoom-video：每帧是歌曲时间 t 的确定性函数）。
// 数据集 = 全曲分析（full-song.json）+ 一个镜头窗口；同一 t 永远得到同一帧。
import fullSong from './full-song.json';

export type LyricWord = { w: string; start: number; end: number };
export type LyricLine = { text: string; start: number; end: number; words: LyricWord[] };

/** 逐帧传给场景的输入。所有时间都是全曲时间（秒），lt/p 是镜头内局部量。 */
export interface ShotFrame {
  t: number;
  lt: number;
  p: number;
  W: number;
  H: number;
  audio: {
    rms: number;
    low: number;
    mid: number;
    high: number;
    vocal: number;
    drums: number;
    beat: number;
    downbeat: number;
    beatPhase: number;
  };
  lyric: { lines: LyricLine[] };
}

export interface ShotApi {
  palette: Record<'ink' | 'ink2' | 'graphite' | 'ash' | 'bone' | 'signal' | 'ember' | 'blood' | 'acid', string>;
  ease: {
    outExpo: (x: number) => number;
    inOutCubic: (x: number) => number;
    inOutQuad: (x: number) => number;
    outBack: (x: number) => number;
  };
  rng: (seed: number) => () => number;
  clamp: (x: number, a?: number, b?: number) => number;
  lerp: (a: number, b: number, x: number) => number;
  /** 词的已唱进度 0..1（卡拉OK上色的唯一正解，不要自己算时间）。 */
  wordProgress: (word: LyricWord, t: number) => number;
  /** 整行已唱字符数（含小数），用于逐字符擦除效果。 */
  lineCharProgress: (line: LyricLine, t: number) => number;
  /** 事件脉冲：t 之前最近一次事件后按半衰期衰减，1 → 0。 */
  pulse: (t: number, events: number[], halfLife?: number) => number;
  beatEvents: number[];
  downbeatEvents: number[];
  kickEvents: number[];
  snareEvents: number[];
}

/** 场景模块的唯一合法导出：画一帧。 */
export type ShotDraw = (ctx: CanvasRenderingContext2D, f: ShotFrame, api: ShotApi) => void;

export const SHOT_PALETTE = {
  ink: '#0A0A0B',
  ink2: '#151517',
  graphite: '#5E5B57',
  ash: '#9C978F',
  bone: '#EEE9DF',
  signal: '#FF4D12',
  ember: '#FF8A3D',
  blood: '#C21D0B',
  acid: '#D8FF3C',
} as const;

export interface SongSection { name: string; start: number; end: number }

export interface FullSongData {
  song: string;
  bpm: number;
  duration: number;
  envFps: number;
  lines: LyricLine[];
  sections: SongSection[];
  beats: number[];
  downbeats: number[];
  kick: [number, number][];
  snare: [number, number][];
  rms: number[];
  low: number[];
  mid: number[];
  high: number[];
  vocal: number[];
  drums: number[];
}

export const FULL_SONG = fullSong as unknown as FullSongData;

export interface ShotWindow { start: number; end: number }

export const windowDuration = (w: ShotWindow) => w.end - w.start;

function envAt(arr: number[], song: FullSongData, t: number): number {
  const i = Math.round(t * song.envFps);
  return arr[Math.max(0, Math.min(arr.length - 1, i))] ?? 0;
}

function pulseAt(t: number, events: number[], halfLife: number): number {
  let last = -Infinity;
  for (const e of events) {
    if (e <= t) last = e;
    else break;
  }
  if (last === -Infinity) return 0;
  return Math.exp(-(t - last) / halfLife);
}

export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const clamp01 = (x: number) => (x < 0 ? 0 : x > 1 ? 1 : x);

export function wordProgress(word: LyricWord, t: number): number {
  return clamp01((t - word.start) / Math.max(0.001, word.end - word.start));
}

export function lineCharProgress(line: LyricLine, t: number): number {
  let chars = 0;
  for (const w of line.words) chars += wordProgress(w, t) * w.w.length;
  return chars;
}

/** 窗口内的歌词行（按时间序）。 */
export function linesInWindow(song: FullSongData, w: ShotWindow): LyricLine[] {
  return song.lines.filter((l) => l.end > w.start - 0.15 && l.start < w.end + 0.15);
}

/** 构造一帧（确定性）。 */
export function makeFrame(song: FullSongData, w: ShotWindow, t: number, W: number, H: number): ShotFrame {
  const period = 60 / song.bpm;
  const firstBeat = song.beats[0] ?? 0.238;
  return {
    t,
    lt: t - w.start,
    p: clamp01((t - w.start) / Math.max(0.001, w.end - w.start)),
    W,
    H,
    audio: {
      rms: envAt(song.rms, song, t),
      low: envAt(song.low, song, t),
      mid: envAt(song.mid, song, t),
      high: envAt(song.high, song, t),
      vocal: envAt(song.vocal, song, t),
      drums: envAt(song.drums, song, t),
      beat: pulseAt(t, song.beats, 0.14),
      downbeat: pulseAt(t, song.downbeats, 0.22),
      beatPhase: (((t - firstBeat) / period) % 1 + 1) % 1,
    },
    lyric: { lines: linesInWindow(song, w) },
  };
}

const EASE = {
  outExpo: (x: number) => (x >= 1 ? 1 : 1 - Math.pow(2, -10 * x)),
  inOutCubic: (x: number) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2),
  inOutQuad: (x: number) => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2),
  outBack: (x: number) => 1 + 2.70158 * Math.pow(x - 1, 3) + 1.70158 * Math.pow(x - 1, 2),
};

export function makeApi(song: FullSongData, w: ShotWindow): ShotApi {
  return {
    palette: SHOT_PALETTE,
    ease: EASE,
    rng: mulberry32,
    clamp: (x, a = 0, b = 1) => Math.max(a, Math.min(b, x)),
    lerp: (a, b, x) => a + (b - a) * x,
    wordProgress,
    lineCharProgress,
    pulse: (t, events, halfLife = 0.14) => pulseAt(t, events, halfLife),
    beatEvents: song.beats.filter((b) => b >= w.start - 0.5 && b <= w.end + 0.5),
    downbeatEvents: song.downbeats.filter((d) => d >= w.start - 0.5 && d <= w.end + 0.5),
    kickEvents: song.kick.filter((k) => k[0] >= w.start - 0.5 && k[0] <= w.end + 0.5).map((k) => k[0]),
    snareEvents: song.snare.filter((s) => s[0] >= w.start - 0.5 && s[0] <= w.end + 0.5).map((s) => s[0]),
  };
}

// ── pdoom timeline 的切点逻辑（cut/after），供规划器复用 ──────────────────────

export function findLine(song: FullSongData, query: string, nth = 0): LyricLine | undefined {
  const norm = (s: string) => s.toLowerCase().replace(/[’']/g, "'");
  const hits = song.lines.filter((l) => norm(l.text).includes(norm(query)));
  return hits[nth];
}

/** 复刻 pdoom 的 cut()：锚定行首词，吸附到它之前（含 20ms 容差）最近的 beat。 */
export function cutAtLine(song: FullSongData, query: string, nth = 0): number {
  const line = findLine(song, query, nth);
  if (!line) return 0;
  const s = line.words[0]!.start + 0.02;
  let last = song.beats[0] ?? 0.238;
  for (const b of song.beats) {
    if (b <= s) last = b;
    else break;
  }
  return last;
}

/** 复刻 pdoom 的 after()：行结束后最近的 downbeat。 */
export function afterLine(song: FullSongData, query: string, nth = 0): number {
  const line = findLine(song, query, nth);
  if (!line) return song.duration;
  return song.downbeats.reduce((b, d) => (Math.abs(d - line.end) < Math.abs(b - line.end) ? d : b), song.downbeats[0] ?? line.end);
}

export function sectionStart(song: FullSongData, name: string): number {
  return song.sections.find((s) => s.name === name)?.start ?? 0;
}
