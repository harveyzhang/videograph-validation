import { ProjectError } from './errors.mjs';

export function trackDirectorCommit(project, target, kind, attemptToken, author = 'human') {
  // 已有导演方案的工程：AI 写镜头/转场必须走 claim → attemptToken，否则修复预算可被旧路径绕过。人在界面的编辑不受限。
  if (!attemptToken) {
    if (project.director && author === 'mcp') throw new ProjectError('该工程已有导演方案：AI 写入镜头/转场必须带 project_director_claim 返回的 attemptToken；修复预算用尽时停下等人决定，不能走无 token 的旧路径', 409);
    return null;
  }
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
