// index.mjs — 本地工程服务：UI/MCP 共用命令，后台任务不依赖浏览器生命周期。
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { createReadStream, existsSync, mkdirSync, statSync, writeFileSync, unlinkSync } from 'node:fs';
import { join, extname, resolve, dirname } from 'node:path';
import { createProjectFromAudio, listProjects, readProject, updateShot, addShotFeedback, acceptShotFeedback, rejectShotFeedback, readShotSource, readShotLyricContext, submitShotSource, updateTransition, configureTransition, projectDir, projectsRoot, productRoot, saveJob, listJobs, readJob, ProjectError, safeId } from './project-store.mjs';
import { startReferenceServer } from './reference-server.mjs';
import { transitionPair, transitionWindow } from './transitions.mjs';

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
function enqueue(projectId, kind, options) {
  const project = readProject(projectId);
  if (!['validate', 'validate-transition', 'export'].includes(kind)) throw new ProjectError('invalid job kind');
  if (kind === 'validate-transition' && !project.transitions.some((transition) => transition.id === options.transitionId)) throw new ProjectError('transition not found', 404);
  if (kind === 'validate' && !project.shots.some((shot) => shot.id === options.shotId)) throw new ProjectError('shot not found', 404);
  if (kind === 'export' && [...project.shots, ...project.transitions].some((target) => (target.feedback ?? []).some((note) => note.status !== 'accepted'))) throw new ProjectError('存在未接受的镜头或转场意见：请先配置/改写、校验并确认采用。', 409);
  if (kind === 'export' && project.transitions.some((transition) => transition.status === 'needs-generation')) throw new ProjectError('有转场指导尚未落实为效果配置', 409);
  const fps = options.fps ?? project.output.fps;
  const samples = options.samples ?? project.output.samples;
  if (![24, 30, 60].includes(fps) || ![1, 4, 12].includes(samples)) throw new ProjectError('fps supports 24/30/60; samples supports 1/4/12');
  const job = { id: randomUUID(), projectId, kind, status: 'queued', progress: 0, detail: '等待渲染进程', createdAt: Date.now(), input: { project, shotId: options.shotId, transitionId: options.transitionId, fps, samples } };
  saveJob(projectId, job);
  queue.push({ projectId, jobId: job.id });
  pump();
  return publicJob(job);
}
function publicJob(job) {
  const { input, ...result } = job;
  return { ...result, inputRevision: input.project.revision, shotId: input.shotId, transitionId: input.transitionId, fps: input.fps, samples: input.samples };
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
    if (url.pathname === '/health') { json(res, { ok: true, pid: process.pid, apiVersion: 'project-service/v2-lyrics-transitions', projectsRoot, activeJob: active?.jobId ?? null, queued: queue.length, analysis: 'known-BGM fingerprint cache' }); return; }
    if (url.pathname === '/projects' && req.method === 'GET') { json(res, { projects: listProjects() }); return; }
    if (url.pathname === '/projects' && req.method === 'POST') {
      const input = await body(req); json(res, createProjectFromAudio(input.audioPath, input.name), 201); return;
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
    if (parts[0] !== 'projects' || !safeId(parts[1])) throw new ProjectError('route not found', 404);
    const id = parts[1];
    if (parts.length === 2 && req.method === 'GET') { json(res, readProject(id)); return; }
    if (parts[2] === 'jobs' && req.method === 'GET') {
      json(res, parts[3] ? publicJob(readJob(id, parts[3])) : { jobs: listJobs(id).map(publicJob) }); return;
    }
    if (parts[2] === 'jobs' && parts[4] === 'cancel' && req.method === 'POST') {
      const job = readJob(id, parts[3]);
      if (active?.jobId === job.id) active.child.send('cancel');
      else { const index = queue.findIndex((entry) => entry.jobId === job.id); if (index >= 0) queue.splice(index, 1); if (job.status === 'queued') saveJob(id, { ...job, status: 'cancelled', finishedAt: Date.now() }); }
      json(res, publicJob(readJob(id, job.id))); return;
    }
    if (parts[2] === 'validate' && req.method === 'POST') { json(res, enqueue(id, 'validate', await body(req)), 202); return; }
    if (parts[2] === 'render' && req.method === 'POST') { json(res, enqueue(id, 'export', await body(req)), 202); return; }
    if (parts[2] === 'shots' && safeId(parts[3])) {
      if (parts[4] === 'lyrics' && req.method === 'GET') { json(res, readShotLyricContext(id, parts[3])); return; }
      if (parts[4] === 'source' && req.method === 'GET') { json(res, readShotSource(id, parts[3])); return; }
      if (parts[4] === 'source' && req.method === 'POST') { const input = await body(req); json(res, submitShotSource(id, parts[3], input.expectedInputRevision, input.code, input.summary, input.addressedFeedbackIds, input.author)); return; }
      if (parts[4] === 'feedback' && req.method === 'POST') { const input = await body(req); json(res, addShotFeedback(id, parts[3], input.expectedInputRevision, input.text)); return; }
      if (parts[4] === 'reject-feedback' && req.method === 'POST') { const input = await body(req); json(res, rejectShotFeedback(id, parts[3], input.expectedInputRevision)); return; }
      if (parts[4] === 'accept-feedback' && req.method === 'POST') { const input = await body(req); json(res, acceptShotFeedback(id, parts[3], input.expectedInputRevision, input.feedbackIds)); return; }
      if (parts.length === 4 && req.method === 'POST') { const input = await body(req); json(res, updateShot(id, parts[3], input.expectedInputRevision, input.patch ?? {})); return; }
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
        if (parts[4] === 'config') { json(res, configureTransition(id, transitionId, input.expectedInputRevision, input.config, input.addressedFeedbackIds, input.author)); return; }
        if (parts[4] === 'feedback') { json(res, addShotFeedback(id, transitionId, input.expectedInputRevision, input.text, 'transition')); return; }
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
        const host = await startReferenceServer({ root: join(projectDir(id), 'engine'), shots, transitions, fps: project.output.fps });
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
server.listen(port, '127.0.0.1', () => {
  mkdirSync(dirname(tokenPath), { recursive: true });
  writeFileSync(tokenPath, serviceToken, { mode: 0o600 });
  // 不盲目重跑状态不明的旧进程；已完成分段仍可复用。
  for (const project of listProjects()) for (const job of listJobs(project.id)) {
    if (job.status === 'queued') queue.push({ projectId: project.id, jobId: job.id });
    else if (job.status === 'running') saveJob(project.id, { ...job, status: 'interrupted', error: '服务重启，旧渲染进程未恢复；可重新发起并复用已完成分段。' });
  }
  console.log(`VideoGraph project service http://127.0.0.1:${port}`); pump();
});
async function shutdown() {
  closing = true;
  active?.child.send('cancel');
  for (const preview of previews.values()) await preview.server.close();
  server.close();
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
