// index.mjs — 本地工程服务：UI/MCP 共用命令，后台任务不依赖浏览器生命周期。
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { createReadStream, existsSync, mkdirSync, statSync, writeFileSync, unlinkSync } from 'node:fs';
import { join, extname, resolve, dirname } from 'node:path';
import { createProjectFromAudio, listProjects, readProject, updateShot, addShotFeedback, acceptShotFeedback, rejectShotFeedback, readShotSource, readShotLyricContext, submitShotSource, updateTransition, configureTransition, askFeedback, replyFeedback, feedbackInbox, projectDir, projectsRoot, productRoot, saveJob, listJobs, readJob, ProjectError, safeId } from './project-store.mjs';
import { getSongAnalysis, confirmSongAnalysis, submitSongLyrics, submitPlan, retryAnalysis, patchSongAnalysis } from './song-project.mjs';
import { startReferenceServer } from './reference-server.mjs';
import { feedbackTargetWindow } from './feedback.mjs';
import { transitionPair, transitionWindow } from './transitions.mjs';
import { startAnalysisWorker } from './analysis-jobs.mjs';
import { cueSheet } from './rhythm.mjs';
import { getDirector, submitDirector, claimDirector, completeDirector, submitReview, acceptDirectorReview, dispatchDirector, assertDirectorExport } from './director.mjs';

const port = Number(process.env.VIDEOGRAPH_SERVICE_PORT ?? 5191);
const allowedOrigins = new Set((process.env.VIDEOGRAPH_STUDIO_ORIGINS ?? 'http://127.0.0.1:5188,http://localhost:5188').split(',').map((origin) => origin.trim()).filter(Boolean));
for (const origin of allowedOrigins) {
  const url = new URL(origin);
  if (url.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(url.hostname) || url.origin !== origin) throw new Error('Studio origins must be explicit local HTTP origins');
}
const serviceToken = randomUUID() + randomUUID();
const tokenPath = resolve(process.env.VIDEOGRAPH_SERVICE_TOKEN_FILE ?? join(productRoot, '.cache/service-token'));
const previews = new Map();
const queue = [];
let active = null;
let closing = false;

function pump() {
  if (active || closing || !queue.length) return;
  const entry = queue.shift();
  const child = spawn(process.execPath, [join(productRoot, 'src/server/render-worker.mjs'), entry.projectId, entry.jobId], {
    cwd: productRoot, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe', 'ipc'], env: process.env,
  });
  active = { ...entry, child };
  let log = '';
  child.stdout.on('data', (chunk) => { log = (log + chunk).slice(-12000); });
  child.stderr.on('data', (chunk) => { log = (log + chunk).slice(-12000); });
  child.on('error', (error) => { log += String(error); });
  child.on('close', (code) => {
    const job = readJob(entry.projectId, entry.jobId);
    if (!['done', 'error', 'cancelled'].includes(job.status)) saveJob(entry.projectId, { ...job, status: 'error', error: `渲染进程退出 ${code}\n${log}`, finishedAt: Date.now() });
    active = null;
    pump();
  });
}
// AE-02/03/04：只读的画面/节奏分析任务。参数在入队时校验并展开为确定的时间点，渲染进程只执行。
const AE_KINDS = ['filmstrip', 'contact-sheet', 'rhythm'];
function aeRange(project, options) {
  const duration = project.song?.duration ?? Math.max(...project.shots.map((shot) => shot.end));
  if (options.shotId) {
    const shot = project.shots.find((entry) => entry.id === options.shotId);
    if (!shot) throw new ProjectError('shot not found', 404);
    return { start: shot.start, end: shot.end, label: `镜头 ${shot.id}`, shots: [shot] };
  }
  if (options.transitionId) {
    const transition = project.transitions.find((entry) => entry.id === options.transitionId);
    if (!transition) throw new ProjectError('transition not found', 404);
    const { left, right } = transitionPair(project, transition);
    const window = transitionWindow(project, transition);
    const start = Math.max(left.start, window.start - 1), end = Math.min(right.end, window.end + 1);
    return { start, end, label: `转场 ${transition.id}`, shots: [left, right] };
  }
  const start = Math.max(0, options.start ?? 0), end = Math.min(duration, options.end ?? duration);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end - start < 0.05) throw new ProjectError('start/end 必须构成有效时间段');
  return { start, end, label: options.start === undefined && options.end === undefined ? '全片' : `${start.toFixed(2)}–${end.toFixed(2)}s`,
    shots: project.shots.filter((shot) => shot.end > start && shot.start < end) };
}
function aeInput(project, kind, options) {
  const fps = project.output.fps;
  const intIn = (value, fallback, min, max, name) => {
    const result = value ?? fallback;
    if (!Number.isInteger(result) || result < min || result > max) throw new ProjectError(`${name} 必须是 ${min}..${max} 的整数`);
    return result;
  };
  if (kind === 'contact-sheet') {
    const ratios = options.ratios ?? [0.45];
    if (!Array.isArray(ratios) || !ratios.length || ratios.length > 3 || !ratios.every((ratio) => Number.isFinite(ratio) && ratio >= 0 && ratio <= 1)) throw new ProjectError('ratios 必须是 1–3 个 0..1 的数');
    return { ratios, thumbWidth: intIn(options.thumbWidth, project.shots.length * ratios.length > 24 ? 240 : 320, 160, 480, 'thumbWidth'),
      columns: intIn(options.columns, ratios.length > 1 ? ratios.length * 2 : 6, 1, 12, 'columns') };
  }
  const range = aeRange(project, options);
  const missing = range.shots.filter((shot) => !shot.module).map((shot) => shot.id);
  if (missing.length) throw new ProjectError(`这些镜头还没有源码：${missing.join(', ')}；先 project_shot_submit`, 409);
  const frame = (t) => Math.round(t * fps) / fps;
  if (kind === 'filmstrip') {
    let times;
    if (options.around !== undefined) {
      if (!Number.isFinite(options.around) || options.around < range.start || options.around >= range.end) throw new ProjectError('around 必须落在目标时间段内');
      const half = intIn(options.frames, 5, 1, 11, 'frames');
      times = Array.from({ length: half * 2 + 1 }, (_, i) => frame(options.around) + (i - half) / fps);
    } else if (options.sampleFps !== undefined) {
      if (!Number.isFinite(options.sampleFps) || options.sampleFps <= 0 || options.sampleFps > fps) throw new ProjectError(`sampleFps 必须在 (0, ${fps}]`);
      times = [];
      for (let t = range.start; t < range.end - 1e-6; t += 1 / options.sampleFps) times.push(t);
    } else {
      const count = Math.min(24, Math.max(6, Math.round((range.end - range.start) * 4)));
      times = Array.from({ length: count }, (_, i) => range.start + (range.end - range.start) * i / count);
    }
    times = [...new Set(times.map(frame).filter((t) => t >= range.start - 1e-6 && t < range.end - 1e-6).map((t) => +t.toFixed(4)))];
    if (!times.length || times.length > 24) throw new ProjectError(`帧数 ${times.length} 超出 1..24：缩小时间段或降低 sampleFps`);
    return { times, label: options.around !== undefined ? `${range.label === '全片' ? '' : range.label + ' · '}around ${options.around}s` : range.label, thumbWidth: intIn(options.thumbWidth, 320, 160, 480, 'thumbWidth'), columns: intIn(options.columns, Math.min(6, times.length), 1, 12, 'columns') };
  }
  const sampleFps = intIn(options.sampleFps, range.end - range.start > 30 ? 15 : fps, 10, 60, 'sampleFps');
  if ((range.end - range.start) * sampleFps > 6000) throw new ProjectError('采样帧过多（>6000）：缩小时间段或降低 sampleFps');
  return { start: range.start, end: range.end, sampleFps, label: range.label };
}
function enqueue(projectId, kind, options) {
  const project = readProject(projectId);
  if (!['validate', 'validate-transition', 'export', 'stills', ...AE_KINDS].includes(kind)) throw new ProjectError('invalid job kind');
  if (kind === 'validate-transition' && !project.transitions.some((transition) => transition.id === options.transitionId)) throw new ProjectError('transition not found', 404);
  if (kind === 'validate' && !project.shots.some((shot) => shot.id === options.shotId)) throw new ProjectError('shot not found', 404);
  if (kind === 'export' && [...project.shots, ...project.transitions].some((target) => (target.feedback ?? []).some((note) => note.status !== 'accepted'))) throw new ProjectError('存在未接受的镜头或转场意见：请先配置/改写、校验并确认采用。', 409);
  if (['validate', 'export', 'stills', ...AE_KINDS].includes(kind) && project.status && project.status !== 'planned') throw new ProjectError(`工程还在 ${project.status} 阶段：先完成分析确认与镜头规划`, 409);
  if (kind === 'validate' && !project.shots.find((shot) => shot.id === options.shotId).module) throw new ProjectError('镜头还没有源码：先 project_shot_submit', 409);
  if (kind === 'export' && project.shots.some((shot) => !shot.module || shot.status === 'needs-generation')) throw new ProjectError('有镜头尚未生成源码（needs-generation）', 409);
  if (kind === 'export' && project.transitions.some((transition) => transition.status === 'needs-generation')) throw new ProjectError('有转场指导尚未落实为效果配置', 409);
  if (kind === 'export') assertDirectorExport(project);
  let stills = null;
  if (kind === 'stills') {
    const shotTarget = options.shotId ? project.shots.find((shot) => shot.id === options.shotId) : null;
    const transitionTarget = !shotTarget && options.transitionId ? project.transitions.find((transition) => transition.id === options.transitionId) : null;
    if (!shotTarget && !transitionTarget) throw new ProjectError('必须指定存在的 shotId 或 transitionId', 404);
    const targetKind = shotTarget ? 'shot' : 'transition';
    const target = shotTarget ?? transitionTarget;
    if (options.version === 'before-feedback' && !target.reviewBaseline) throw new ProjectError('没有可比较的修改前版本');
    const pair = targetKind === 'transition' ? transitionPair(project, target) : null;
    const window = feedbackTargetWindow(project, target, targetKind, pair);
    const fps0 = project.output?.fps ?? 30;
    const tolerance = 0.5 / fps0;
    const inWindow = (t) => Number.isFinite(t) && t >= window.start - tolerance && t <= window.end + tolerance;
    let times = options.times;
    if (times === undefined || times === null) {
      // 默认时间点：未接受意见的锚点 t，再加窗口的 0 / 0.5 / 1（终点回退一帧，避免停在窗口外）。
      const last = Math.max(window.start, window.end - 1 / fps0);
      const anchors = (target.feedback ?? []).filter((note) => note.status !== 'accepted' && inWindow(note.anchor?.t)).map((note) => Math.min(note.anchor.t, last));
      times = [...anchors, window.start, window.start + (window.end - window.start) * .5, last];
    }
    if (!Array.isArray(times) || !times.length || times.length > 6 || !times.every(inWindow)) throw new ProjectError('times 必须是落在目标时间窗内、最多 6 个的时间点');
    times = [...new Set(times.map((t) => Math.round(t * 1000) / 1000))];
    const width = options.width ?? 960;
    if (!Number.isInteger(width) || width < 320 || width > 1920) throw new ProjectError('width 必须是 320..1920 的整数像素');
    stills = { targetKind, targetId: target.id, times, version: options.version === 'before-feedback' ? 'before-feedback' : 'current', width };
  }
  const ae = AE_KINDS.includes(kind) ? aeInput(project, kind, options) : null;
  const fps = AE_KINDS.includes(kind) ? project.output.fps : options.fps ?? project.output.fps;
  const samples = AE_KINDS.includes(kind) ? 1 : options.samples ?? project.output.samples;
  if (![24, 30, 60].includes(fps) || ![1, 4, 12].includes(samples)) throw new ProjectError('fps supports 24/30/60; samples supports 1/4/12');
  const job = { id: randomUUID(), projectId, kind, status: 'queued', progress: 0, detail: '等待渲染进程', createdAt: Date.now(), input: { project, shotId: options.shotId, transitionId: options.transitionId, fps, samples, ...(stills ? { stills } : {}), ...(ae ? { ae } : {}) } };
  saveJob(projectId, job);
  queue.push({ projectId, jobId: job.id });
  pump();
  return publicJob(job);
}
function publicJob(job) {
  const { input, ...result } = job;
  if (!input) return result; // 分析任务没有渲染输入
  return { ...result, inputRevision: input.project.revision, shotId: input.shotId, transitionId: input.transitionId, fps: input.fps, samples: input.samples, ...(input.stills ? { stills: input.stills } : {}), ...(input.ae ? { ae: input.ae } : {}) };
}
// AE-06：GET 任务时可阻塞等待到结束（最多 50 秒，留余量给 MCP 客户端常见的 60 秒请求超时），减少 agent 轮询回合。
async function waitJob(projectId, jobId, seconds) {
  const deadline = Date.now() + Math.min(50, Math.max(0, seconds)) * 1000;
  let job = readJob(projectId, jobId);
  while (!['done', 'error', 'cancelled', 'interrupted'].includes(job.status) && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 250));
    job = readJob(projectId, jobId);
  }
  return job;
}
async function body(req, limit = 1000000) {
  const buffers = []; let size = 0;
  for await (const chunk of req) { size += chunk.length; if (size > limit) throw new ProjectError('request too large', 413); buffers.push(chunk); }
  const raw = Buffer.concat(buffers);
  try { return JSON.parse(raw.toString('utf8') || '{}'); } catch { throw new ProjectError('invalid JSON'); }
}
function json(res, data, status = 200) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
  res.end(JSON.stringify(data));
}
function fileResponse(req, res, path) {
  if (!existsSync(path)) throw new ProjectError('file not found', 404);
  const size = statSync(path).size;
  const type = { '.png': 'image/png', '.mp4': 'video/mp4', '.json': 'application/json' }[extname(path)] ?? 'application/octet-stream';
  let start = 0, end = size - 1;
  if (req.headers.range) {
    const match = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range);
    if (!match) throw new ProjectError('unsupported range', 416);
    start = Number(match[1]); end = match[2] ? Math.min(Number(match[2]), end) : end;
    if (start > end) throw new ProjectError('invalid range', 416);
    res.setHeader('content-range', `bytes ${start}-${end}/${size}`);
  }
  res.writeHead(req.headers.range ? 206 : 200, { 'content-type': type, 'accept-ranges': 'bytes', 'content-length': end - start + 1 });
  createReadStream(path, { start, end }).pipe(res);
}

const server = createServer(async (req, res) => {
  const origin = req.headers.origin;
  if (origin && !allowedOrigins.has(origin)) { json(res, { error: 'origin not allowed' }, 403); return; }
  if (origin) res.setHeader('access-control-allow-origin', origin);
  res.setHeader('vary', 'Origin');
  if (req.method === 'OPTIONS') {
    res.writeHead(204, { 'access-control-allow-methods': 'GET, POST, OPTIONS', 'access-control-allow-headers': 'content-type, x-file-name, authorization' }); res.end(); return;
  }
  try {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    const parts = url.pathname.split('/').filter(Boolean).map(decodeURIComponent);
    if (url.pathname === '/session' && req.method === 'GET') {
      if (!origin || !allowedOrigins.has(origin)) throw new ProjectError('studio origin required', 403);
      json(res, { token: serviceToken }); return;
    }
    const artifactRead = req.method === 'GET' && parts[0] === 'projects' && parts[2] === 'files';
    if (url.pathname !== '/health' && !artifactRead && req.headers.authorization !== `Bearer ${serviceToken}`) throw new ProjectError('local service authorization required', 401);
    if (url.pathname === '/health') { json(res, { ok: true, pid: process.pid, apiVersion: 'project-service/v5-llm-ae', projectsRoot, activeJob: active?.jobId ?? null, queued: queue.length, analysis: 'reference fingerprint import + SONG analyzer for new audio' }); return; }
    if (url.pathname === '/projects' && req.method === 'GET') { json(res, { projects: listProjects() }); return; }
    if (url.pathname === '/projects' && req.method === 'POST') {
      const input = await body(req);
      json(res, createProjectFromAudio(input.audioPath, input.name, {
        lyricsText: input.lyricsText,
        lrcPath: input.lrcPath,
        language: input.language,
        stages: input.stages
      }), 201);
      return;
    }
    if (url.pathname === '/import-audio' && req.method === 'POST') {
      const name = decodeURIComponent(String(req.headers['x-file-name'] ?? 'audio.mp3'));
      const ext = extname(name).toLowerCase();
      if (!['.mp3', '.wav', '.m4a', '.ogg', '.flac'].includes(ext)) throw new ProjectError('unsupported audio file');
      const chunks = []; let size = 0;
      for await (const chunk of req) { size += chunk.length; if (size > 300 * 1024 * 1024) throw new ProjectError('audio exceeds 300 MB', 413); chunks.push(chunk); }
      const imports = join(projectsRoot, '.imports'); mkdirSync(imports, { recursive: true });
      const temporary = join(imports, randomUUID() + ext);
      writeFileSync(temporary, Buffer.concat(chunks), { flag: 'wx' });
      try { json(res, createProjectFromAudio(temporary, name.replace(/\.[^.]+$/, '')), 201); }
      finally { unlinkSync(temporary); }
      return;
    }
    if (url.pathname === '/feedback' && req.method === 'GET') {
      const projectId = url.searchParams.get('projectId') ?? undefined;
      if (projectId !== undefined && !safeId(projectId)) throw new ProjectError('invalid project id');
      json(res, feedbackInbox({ projectId, status: url.searchParams.get('status') ?? 'open' })); return;
    }
    if (parts[0] !== 'projects' || !safeId(parts[1])) throw new ProjectError('route not found', 404);
    const id = parts[1];
    if (parts.length === 2 && req.method === 'GET') { json(res, readProject(id)); return; }
    if (parts[2] === 'director') {
      if (req.method === 'GET' && parts.length <= 4) { json(res, getDirector(id)); return; }
      if (req.method === 'POST') {
        const input = await body(req);
        if (parts.length === 3) { json(res, submitDirector(id, input.expectedProjectRevision, input.director, input.author ?? 'mcp')); return; }
        if (parts[3] === 'claim') { json(res, claimDirector(id, input.actionId, input.owner, input.leaseSeconds)); return; }
        if (parts[3] === 'complete') { json(res, completeDirector(id, input.actionId, input.attemptToken, input)); return; }
        if (parts[3] === 'dispatch') { json(res, dispatchDirector(id, input.actionIds, input.attemptTokens, enqueue), 202); return; }
        if (parts[3] === 'review') { json(res, submitReview(id, input.expectedProjectRevision, input.review)); return; }
        if (parts[3] === 'accept-review') { json(res, acceptDirectorReview(id, input.expectedProjectRevision)); return; }
      }
    }
    if (parts[2] === 'jobs' && parts.length <= 4 && req.method === 'GET') {
      const wait = Number(url.searchParams.get('wait') ?? 0);
      json(res, parts[3] ? publicJob(wait > 0 ? await waitJob(id, parts[3], wait) : readJob(id, parts[3])) : { jobs: listJobs(id).map(publicJob) }); return;
    }
    if (parts[2] === 'jobs' && parts[4] === 'cancel' && req.method === 'POST') {
      const job = readJob(id, parts[3]);
      if (active?.jobId === job.id) active.child.send('cancel');
      else { const index = queue.findIndex((entry) => entry.jobId === job.id); if (index >= 0) queue.splice(index, 1); if (job.status === 'queued') saveJob(id, { ...job, status: 'cancelled', finishedAt: Date.now() }); }
      json(res, publicJob(readJob(id, job.id))); return;
    }
    if (parts[2] === 'validate' && req.method === 'POST') { json(res, enqueue(id, 'validate', await body(req)), 202); return; }
    if (parts[2] === 'stills' && req.method === 'POST') { json(res, enqueue(id, 'stills', await body(req)), 202); return; }
    if (AE_KINDS.includes(parts[2]) && req.method === 'POST') { json(res, enqueue(id, parts[2], await body(req)), 202); return; }
    if (parts[2] === 'cue-sheet' && req.method === 'GET') {
      const project = readProject(id);
      if (!project.song) throw new ProjectError(`工程还在 ${project.status ?? '未知'} 阶段，没有音乐分析`, 409);
      const number = (key) => (url.searchParams.has(key) ? Number(url.searchParams.get(key)) : undefined);
      const sheet = cueSheet(project.song, { start: number('start') ?? 0, end: number('end') ?? Infinity, shots: project.shots, transitions: project.transitions });
      json(res, { projectId: id, revision: project.revision, text: sheet.text, grid: sheet.grid, bars: sheet.bars.length }); return;
    }
    if (parts[2] === 'render' && req.method === 'POST') { json(res, enqueue(id, 'export', await body(req)), 202); return; }
    if (parts[2] === 'song' && parts[3] === 'analysis' && req.method === 'GET') { json(res, getSongAnalysis(id, url.searchParams)); return; }
    if (parts[2] === 'song' && parts[3] === 'analysis' && parts[4] === 'confirm' && req.method === 'POST') { json(res, confirmSongAnalysis(id, (await body(req)).author ?? 'human')); return; }
    if (parts[2] === 'song' && parts[3] === 'analysis' && parts[4] === 'retry' && req.method === 'POST') { json(res, retryAnalysis(id)); return; }
    if (parts[2] === 'song' && parts[3] === 'analysis' && parts[4] === 'patch' && req.method === 'POST') { const input = await body(req); json(res, patchSongAnalysis(id, input.expectedInputRevision, input.patch, input.author ?? 'human')); return; }
    if (parts[2] === 'song' && parts[3] === 'lyrics' && req.method === 'POST') { const input = await body(req); json(res, submitSongLyrics(id, input.expectedInputRevision, input.lyrics, input.author ?? 'human')); return; }
    if (parts[2] === 'plan' && req.method === 'POST') { const input = await body(req); json(res, submitPlan(id, input.expectedInputRevision, input.plan, input.reasoning, input.author ?? 'human')); return; }
    if (parts[2] === 'shots' && safeId(parts[3])) {
      if (parts[4] === 'lyrics' && req.method === 'GET') { json(res, readShotLyricContext(id, parts[3])); return; }
      if (parts[4] === 'source' && req.method === 'GET') { json(res, readShotSource(id, parts[3])); return; }
      if (parts[4] === 'source' && req.method === 'POST') { const input = await body(req); json(res, submitShotSource(id, parts[3], input.expectedInputRevision, input.code, input.summary, input.addressedFeedbackIds, input.author, input.feedbackResponses, input.attemptToken)); return; }
      if (parts[4] === 'feedback' && parts.length === 5 && req.method === 'POST') { const input = await body(req); json(res, addShotFeedback(id, parts[3], input.expectedInputRevision, { text: input.text, anchor: input.anchor, preserve: input.preserve, author: input.author })); return; }
      if (parts[4] === 'feedback' && safeId(parts[5]) && ['ask', 'reply'].includes(parts[6]) && req.method === 'POST') {
        const input = await body(req);
        json(res, parts[6] === 'ask' ? askFeedback(id, 'shot', parts[3], parts[5], input.question, input.author ?? 'mcp') : replyFeedback(id, 'shot', parts[3], parts[5], input.text, input.author ?? 'human')); return;
      }
      if (parts[4] === 'reject-feedback' && req.method === 'POST') { const input = await body(req); json(res, rejectShotFeedback(id, parts[3], input.expectedInputRevision)); return; }
      if (parts[4] === 'accept-feedback' && req.method === 'POST') { const input = await body(req); json(res, acceptShotFeedback(id, parts[3], input.expectedInputRevision, input.feedbackIds)); return; }
      if (parts.length === 4 && req.method === 'POST') { const input = await body(req); json(res, updateShot(id, parts[3], input.expectedInputRevision, input.patch ?? {}, input.attemptToken, input.author ?? 'human')); return; }
    }
    if (parts[2] === 'transitions' && safeId(parts[3])) {
      const transitionId = parts[3];
      const project = readProject(id);
      const transition = project.transitions.find((entry) => entry.id === transitionId);
      if (!transition) throw new ProjectError('transition not found', 404);
      if (req.method === 'GET' && parts.length === 4) {
        const { left, right } = transitionPair(project, transition);
        json(res, { transition, fromShot: left, toShot: right, window: transitionWindow(project, transition), rule: '过渡位于切点之后，出镜停在末帧，入镜跟随当前歌曲时间；不改变全片时长。' }); return;
      }
      if (req.method === 'POST') {
        const input = await body(req);
        if (parts[4] === 'config') { json(res, configureTransition(id, transitionId, input.expectedInputRevision, input.config, input.addressedFeedbackIds, input.author, input.feedbackResponses, input.attemptToken)); return; }
        if (parts[4] === 'feedback' && parts.length === 5) { json(res, addShotFeedback(id, transitionId, input.expectedInputRevision, { text: input.text, anchor: input.anchor, preserve: input.preserve, author: input.author }, 'transition')); return; }
        if (parts[4] === 'feedback' && safeId(parts[5]) && parts[6] === 'ask') { json(res, askFeedback(id, 'transition', transitionId, parts[5], input.question, input.author ?? 'mcp')); return; }
        if (parts[4] === 'feedback' && safeId(parts[5]) && parts[6] === 'reply') { json(res, replyFeedback(id, 'transition', transitionId, parts[5], input.text, input.author ?? 'human')); return; }
        if (parts[4] === 'accept-feedback') { json(res, acceptShotFeedback(id, transitionId, input.expectedInputRevision, input.feedbackIds, 'transition')); return; }
        if (parts[4] === 'reject-feedback') { json(res, rejectShotFeedback(id, transitionId, input.expectedInputRevision, 'transition')); return; }
        if (parts[4] === 'validate') { json(res, enqueue(id, 'validate-transition', { transitionId }), 202); return; }
        if (parts.length === 4) { json(res, updateTransition(id, transitionId, input.expectedInputRevision, input.patch)); return; }
      }
    }
    if (parts[2] === 'preview' && req.method === 'POST') {
      const project = readProject(id);
      const options = await body(req);
      const before = options.version === 'before-feedback';
      const transition = options.transitionId ? project.transitions.find((entry) => entry.id === options.transitionId) : null;
      if (options.transitionId && !transition) throw new ProjectError('transition not found', 404);
      const target = before ? transition ?? project.shots.find((shot) => shot.id === options.shotId) : null;
      if (before && !target?.reviewBaseline) throw new ProjectError('没有可比较的修改前版本');
      const key = `${id}:${options.transitionId ?? options.shotId ?? 'all'}:${before ? 'before' : 'current'}`;
      const transitions = before && transition ? project.transitions.map((entry) => entry.id === transition.id ? { ...entry, ...transition.reviewBaseline } : entry) : project.transitions;
      let shots = before && !transition ? project.shots.map((shot) => shot.id === target.id ? { ...shot, ...target.reviewBaseline } : shot) : project.shots;
      if (before && transition?.reviewBaselineSources) shots = shots.map((shot) => shot.id === transition.fromShotId ? { ...shot, ...transition.reviewBaselineSources.left } : shot.id === transition.toShotId ? { ...shot, ...transition.reviewBaselineSources.right } : shot);
      let preview = previews.get(key);
      if (preview?.revision !== project.revision) {
        await preview?.server.close();
        if (previews.size >= 2 && !previews.has(key)) { const [oldId, old] = previews.entries().next().value; await old.server.close(); previews.delete(oldId); }
        const host = await startReferenceServer({ root: join(projectDir(id), 'engine'), shots, transitions, fps: project.output.fps, audioFile: project.audio.engineFile });
        preview = { revision: project.revision, server: host }; previews.set(key, preview);
      }
      let range;
      if (transition) {
        const selectedTransition = transitions.find((entry) => entry.id === transition.id);
        const context = { ...project, shots };
        const window = transitionWindow(context, selectedTransition);
        const { left, right } = transitionPair(context, selectedTransition);
        range = { start: Math.max(left.start, window.start - .4), end: Math.min(right.end, window.end + .4), only: `${left.id},${right.id}` };
      } else if (options.shotId) {
        const selectedShot = shots.find((shot) => shot.id === options.shotId);
        if (!selectedShot) throw new ProjectError('shot not found', 404);
        range = { start: Math.round(selectedShot.start * project.output.fps) / project.output.fps,
          end: Math.round(selectedShot.end * project.output.fps) / project.output.fps, only: selectedShot.id };
      }
      json(res, { url: preview.server.url, revision: preview.revision, range }); return;
    }
    if (parts[2] === 'files' && req.method === 'GET') {
      const relative = parts.slice(3).join('/');
      if (!/^(artifacts\/[a-f0-9]{64}\.(png|mp4|json)|exports\/[a-f0-9-]{36}\/(pv\.mp4|manifest\.json))$/.test(relative)) throw new ProjectError('invalid artifact path');
      fileResponse(req, res, join(projectDir(id), relative)); return;
    }
    throw new ProjectError('route not found', 404);
  } catch (error) { if (!res.headersSent) json(res, { error: String(error.message ?? error) }, error.status ?? 500); else res.destroy(); }
});

// 只有成功取得端口后才发布令牌/恢复任务；启动冲突不能破坏已有服务的认证或任务状态。
server.on('error', (error) => { console.error(error); process.exitCode = 1; });
let stopAnalysisWorker;
server.listen(port, '127.0.0.1', () => {
  mkdirSync(dirname(tokenPath), { recursive: true });
  writeFileSync(tokenPath, serviceToken, { mode: 0o600 });
  // 不盲目重跑状态不明的旧进程；已完成分段仍可复用。
  for (const project of listProjects()) for (const job of listJobs(project.id, 10000)) {
    if (job.kind === 'analysis') { if (job.status === 'running') saveJob(project.id, { ...job, status: 'interrupted', error: '服务重启；工程仍为 analysis-pending 时会自动重新分析。' }); continue; }
    if (job.status === 'queued') queue.push({ projectId: project.id, jobId: job.id });
    else if (job.status === 'running') saveJob(project.id, { ...job, status: 'interrupted', error: '服务重启，旧渲染进程未恢复；可重新发起并复用已完成分段。' });
  }
  // SONG-05: 启动分析任务后台处理器
  stopAnalysisWorker = startAnalysisWorker();
  console.log(`VideoGraph project service http://127.0.0.1:${port}`); pump();
});
async function shutdown() {
  closing = true;
  if (stopAnalysisWorker) stopAnalysisWorker();
  active?.child.send('cancel');
  for (const preview of previews.values()) await preview.server.close();
  server.close();
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
