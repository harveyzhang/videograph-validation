// transitions.mjs — 以切点后的短区间做过渡，不改变总时长、不提前显示下一句歌词。
import { createHash } from 'node:crypto';
import { ProjectError } from './errors.mjs';
import { prepareTransitionEffect } from './fx/apply.mjs';
// effect：特效箱里的转场动效（gl-transitions 等），代码与参数冻结在 transition.effect。
export const transitionModes = ['cut', 'dissolve', 'wipe', 'dip', 'effect'];
export function defaultTransitions(shots) {
  return shots.slice(1).map((right, index) => {
    const left = shots[index];
    const id = 'tr-' + createHash('sha256').update(`${left.id}|${right.id}`).digest('hex').slice(0, 16);
    return { id, fromShotId: left.id, toShotId: right.id, intent: '保留节拍上的硬切；如需过渡请单独指导此节点。', mode: 'cut', duration: 0,
      easing: 'smooth', direction: 'left', inputRevision: 0, inputToken: `${id}:0`, status: 'ready', locked: false, feedback: [] };
  });
}
export function normalizeProject(project) {
  project.transitions ??= defaultTransitions(project.shots);
  for (const transition of project.transitions) {
    if (!transition.validation) continue;
    const left = project.shots.find((shot) => shot.id === transition.fromShotId);
    const right = project.shots.find((shot) => shot.id === transition.toShotId);
    if (transition.validation.inputToken !== transition.inputToken || transition.validation.leftInputToken !== left?.inputToken || transition.validation.rightInputToken !== right?.inputToken) {
      delete transition.validation;
      if (transition.status === 'ready') transition.status = 'needs-validation';
    }
  }
  return project;
}
export function transitionPair(project, transition) {
  const index = project.shots.findIndex((shot) => shot.id === transition.toShotId);
  const right = project.shots[index], left = project.shots[index - 1];
  if (!right || !left || left.id !== transition.fromShotId) throw new ProjectError('转场必须连接两个相邻镜头');
  if (Math.abs(left.end - right.start) > 0.002) throw new ProjectError('首版转场要求相邻镜头共享同一切点');
  return { left, right };
}
/** frozenEffect：渲染路径复核已冻结的转场时传入，跳过重新查找特效箱（冻结后不受特效箱更新影响）。 */
export function validateTransitionConfig(project, transition, config, { frozenEffect } = {}) {
  const { right } = transitionPair(project, transition);
  if (!config || typeof config !== 'object' || Array.isArray(config) || Object.keys(config).some((key) => !['mode', 'duration', 'easing', 'direction', 'effectId', 'params'].includes(key))) throw new ProjectError('unsupported transition config');
  const mode = config.mode ?? transition.mode;
  if (!transitionModes.includes(mode)) throw new ProjectError('转场类型仅支持 cut/dissolve/wipe/dip/effect');
  if (mode !== 'effect' && (config.effectId !== undefined || config.params !== undefined)) throw new ProjectError('effectId/params 只用于 mode=effect');
  const effect = mode !== 'effect' ? null : frozenEffect ?? prepareTransitionEffect(config.effectId ?? transition.effect?.id, config.params ?? (config.effectId ? undefined : transition.effect?.params));
  const maxDuration = Math.min(1.5, (right.end - right.start) / 2);
  const duration = mode === 'cut' ? 0 : config.duration ?? (transition.duration > 0 ? transition.duration : Math.min(.25, maxDuration));
  if (!Number.isFinite(duration) || duration < 0 || (mode !== 'cut' && (duration < 1 / (project.output?.fps ?? 30) || duration > maxDuration))) throw new ProjectError(`转场时长必须在一帧到 ${maxDuration.toFixed(3)} 秒之间`);
  if (mode === 'cut' && config.duration !== undefined && config.duration !== 0) throw new ProjectError('硬切的 duration 必须为 0');
  const easing = config.easing ?? transition.easing ?? 'smooth';
  const direction = config.direction ?? transition.direction ?? 'left';
  if (!['linear', 'smooth'].includes(easing) || !['left', 'right'].includes(direction)) throw new ProjectError('invalid transition easing/direction');
  return { mode, duration, easing, direction, ...(effect ? { effect } : {}) };
}
export function transitionWindow(project, transition, fps = project.output?.fps ?? 30) {
  const { left, right } = transitionPair(project, transition);
  const startFrame = Math.round(right.start * fps);
  const frames = transition.mode === 'cut' ? 0 : Math.max(1, Math.round(transition.duration * fps));
  const nextEnd = Math.round(right.end * fps);
  if (frames && startFrame + frames >= nextEnd) throw new ProjectError('转场量化后超出目标镜头');
  return { start: startFrame / fps, end: (startFrame + frames) / fps, frames,
    holdTime: Math.max(left.start, startFrame / fps - 1 / fps) };
}
export function renderShotsWithTransitions(shots, transitions = [], fps = 30) {
  const aligned = shots.map((shot) => ({ ...shot, start: Math.round(shot.start * fps) / fps, end: Math.round(shot.end * fps) / fps }));
  const project = { shots: aligned, output: { fps } };
  const rendered = aligned.map((shot) => ({ ...shot, logicalStart: shot.start, logicalEnd: shot.end }));
  for (const transition of transitions) {
    if (transition.mode === 'cut') continue;
    const { effect: frozenEffect, ...base } = transitionConfig(transition);
    if (base.mode === 'effect' && !frozenEffect) throw new ProjectError(`${transition.id} 的转场动效缺少冻结代码`);
    validateTransitionConfig(project, transition, base, { frozenEffect });
    const window = transitionWindow(project, transition, fps);
    const left = rendered.find((shot) => shot.id === transition.fromShotId);
    const right = rendered.find((shot) => shot.id === transition.toShotId);
    left.end = window.end;
    right.incomingTransition = { ...transitionConfig(transition), duration: window.end - window.start };
  }
  return rendered;
}
export const transitionConfig = ({ mode, duration, easing, direction, effect }) => ({ mode, duration, easing, direction, ...(mode === 'effect' && effect ? { effect } : {}) });
