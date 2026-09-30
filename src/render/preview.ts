import * as THREE from 'three';
import { transform } from 'sucrase';
import type { TechStack } from '../types';

export interface FrameInput {
  frame: number;
  t: number;
  w: number;
  h: number;
  beat: number;
  rms: number;
  rand: (i: number) => number;
}

export interface PreviewResult {
  frames: number;
  seconds: number;
}

export interface PreviewTask {
  code: string;
  techStack: TechStack;
  seed: number;
}

type DrawFn = (ctx: CanvasRenderingContext2D, f: FrameInput) => void;

interface SceneInstance {
  render?: (f: { t: number; frame: number; beat: number; rms: number }) => void;
  object?: unknown;
  group?: unknown;
  camera?: unknown;
  mount?: (scene: THREE.Scene) => void;
  dispose?: () => void;
}

const FPS = 60;
const TOTAL_FRAMES = FPS * 3;

function mulberry32(seed: number) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const beatAt = (frame: number) => Math.max(0, 1 - (frame % 30) / 8) ** 2;
const rmsAt = (frame: number) => 0.4 + 0.22 * Math.sin(frame / 9) + 0.08 * Math.sin(frame / 3.1);

/** 用 sucrase 把 TS/ESM 代码转成 CJS JS，再在受限作用域内执行，返回 exports。 */
function compileModule(code: string): { exports: Record<string, unknown> } {
  const js = transform(code, { transforms: ['typescript', 'jsx', 'imports'] }).code;
  const moduleObj = { exports: {} as Record<string, unknown> };
  const requireShim = (name: string): unknown => {
    if (name === 'three') return THREE;
    throw new Error(`预览环境不支持导入 "${name}"`);
  };
  new Function('require', 'module', 'exports', js)(requireShim, moduleObj, moduleObj.exports);
  return moduleObj;
}

function compileCanvasDraw(code: string): DrawFn | null {
  const { exports } = compileModule(code);
  const draw = (exports.draw ?? (exports.default as { draw?: unknown } | undefined)?.draw) as DrawFn | undefined;
  return typeof draw === 'function' ? draw : null;
}

function compileThreeScene(code: string): (new (opts: { width: number; height: number; seed: number }) => SceneInstance) | null {
  const { exports } = compileModule(code);
  const Scene = (exports.default ?? exports.Scene) as
    | (new (opts: { width: number; height: number; seed: number }) => SceneInstance)
    | undefined;
  return typeof Scene === 'function' ? Scene : null;
}

/**
 * 在给定 canvas 上实时渲染 3 秒（180 帧 / 60fps）预览动画。
 * canvas-2d：直接调用生成的 draw()；three-webgl：实例化 Scene 类并驱动 Three 渲染循环。
 * shouldStop 返回 true 时提前结束（用于组件卸载时中止）。
 */
export async function runPreview(
  canvas: HTMLCanvasElement,
  task: PreviewTask,
  onFrame?: (frame: number) => void,
  shouldStop?: () => boolean,
): Promise<PreviewResult> {
  const w = 480;
  const h = 270;
  canvas.width = w;
  canvas.height = h;

  const frameInput = (frame: number): FrameInput => ({
    frame,
    t: frame / FPS,
    w,
    h,
    beat: beatAt(frame),
    rms: rmsAt(frame),
    rand: mulberry32(task.seed + frame * 7919),
  });

  const loop = async (step: (frame: number) => void): Promise<void> => {
    let frame = 0;
    await new Promise<void>((resolve) => {
      const tick = () => {
        if (shouldStop?.() || frame >= TOTAL_FRAMES) { resolve(); return; }
        step(frame);
        onFrame?.(frame);
        frame += 1;
        requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    });
  };

  if (task.techStack === 'canvas-2d') {
    const draw = compileCanvasDraw(task.code);
    if (!draw) throw new Error('代码中没有可调用的 draw() 导出');
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('无法获取 Canvas 2D 上下文');
    await loop((frame) => {
      try { draw(ctx, frameInput(frame)); } catch { /* 单帧异常不中断预览 */ }
    });
    return { frames: TOTAL_FRAMES, seconds: TOTAL_FRAMES / FPS };
  }

  if (task.techStack === 'three-webgl') {
    const SceneClass = compileThreeScene(task.code);
    if (!SceneClass) throw new Error('代码中没有导出 Scene 类');
    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    renderer.setSize(w, h, false);
    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#0b0d11');
    const camera = new THREE.PerspectiveCamera(50, w / h, 0.1, 200);
    camera.position.set(0, 0, 14);
    try {
      const instance = new SceneClass({ width: w, height: h, seed: task.seed });
      const root = instance.object ?? instance.group;
      if (root instanceof THREE.Object3D) scene.add(root);
      else if (typeof instance.mount === 'function') instance.mount(scene);
      const cam = instance.camera instanceof THREE.Camera ? instance.camera : camera;
      await loop((frame) => {
        try {
          instance.render?.({ t: frame / FPS, frame, beat: beatAt(frame), rms: rmsAt(frame) });
          renderer.render(scene, cam);
        } catch { /* 单帧异常不中断预览 */ }
      });
      instance.dispose?.();
    } finally {
      renderer.dispose();
    }
    return { frames: TOTAL_FRAMES, seconds: TOTAL_FRAMES / FPS };
  }

  throw new Error('Remotion / React 场景需要 Remotion 渲染器，浏览器预览暂不支持；请切换到 Three.js 或 Canvas 2D 技术栈');
}
