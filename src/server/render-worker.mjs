// render-worker.mjs — 独立进程：冻结工程版本、逐帧渲染、分段缓存、整曲封装。
import { chromium } from 'playwright-core';
import { WebSocketServer } from 'ws';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync } from 'node:fs';
import { join } from 'node:path';
import { startReferenceServer } from './reference-server.mjs';
import { projectDir, readJob, saveJob, mutateProject, sha256, productRoot } from './project-store.mjs';
import { normalizeProject, transitionPair, transitionWindow, transitionConfig } from './transitions.mjs';

const [projectId, jobId] = process.argv.slice(2);
const job = readJob(projectId, jobId);
const frozen = normalizeProject(job.input.project);
const dir = projectDir(projectId);
const controller = new AbortController();
process.on('message', (message) => { if (message === 'cancel') controller.abort(); });
process.on('disconnect', () => controller.abort());
const signal = controller.signal;
let browser;
let server;
let lastSave = 0;
function progress(detail, value) {
  job.detail = detail; job.progress = value;
  if (Date.now() - lastSave > 500 || value === 1) { saveJob(projectId, job); lastSave = Date.now(); }
}
const ffmpeg = process.env.FFMPEG_PATH ?? 'ffmpeg';

async function runFfmpeg(args) {
  signal.throwIfAborted();
  const process = spawn(ffmpeg, args, { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'], signal });
  let stderr = '';
  process.stderr.on('data', (chunk) => { stderr = (stderr + chunk).slice(-6000); });
  const [code] = await once(process, 'close');
  if (code !== 0) throw new Error(`ffmpeg exit ${code}: ${stderr}`);
}

async function renderSegment(page, shot, output, fps, samples, doneFrames, totalFrames) {
  signal.throwIfAborted();
  const first = Math.round(shot.start * fps), last = Math.round(shot.end * fps), count = last - first;
  const width = 1920, height = 1080;
  const encoder = spawn(ffmpeg, ['-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${width}x${height}`, '-r', String(fps), '-i', 'pipe:0',
    '-an', '-vf', 'vflip,scale=out_color_matrix=bt709,setparams=color_primaries=bt709:color_trc=bt709', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', output],
    { windowsHide: true, stdio: ['pipe', 'ignore', 'pipe'] });
  let stderr = '', failure;
  encoder.stderr.on('data', (data) => { stderr = (stderr + data).slice(-6000); });
  encoder.stdin.on('error', (error) => { failure = error; });
  encoder.on('error', (error) => { failure = error; });
  const encoderExit = new Promise((resolve) => encoder.on('close', (code) => resolve(code)));
  const token = randomUUID();
  const socket = new WebSocketServer({ host: '127.0.0.1', port: 0, maxPayload: width * height * 4 + 1024,
    verifyClient: ({ req, origin }) => req.url === `/${token}` && origin === server.url });
  await once(socket, 'listening');
  let received = 0;
  let chain = Promise.resolve();
  socket.on('connection', (ws) => {
    ws.on('message', (buffer, binary) => {
      chain = chain.then(async () => {
        signal.throwIfAborted();
        if (!binary || buffer.length !== width * height * 4 || received >= count) throw new Error('unexpected frame payload');
        if (!encoder.stdin.write(buffer)) await once(encoder.stdin, 'drain');
        received++;
        ws.send(String(received));
        progress(`渲染 ${shot.title} · ${received}/${count} 帧`, (doneFrames + received) / totalFrames);
      }).catch((error) => { failure = error; ws.terminate(); encoder.kill(); void page.close(); });
    });
  });
  const cancel = () => { for (const ws of socket.clients) ws.terminate(); encoder.kill(); void page.close(); };
  signal.addEventListener('abort', cancel, { once: true });
  try {
    await page.evaluate((options) => window.__pdoom.stream(options), { from: first / fps, to: last / fps, fps, samples, shutter: 0.2, inflight: 2, ws: `ws://127.0.0.1:${socket.address().port}/${token}` });
    await chain;
    const deadline = Date.now() + 30000;
    while (received < count && !failure && Date.now() < deadline) {
      signal.throwIfAborted();
      await new Promise((resolve) => setTimeout(resolve, 10));
      await chain;
    }
    if (failure) throw failure;
    if (received !== count) throw new Error(`frame count mismatch: ${received}/${count}`);
    encoder.stdin.end();
    const code = await encoderExit;
    if (code !== 0) throw new Error(`encoder exit ${code}: ${stderr}`);
  } finally {
    signal.removeEventListener('abort', cancel);
    for (const ws of socket.clients) ws.terminate();
    await new Promise((resolve) => socket.close(resolve));
    if (encoder.exitCode === null) encoder.kill();
  }
}

try {
  job.status = 'running'; job.startedAt = Date.now(); saveJob(projectId, job);
  for (const [pkg, version] of Object.entries(frozen.dependencies)) {
    const actual = JSON.parse(readFileSync(join(productRoot, `node_modules/${pkg}/package.json`), 'utf8')).version;
    if (actual !== version) throw new Error(`引擎依赖版本改变：${pkg} 需要 ${version}，当前 ${actual}`);
  }
  const manifest = JSON.parse(readFileSync(join(dir, 'engine-manifest.json'), 'utf8'));
  for (const [path, hash] of manifest.files) {
    if (sha256(readFileSync(join(dir, 'engine', path))) !== hash) throw new Error(`引擎快照被外部修改：${path}；请重新导入或通过镜头源码工具创建新版本。`);
  }
  const hostHash = sha256(Buffer.concat(['reference-server.mjs', 'transition-runtime.mjs', 'transitions.mjs'].map((name) => readFileSync(new URL(name, import.meta.url)))));
  const fps = job.input.fps ?? frozen.output.fps;
  const samples = job.input.samples ?? frozen.output.samples;
  const shots = frozen.shots.map((shot) => ({ ...shot, start: Math.round(shot.start * fps) / fps, end: Math.round(shot.end * fps) / fps }));
  server = await startReferenceServer({ root: join(dir, 'engine'), shots, transitions: frozen.transitions, fps });
  browser = await chromium.launch({ headless: true, executablePath: process.env.EDGE_PATH ?? 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    args: ['--use-angle=d3d11', '--ignore-gpu-blocklist', '--enable-gpu-rasterization', '--disable-background-timer-throttling'] });
  signal.addEventListener('abort', () => { void browser?.close(); }, { once: true });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  let browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(error.message));
  page.on('console', (message) => { if (message.type() === 'error') browserErrors.push(message.text()); });
  await page.route('**/*', (route) => route.request().url().startsWith(server.url + '/') ? route.continue() : route.abort());
  async function loadShot(shot, previous) {
    browserErrors = [];
    const index = shots.findIndex((entry) => entry.id === shot.id);
    const previousId = previous?.id ?? (samples > 1 ? shots[index - 1]?.id : undefined);
    const only = [previousId, shot.id].filter(Boolean).join(',');
    await page.goto(`${server.url}/?export=1&only=${encodeURIComponent(only)}`);
    await page.waitForFunction(() => window.__pdoom?.ready || window.__pdoom?.error, null, { timeout: 120000 });
    const error = await page.evaluate(() => window.__pdoom.error || window.__pdoom.errors.join('\n'));
    if (error) throw new Error(error);
  }
  const targetTransition = job.kind === 'validate-transition' ? frozen.transitions.find((entry) => entry.id === job.input.transitionId) : null;
  if (job.kind === 'validate-transition' && !targetTransition) throw new Error('转场不存在');
  const wanted = targetTransition ? shots.filter((shot) => shot.id === targetTransition.toShotId) : job.kind === 'validate' ? shots.filter((shot) => shot.id === job.input.shotId) : shots;
  if (!wanted.length) throw new Error('没有可渲染镜头');
  const total = Math.round(frozen.song.duration * fps);
  let doneFrames = 0;
  const segments = [], reports = [];
  for (const shot of wanted) {
    signal.throwIfAborted();
    if (shot.status === 'needs-generation') throw new Error(`${shot.id} 提示词已修改，请先通过 MCP 提交对应源码`);
    const code = readFileSync(join(dir, `engine/app/src/scenes/${shot.module}.ts`), 'utf8');
    const incoming = targetTransition ?? frozen.transitions.find((entry) => entry.toShotId === shot.id && entry.mode !== 'cut');
    if (incoming?.status === 'needs-generation') throw new Error(`${incoming.id} 有新的转场指导，尚未配置效果`);
    const previous = incoming ? transitionPair({ ...frozen, shots }, incoming).left : null;
    if (previous?.status === 'needs-generation') throw new Error(`${previous.id} 尚未完成改写，不能验证相邻转场`);
    const dependency = incoming ? { config: transitionConfig(incoming), from: { start: previous.start, end: previous.end, params: previous.params, post: previous.post,
      code: readFileSync(join(dir, `engine/app/src/scenes/${previous.module}.ts`), 'utf8') } } : null;
    const key = sha256(JSON.stringify({ engine: frozen.engineHash, hostHash, browser: browser.version(), code, dependency, scope: targetTransition ? 'transition' : 'shot', shot: { start: shot.start, end: shot.end, params: shot.params, post: shot.post }, fps, samples, encoder: 'x264-crf18-veryfast-bt709-v1' }));
    const publishValidation = (validation) => mutateProject(projectId, undefined, (project) => {
      const current = project.shots.find((entry) => entry.id === shot.id);
      const currentTransition = incoming ? project.transitions.find((entry) => entry.id === incoming.id) : null;
      const currentPrevious = previous ? project.shots.find((entry) => entry.id === previous.id) : null;
      if (current?.inputToken !== shot.inputToken || (incoming && (currentTransition?.inputToken !== incoming.inputToken || currentPrevious?.inputToken !== previous.inputToken))) return project;
      if (targetTransition) {
        currentTransition.validation = { ...validation, inputToken: incoming.inputToken, leftInputToken: previous.inputToken, rightInputToken: shot.inputToken };
        currentTransition.status = 'ready';
      } else { current.validation = validation; current.status = 'ready'; }
      return project;
    });
    const file = join(dir, 'artifacts', `${key}.mp4`);
    const meta = join(dir, 'artifacts', `${key}.json`);
    const cached = existsSync(file) && existsSync(meta) && JSON.parse(readFileSync(meta, 'utf8')).hash === sha256(readFileSync(file));
    if (job.kind === 'export' && cached) {
      const validation = { samples: 5, inputToken: shot.inputToken, key, thumb: `${key}.png`, checkedAt: Date.now(), cached: true };
      publishValidation(validation);
      doneFrames += Math.round((shot.end - shot.start) * fps);
      segments.push(file); reports.push({ shotId: shot.id, cached: true, key });
      progress(`复用 ${shot.title}`, doneFrames / total);
      continue;
    }
    await loadShot(shot, previous);
    const window = targetTransition ? transitionWindow({ ...frozen, shots }, targetTransition, fps) : null;
    const sampleTimes = window ? (window.frames ? [window.start - 1 / fps, window.start, (window.start + window.end) / 2, window.end, window.end + 1 / fps]
      : [-2, -1, 0, 1, 2].map((frame) => window.start + frame / fps)).map((t) => Math.max(previous.start, Math.min(shot.end - 1 / fps, t)))
      : [0, .25, .45, .75, .99].map((ratio) => shot.start + (shot.end - shot.start) * ratio);
    for (const t of sampleTimes) await page.evaluate((t) => window.__pdoom.still(t, 1, .2), t);
    const errors = await page.evaluate(() => window.__pdoom.errors);
    if (errors.length || browserErrors.length) throw new Error(`${shot.id}: ${[...errors, ...browserErrors].join('\n')}`);
    const previewTime = window ? (window.start + window.end) / 2 : shot.start + (shot.end - shot.start) * .45;
    await page.evaluate((t) => window.__pdoom.still(t, 1, 0.2), previewTime);
    const png = await page.evaluate(() => window.__pdoom.png());
    const thumb = `${key}.png`;
    writeFileSync(join(dir, 'artifacts', thumb), Buffer.from(png, 'base64'));
    const validation = { samples: 5, times: sampleTimes, inputToken: shot.inputToken, key, thumb, checkedAt: Date.now() };
    publishValidation(validation);
    if (job.kind === 'export') {
      const temporary = join(dir, 'artifacts', `${key}-${jobId}.tmp.mp4`);
      await renderSegment(page, shot, temporary, fps, samples, doneFrames, total);
      const renderErrors = await page.evaluate(() => window.__pdoom.errors);
      if (renderErrors.length || browserErrors.length) throw new Error(`${shot.id}: ${[...renderErrors, ...browserErrors].join('\n')}`);
      renameSync(temporary, file);
      writeFileSync(meta, JSON.stringify({ hash: sha256(readFileSync(file)), frames: Math.round(shot.end * fps) - Math.round(shot.start * fps), key }));
      segments.push(file);
      doneFrames += Math.round(shot.end * fps) - Math.round(shot.start * fps);
    }
    reports.push({ shotId: shot.id, ...(targetTransition ? { transitionId: targetTransition.id } : {}), cached: false, ...validation });
  }
  if (job.kind === 'export') {
    const outDir = join(dir, 'exports', jobId); mkdirSync(outDir, { recursive: true });
    const list = join(outDir, 'segments.txt');
    writeFileSync(list, segments.map((path) => `file '${path.replace(/\\/g, '/').replace(/'/g, "'\\''")}'`).join('\n'));
    const output = join(outDir, 'pv.mp4');
    progress('合成全片并封装完整 BGM…', 0.99);
    await runFfmpeg(['-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', list, '-i', join(dir, 'engine/audio/pdoom.mp3'),
      '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '320k', '-af', 'apad', '-t', String(total / fps), '-movflags', '+faststart', output]);
    job.result = { file: `exports/${jobId}/pv.mp4`, frames: total, seconds: total / fps, fps, samples, revision: frozen.revision, transitions: frozen.transitions.map(({ id, fromShotId, toShotId, mode, duration, easing, direction }) => ({ id, fromShotId, toShotId, mode, duration, easing, direction })), reports };
    writeFileSync(join(outDir, 'manifest.json'), JSON.stringify({ ...job.result, engineHash: frozen.engineHash, audioHash: frozen.audio.hash, credits: frozen.credits }, null, 2));
  } else job.result = { revision: frozen.revision, reports };
  job.status = 'done'; job.finishedAt = Date.now(); progress('完成', 1);
} catch (error) {
  job.status = signal.aborted ? 'cancelled' : 'error'; job.error = String(error).slice(0, 12000); job.finishedAt = Date.now(); saveJob(projectId, job);
  console.error(job.error);
} finally {
  await browser?.close();
  await server?.close();
  if (process.connected) process.disconnect();
}
