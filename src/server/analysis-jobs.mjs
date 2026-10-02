// analysis-jobs.mjs — SONG-05：新歌工程的后台分析。轮询 analysis-pending 工程，调用 SONG-01 分析器，结果经契约校验后写回工程。
// 与渲染队列分离（分析走 Python 子进程，不占渲染宿主）；同一时间只跑一个分析，服务重启后从 analysis-pending 状态自然恢复。
import { randomUUID } from 'node:crypto';
import { listProjects, saveJob } from './project-store.mjs';
import { analysisInput, completeAnalysis, failAnalysis } from './song-project.mjs';
import { runAnalysis } from '../song/analyzer-runner.mjs';

let busy = false;

/** 启动后台轮询器（5 秒一次）；返回停止函数。 */
export function startAnalysisWorker({ interval = 5000, run = runAnalysis } = {}) {
  const tick = () => { if (!busy) void next(run); };
  const timer = setInterval(tick, interval);
  tick();
  return () => clearInterval(timer);
}

async function next(run) {
  const pending = listProjects().filter((project) => project.status === 'analysis-pending').at(-1); // 最早创建的先跑
  if (!pending) return;
  busy = true;
  try { await analyzeProject(pending.id, run); }
  finally { busy = false; }
}

export async function analyzeProject(projectId, run = runAnalysis) {
  const job = { id: randomUUID(), projectId, kind: 'analysis', status: 'running', progress: 0, detail: '音频分析', createdAt: Date.now() };
  saveJob(projectId, job);
  try {
    const input = analysisInput(projectId);
    const result = await run({ ...input, onProgress: (line) => {
      job.detail = `分析 ${line.stage ?? ''}`.trim();
      saveJob(projectId, job);
    } });
    completeAnalysis(projectId, result.analysis, { cached: result.cached });
    Object.assign(job, { status: 'done', progress: 1, detail: result.cached ? '复用分析缓存' : '分析完成', finishedAt: Date.now(), result: { cached: result.cached, key: result.key } });
  } catch (error) {
    const message = String(error?.message ?? error).slice(0, 4000);
    try { failAnalysis(projectId, message); } catch { /* 工程被删除等情况：只记任务失败 */ }
    Object.assign(job, { status: 'error', error: message, finishedAt: Date.now() });
    console.error(`[分析] 工程 ${projectId} 失败：${message}`);
  }
  saveJob(projectId, job);
  return job;
}
