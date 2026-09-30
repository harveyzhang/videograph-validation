// validation.ts — 生成代码的质量门：静态约束 → 编译 → 多时刻抽检。
// 抽检不等于逐帧验收；new Function 也不提供针对恶意代码的安全隔离。
import { compileShotScene, lintShotCode, makeShotCtx, renderStill } from './runtime';
import { FULL_SONG, type FullSongData, type ShotDraw, type ShotWindow } from './engine';

export const MAX_SHOT_REPAIRS = 2;

export type ShotValidationIssue = {
  stage: 'input' | 'lint' | 'compile' | 'render';
  message: string;
  t?: number;
};

export type ShotValidationReport = {
  attempt: number;
  samples: number;
  failures: Array<{ attempt: number; issue: ShotValidationIssue }>;
};

export type ShotValidationResult =
  | { ok: true; draw: ShotDraw; thumb: string; samples: number }
  | { ok: false; issue: ShotValidationIssue; samples: number };

const stageLabels = { input: '输入', lint: '静态约束', compile: '编译', render: '运行' };
export function describeShotIssue(issue: ShotValidationIssue): string {
  return `${stageLabels[issue.stage]}${issue.t === undefined ? '' : ` · t=${issue.t.toFixed(3)}s`}：${issue.message}`;
}

export function shotSampleTimes(window: ShotWindow): number[] {
  const duration = window.end - window.start;
  return [0, 0.25, 0.45, 0.75].map((p) => window.start + duration * p)
    .concat(window.end - Math.min(1 / 30, duration * 0.01));
}

export function validateShotScene(code: string, window: ShotWindow, song: FullSongData = FULL_SONG): ShotValidationResult {
  const fail = (stage: ShotValidationIssue['stage'], message: string, samples = 0, t?: number): ShotValidationResult =>
    ({ ok: false, issue: { stage, message: message.slice(0, 600), ...(t === undefined ? {} : { t }) }, samples });
  if (!code.trim()) return fail('input', '没有可用的场景代码，请返回完整 draw 函数');
  if (!Number.isFinite(window.start) || !Number.isFinite(window.end) || window.start < 0 || window.end <= window.start) {
    return fail('input', '镜头时间窗无效');
  }
  const lint = lintShotCode(code);
  if (lint.length) return fail('lint', lint.join('；'));
  let draw: ShotDraw;
  try { draw = compileShotScene(code); }
  catch (error) { return fail('compile', String(error)); }
  const ctx = makeShotCtx(window, song);
  const times = shotSampleTimes(window);
  let thumb = '';
  for (let i = 0; i < times.length; i++) {
    try {
      const still = renderStill(ctx, draw, times[i], 400, 225);
      if (still.error) return fail('render', still.error, i, times[i]);
      if (i === 2) thumb = still.dataUrl;
    } catch (error) { return fail('render', String(error), i, times[i]); }
  }
  return { ok: true, draw, thumb, samples: times.length };
}
