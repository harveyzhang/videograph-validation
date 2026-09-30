// runtime.ts — 场景代码的沙箱编译、静帧渲染、实时播放与片段导出。
// 一切渲染调用都绑定一个 ShotCtx（全曲数据 + 镜头窗口），同一 ctx+t → 同一帧。
import { transform } from 'sucrase';
import { FULL_SONG, makeApi, makeFrame, type FullSongData, type ShotApi, type ShotDraw, type ShotWindow } from './engine';

export interface ShotCtx {
  song: FullSongData;
  window: ShotWindow;
  api: ShotApi;
}

export function makeShotCtx(window: ShotWindow, song: FullSongData = FULL_SONG): ShotCtx {
  return { song, window, api: makeApi(song, window) };
}

/** 转译并加载可信场景代码；require 被限制，但 new Function 不是安全沙箱。 */
export function compileShotScene(code: string): ShotDraw {
  const js = transform(code, { transforms: ['typescript', 'imports'] }).code;
  const moduleObj = { exports: {} as Record<string, unknown> };
  const requireShim = (name: string): unknown => {
    throw new Error(`镜头场景不允许导入 "${name}"（只允许 Canvas 2D + 传入的 api）`);
  };
  try {
    new Function('require', 'module', 'exports', js)(requireShim, moduleObj, moduleObj.exports);
  } catch (error) {
    throw new Error(`场景代码执行失败：${String(error).slice(0, 200)}`);
  }
  const draw = (moduleObj.exports.draw ?? moduleObj.exports.default) as unknown;
  if (typeof draw !== 'function') {
    throw new Error('场景代码没有导出 draw(ctx, f, api) 函数');
  }
  return draw as ShotDraw;
}

/** 统一逐帧入口：清空 Canvas 状态，避免 transform/clip/save 栈污染后续帧。 */
export function drawShotFrame(ctx: ShotCtx, draw: ShotDraw, canvas: HTMLCanvasElement, t: number): void {
  const c2d = canvas.getContext('2d');
  if (!c2d) throw new Error('无法创建 Canvas 2D 上下文');
  if (typeof c2d.reset === 'function') c2d.reset();
  else canvas.width = canvas.width;
  c2d.fillStyle = '#0A0A0B';
  c2d.fillRect(0, 0, canvas.width, canvas.height);
  draw(c2d, makeFrame(ctx.song, ctx.window, t, canvas.width, canvas.height), ctx.api);
}

/** 渲染一帧静帧，返回 dataURL（用作卡片缩略图 / 静帧条）。 */
export function renderStill(ctx: ShotCtx, draw: ShotDraw, t: number, W = 960, H = 540): { dataUrl: string; error?: string } {
  const canvas = document.createElement('canvas');
  canvas.width = W;
  canvas.height = H;
  let error: string | undefined;
  try {
    drawShotFrame(ctx, draw, canvas, t);
  } catch (err) {
    error = String(err).slice(0, 240);
  }
  return { dataUrl: canvas.toDataURL('image/png'), error };
}

export interface PlayerCallbacks {
  onEnd?: () => void;
  onFrameError?: (message: string) => void;
}

const mediaSources = new WeakMap<HTMLAudioElement, MediaStreamAudioDestinationNode>();

function audioTap(audio: HTMLAudioElement): MediaStreamAudioDestinationNode | null {
  try {
    const existing = mediaSources.get(audio);
    if (existing) return existing;
    const Ctx = window.AudioContext;
    if (!Ctx) return null;
    const actx = new Ctx();
    const source = actx.createMediaElementSource(audio);
    const dest = actx.createMediaStreamDestination();
    source.connect(actx.destination);
    source.connect(dest);
    mediaSources.set(audio, dest);
    return dest;
  } catch {
    return null;
  }
}

/** 实时播放镜头窗口。有音频时以 audio.currentTime 为时基，否则用本地时钟。 */
export class ShotPlayer {
  private raf = 0;
  private audio: HTMLAudioElement | null = null;
  playing = false;

  constructor(
    private canvas: HTMLCanvasElement,
    private ctx: ShotCtx,
    private draw: ShotDraw,
    private callbacks: PlayerCallbacks = {},
  ) {}

  private renderAt(t: number) {
    try {
      drawShotFrame(this.ctx, this.draw, this.canvas, t);
    } catch (error) {
      this.stop();
      this.callbacks.onFrameError?.(String(error).slice(0, 240));
    }
  }

  play(withAudio: boolean, loop = false) {
    this.stop();
    this.playing = true;
    const { window: w } = this.ctx;
    if (withAudio && !this.audio) {
      const el = new Audio('/audio/pdoom.mp3');
      el.preload = 'auto';
      this.audio = el;
    }
    const audio = this.audio as HTMLAudioElement | null;
    if (audio) audio.muted = !withAudio;

    let startWall = performance.now();
    const seekToStart = () => {
      if (!audio) return;
      const seek = () => { audio.currentTime = w.start; };
      if (audio.readyState >= 1) seek();
      else audio.addEventListener('loadedmetadata', seek, { once: true });
    };

    const tick = () => {
      if (!this.playing) return;
      // 音频已就绪并成功定位到窗口起点时以它为时基，否则退化为本地时钟（画面仍正确）。
      const audioReady = audio && withAudio && !audio.paused && audio.readyState >= 1 && audio.currentTime >= w.start - 0.6;
      const t = audioReady ? audio.currentTime : w.start + (performance.now() - startWall) / 1000;
      if (t >= w.end) {
        if (loop) {
          startWall = performance.now();
          if (audio) {
            seekToStart();
            if (audio.paused) void audio.play().catch(() => { /* 忽略 */ });
          }
        } else {
          this.stop();
          this.callbacks.onEnd?.();
          return;
        }
      } else {
        this.renderAt(Math.min(t, w.end));
      }
      if (this.playing) this.raf = requestAnimationFrame(tick);
    };

    if (audio && withAudio) {
      seekToStart();
      void audio.play().catch(() => { /* 自动播放被拒：退化为无声/时钟播放 */ });
    }
    this.raf = requestAnimationFrame(tick);
  }

  /** 暂停在某个时间点（拖动进度条时用）。 */
  scrub(t: number) {
    const clamped = Math.max(this.ctx.window.start, Math.min(this.ctx.window.end, t));
    if (this.audio) this.audio.currentTime = clamped;
    this.renderAt(clamped);
  }

  stop() {
    this.playing = false;
    cancelAnimationFrame(this.raf);
    if (this.audio && !this.audio.paused) this.audio.pause();
  }

  dispose() {
    this.stop();
    if (this.audio) {
      this.audio.removeAttribute('src');
      this.audio.load();
      this.audio = null;
    }
  }
}

export interface ClipResult {
  blob: Blob;
  seconds: number;
}

/**
 * 「单段渲染」：实时重放窗口并用 MediaRecorder 录成 WebM（VP9/VP8 + Opus）。
 * 这是浏览器内的最小可行片段导出；离线工程化版本走 headless Chrome + ffmpeg。
 */
export async function exportShotClip(
  ctx: ShotCtx,
  draw: ShotDraw,
  opts: { width?: number; withAudio?: boolean; onProgress?: (p: number) => void } = {},
): Promise<ClipResult> {
  const width = opts.width ?? 1280;
  const height = Math.round((width * 9) / 16);
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const c2d = canvas.getContext('2d');
  if (!c2d) throw new Error('无法创建 Canvas 2D 上下文');
  const w = ctx.window;

  const stream = canvas.captureStream(30);
  let audioEl: HTMLAudioElement | null = null;
  if (opts.withAudio) {
    audioEl = new Audio('/audio/pdoom.mp3');
    audioEl.preload = 'auto';
    const dest = audioTap(audioEl);
    if (dest) for (const track of dest.stream.getAudioTracks()) stream.addTrack(track);
  }

  const mime = ['video/webm;codecs=vp9,opus', 'video/webm;codecs=vp8,opus', 'video/webm']
    .find((m) => typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported(m));
  if (!mime) throw new Error('此浏览器不支持 MediaRecorder（WebM）导出');
  const recorder = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: 8_000_000 });
  const chunks: Blob[] = [];
  recorder.ondataavailable = (event) => { if (event.data.size > 0) chunks.push(event.data); };

  const done = new Promise<Blob>((resolve) => {
    recorder.onstop = () => resolve(new Blob(chunks, { type: 'video/webm' }));
  });

  recorder.start(200);
  if (audioEl) {
    audioEl.currentTime = w.start;
    void audioEl.play().catch(() => { /* 忽略自动播放失败 */ });
  }
  const startWall = performance.now();

  let frameError: unknown;
  await new Promise<void>((resolve) => {
    const tick = () => {
      const t = audioEl && !audioEl.paused && audioEl.currentTime >= w.start - 0.1
        ? audioEl.currentTime
        : w.start + (performance.now() - startWall) / 1000;
      if (t >= w.end) { resolve(); return; }
      try {
        drawShotFrame(ctx, draw, canvas, t);
      } catch (error) { frameError = error; resolve(); return; }
      opts.onProgress?.((t - w.start) / Math.max(0.001, w.end - w.start));
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });

  audioEl?.pause();
  recorder.stop();
  const blob = await done;
  stream.getTracks().forEach((track) => track.stop());
  if (frameError) throw new Error(`导出已中止，场景运行失败：${String(frameError)}`);
  return { blob, seconds: w.end - w.start };
}

/** 粗查一段代码里是否用了被禁止的非确定性来源（静态 lint，不执行代码）。 */
export function lintShotCode(code: string): string[] {
  const problems: string[] = [];
  if (/\bMath\.random\b/.test(code)) problems.push('使用了 Math.random() —— 请改用 api.rng(seed)');
  if (/\bDate\.now\b/.test(code)) problems.push('使用了 Date.now() —— 场景必须是 t 的纯函数');
  if (/\bperformance\.now\b/.test(code)) problems.push('使用了 performance.now() —— 请使用 f.lt / f.p');
  if (/\bfetch\s*\(|\bimport\s*\(/.test(code)) problems.push('场景代码不允许网络请求或动态导入');
  if (/import\s+[^;]+\s+from/.test(code)) problems.push('场景代码不允许导入外部模块');
  return problems;
}
