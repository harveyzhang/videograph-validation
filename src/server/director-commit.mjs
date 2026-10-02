import { ProjectError } from './errors.mjs';

export function trackDirectorCommit(project, target, kind, attemptToken) {
  if (!attemptToken) return null;
  const op = Object.values(project.director?.operations ?? {}).find((entry) => entry.attemptToken === attemptToken);
  if (!op || op.status !== 'claimed' || op.leaseExpiresAt <= Date.now() || op.directorVersion !== project.director.version) throw new ProjectError('导演操作租约过期或不存在', 409);
  if (op.targetId !== target.id || op.targetKind !== kind || !['generate', 'transition'].includes(op.kind)) throw new ProjectError('操作目标不匹配', 409);
  if (op.targetToken !== target.inputToken && op.cursorToken !== target.inputToken && op.receipt?.inputToken !== target.inputToken) throw new ProjectError('操作基线已被其他编辑改变', 409);
  return op;
}
export function receiptDirectorCommit(project, target, kind, op) {
  if (!op) return;
  op.receipt = { inputToken: target.inputToken, codeHash: target.codeHash, inputRevision: target.inputRevision };
  delete op.cursorToken;
  if (kind === 'shot') project.director.appliedShots[target.id] = project.director.version;
  else project.director.appliedTransitions[target.id] = project.director.version;
}
