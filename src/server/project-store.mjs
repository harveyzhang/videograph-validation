// project-store.mjs — 本地工程事实源。SQLite 元数据/历史 + 内容寻址源码 + 完整引擎快照。
import { DatabaseSync } from 'node:sqlite';
import { createHash, randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync, statSync, cpSync, copyFileSync, constants } from 'node:fs';
import { resolve, join, extname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { referenceShots } from './reference-plan.mjs';
import { ProjectError } from './errors.mjs';
import { prepareLyricPlan, shotLyricContext } from './lyric-elements.mjs';
import { normalizeProject, transitionPair, transitionConfig, validateTransitionConfig, transitionWindow } from './transitions.mjs';
import { prepareFeedbackInput, createNote, invalidateResponses, prepareResponses, applyResponses, askOnNote, replyOnNote, inboxItems, feedbackTargetWindow, lyricElementIds } from './feedback.mjs';
export { ProjectError } from './errors.mjs';

export const productRoot = fileURLToPath(new URL('../..', import.meta.url));
export const projectsRoot = resolve(process.env.VIDEOGRAPH_PROJECTS ?? join(productRoot, 'projects'));
const referenceRoot = resolve(productRoot, '../pdoom-video');
export const sha256 = (value) => createHash('sha256').update(value).digest('hex');
export const safeId = (value) => typeof value === 'string' && /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,80}$/.test(value);
export function projectDir(id) {
  if (!safeId(id)) throw new ProjectError('invalid project id');
  const dir = join(projectsRoot, id);
  if (!existsSync(join(dir, 'project.sqlite'))) throw new ProjectError('project not found', 404);
  return dir;
}
function open(id) { const db = new DatabaseSync(join(projectDir(id), 'project.sqlite')); db.exec('PRAGMA busy_timeout=5000;'); return db; }
function parse(row) { return row ? JSON.parse(row.data) : null; }

export function readProject(id) {
  const db = open(id);
  try { return normalizeProject(parse(db.prepare('SELECT data FROM project WHERE id=1').get())); }
  finally { db.close(); }
}
export function listProjects() {
  if (!existsSync(projectsRoot)) return [];
  return readdirSync(projectsRoot).filter((id) => safeId(id) && existsSync(join(projectsRoot, id, 'project.sqlite')))
    .map((id) => { const p = readProject(id); return { id, name: p.name, revision: p.revision, createdAt: p.createdAt, shots: p.shots.length, duration: p.song.duration }; })
    .sort((a, b) => b.createdAt - a.createdAt);
}
export function mutateProject(id, expectedRevision, mutate) {
  const db = open(id);
  try {
    db.exec('BEGIN IMMEDIATE');
    const current = normalizeProject(parse(db.prepare('SELECT data FROM project WHERE id=1').get()));
    if (expectedRevision !== undefined && current.revision !== expectedRevision) throw new ProjectError('工程已更新，请重新读取后再操作', 409);
    const next = normalizeProject(mutate(structuredClone(current)));
    next.revision = current.revision + 1;
    next.updatedAt = Date.now();
    const data = JSON.stringify(next);
    db.prepare('UPDATE project SET data=? WHERE id=1').run(data);
    db.prepare('INSERT INTO revisions(revision,data,created_at) VALUES(?,?,?)').run(next.revision, data, next.updatedAt);
    db.exec('COMMIT');
    return next;
  } catch (error) { db.exec('ROLLBACK'); throw error; }
  finally { db.close(); }
}

function hashTree(dir, prefix = '') {
  return readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    const key = prefix + entry.name;
    return entry.isDirectory() ? hashTree(join(dir, entry.name), key + '/') : [[key, sha256(readFileSync(join(dir, entry.name)))]];
  });
}

/** 本阶段对该 BGM 使用内容指纹命中的已对齐分析；不会把它说成重新跑过语音识别。 */
export function createProjectFromAudio(audioPath, name) {
  if (typeof audioPath !== 'string' || !['.mp3', '.wav', '.m4a', '.ogg', '.flac'].includes(extname(audioPath).toLowerCase())) throw new ProjectError('需要本地音频文件路径');
  const path = resolve(audioPath);
  if (!existsSync(path) || !statSync(path).isFile() || statSync(path).size > 300 * 1024 * 1024) throw new ProjectError('音频不存在或超过 300 MB');
  const audio = readFileSync(path);
  const audioHash = sha256(audio);
  const knownHash = sha256(readFileSync(join(referenceRoot, 'audio/pdoom.mp3')));
  if (audioHash !== knownHash) throw new ProjectError('该音频尚未匹配可复现的分析/引擎配方。本阶段仅支持 pdoom-video 的原始 BGM；不能用它的歌词时间轴套用其他歌曲。', 422);
  const id = randomUUID();
  const dir = join(projectsRoot, id);
  mkdirSync(dir, { recursive: true });
  const engine = join(dir, 'engine');
  mkdirSync(join(engine, 'app'), { recursive: true });
  cpSync(join(referenceRoot, 'app/src'), join(engine, 'app/src'), { recursive: true });
  cpSync(join(referenceRoot, 'app/public/fonts'), join(engine, 'app/public/fonts'), { recursive: true });
  cpSync(join(referenceRoot, 'app/public/plates'), join(engine, 'app/public/plates'), { recursive: true });
  cpSync(join(referenceRoot, 'data'), join(engine, 'data'), { recursive: true });
  copyFileSync(join(referenceRoot, 'app/index.html'), join(engine, 'app/index.html'), constants.COPYFILE_EXCL);
  copyFileSync(join(referenceRoot, 'LICENSE'), join(engine, 'LICENSE'), constants.COPYFILE_EXCL);
  copyFileSync(join(referenceRoot, 'README.md'), join(engine, 'CREDITS.md'), constants.COPYFILE_EXCL);
  cpSync(join(referenceRoot, 'docs'), join(engine, 'docs'), { recursive: true });
  mkdirSync(join(engine, 'audio'), { recursive: true });
  writeFileSync(join(engine, 'audio/pdoom.mp3'), audio, { flag: 'wx' });
  mkdirSync(join(dir, 'artifacts'), { recursive: true });
  mkdirSync(join(dir, 'exports'), { recursive: true });
  const dependencies = Object.fromEntries(['three', 'opentype.js'].map((pkg) => [pkg, JSON.parse(readFileSync(join(productRoot, `node_modules/${pkg}/package.json`), 'utf8')).version]));
  const files = hashTree(engine);
  const engineHash = sha256(JSON.stringify({ files, dependencies }));
  writeFileSync(join(dir, 'engine-manifest.json'), JSON.stringify({ schema: 1, engineHash, dependencies, files }, null, 2));
  const song = JSON.parse(readFileSync(join(productRoot, 'src/shot/full-song.json'), 'utf8'));
  const project = {
    id, name: name?.trim() || basename(path, extname(path)), schema: 'videograph-project/v1', revision: 0,
    createdAt: Date.now(), updatedAt: Date.now(), engineHash, dependencies,
    audio: { name: basename(path), hash: audioHash },
    analysis: { source: 'fingerprint-cache', reference: 'pdoom-video/data', note: '字节指纹命中已提交的词级/节拍分析；未重新执行语音识别。' },
    song, shots: referenceShots(song).map((shot) => ({ ...shot, inputToken: randomUUID() })),
    output: { fps: 30, width: 1920, height: 1080, samples: 1 },
    credits: 'Engine/scenes: pdoom-video (MIT). Song, lyrics and fonts retain their original rights; see engine/CREDITS.md.',
  };
  normalizeProject(project);
  const db = new DatabaseSync(join(dir, 'project.sqlite'));
  try {
    db.exec(`PRAGMA journal_mode=WAL;
      CREATE TABLE project(id INTEGER PRIMARY KEY CHECK(id=1),data TEXT NOT NULL);
      CREATE TABLE revisions(revision INTEGER PRIMARY KEY,data TEXT NOT NULL,created_at INTEGER NOT NULL);
      CREATE TABLE jobs(id TEXT PRIMARY KEY,kind TEXT NOT NULL,status TEXT NOT NULL,data TEXT NOT NULL,updated_at INTEGER NOT NULL);`);
    db.prepare('INSERT INTO project VALUES(1,?)').run(JSON.stringify(project));
    db.prepare('INSERT INTO revisions VALUES(0,?,?)').run(JSON.stringify(project), project.createdAt);
  } finally { db.close(); }
  return project;
}

function shotFor(project, shotId, expectedInputRevision) {
  const shot = project.shots.find((entry) => entry.id === shotId);
  if (!shot) throw new ProjectError('shot not found', 404);
  if (!Number.isInteger(expectedInputRevision) || shot.inputRevision !== expectedInputRevision) throw new ProjectError('镜头版本已改变，请重新读取后再提交', 409);
  return shot;
}
function targetFor(project, id, revision, kind = 'shot') {
  if (kind === 'shot') return shotFor(project, id, revision);
  if (kind !== 'transition') throw new ProjectError('invalid feedback target');
  const target = project.transitions.find((entry) => entry.id === id);
  if (!target) throw new ProjectError('transition not found', 404);
  if (!Number.isInteger(revision) || target.inputRevision !== revision) throw new ProjectError('转场版本已改变，请重新读取后提交', 409);
  return target;
}

export function readShotLyricContext(id, shotId) {
  const project = readProject(id);
  const shot = project.shots.find((entry) => entry.id === shotId);
  if (!shot) throw new ProjectError('shot not found', 404);
  return shotLyricContext(project, shot);
}

function versionSnapshot(shot) {
  return structuredClone({ module: shot.module, params: shot.params, source: shot.source, start: shot.start, end: shot.end,
    codeHash: shot.codeHash, prompt: shot.prompt, lyricPlan: shot.lyricPlan, summary: shot.summary, validation: shot.validation,
    intent: shot.intent, mode: shot.mode, duration: shot.duration, easing: shot.easing, direction: shot.direction });
}
/** 快照键以基线为唯一事实：候选期写入而基线没有的字段必须删除，浅合并会残留候选的 codeHash/summary 等。 */
function restoreSnapshot(target, snapshot) {
  for (const key of ['module', 'params', 'source', 'start', 'end', 'codeHash', 'prompt', 'lyricPlan', 'summary', 'validation', 'intent', 'mode', 'duration', 'easing', 'direction']) {
    if (snapshot[key] === undefined) delete target[key];
    else target[key] = structuredClone(snapshot[key]);
  }
}

export function updateShot(id, shotId, expectedInputRevision, patch) {
  if (!patch || typeof patch !== 'object' || Array.isArray(patch) || Object.keys(patch).some((key) => !['title', 'prompt', 'params', 'lyricPlan', 'locked'].includes(key))) throw new ProjectError('unsupported shot patch');
  return mutateProject(id, undefined, (project) => {
    const shot = shotFor(project, shotId, expectedInputRevision);
    const edits = Object.keys(patch).filter((key) => key !== 'locked');
    if (shot.locked && edits.length) throw new ProjectError('镜头已锁定，请先显式解锁', 409);
    if (patch.title !== undefined) {
      if (typeof patch.title !== 'string' || !patch.title.trim() || patch.title.length > 120) throw new ProjectError('镜头标题为空或过长');
      shot.title = patch.title.trim();
    }
    if (patch.prompt !== undefined) {
      if (typeof patch.prompt !== 'string' || !patch.prompt.trim() || patch.prompt.length > 12000) throw new ProjectError('提示词为空或过长');
      shot.prompt = patch.prompt;
      shot.status = 'needs-generation';
    }
    if (patch.params !== undefined) {
      if (!patch.params || Array.isArray(patch.params) || typeof patch.params !== 'object' || JSON.stringify(patch.params).length > 16000) throw new ProjectError('invalid params');
      shot.params = patch.params;
      if (shot.status !== 'needs-generation') shot.status = 'needs-validation';
    }
    if (patch.lyricPlan !== undefined) {
      shot.lyricPlan = prepareLyricPlan(project, shot, patch.lyricPlan);
      shot.status = 'needs-generation';
    }
    if (patch.locked !== undefined) {
      if (typeof patch.locked !== 'boolean') throw new ProjectError('locked must be boolean');
      shot.locked = patch.locked;
    }
    if (edits.some((key) => key === 'prompt' || key === 'params' || key === 'lyricPlan')) {
      invalidateResponses(shot);
      shot.inputRevision++; shot.inputToken = randomUUID(); delete shot.validation;
    }
    return project;
  });
}
export function readShotSource(id, shotId) {
  const project = readProject(id);
  const shot = project.shots.find((entry) => entry.id === shotId);
  if (!shot || !safeId(shot.module)) throw new ProjectError('shot not found', 404);
  const engine = join(projectDir(id), 'engine');
  return { shot, code: readFileSync(join(engine, `app/src/scenes/${shot.module}.ts`), 'utf8'),
    contract: readFileSync(join(engine, 'docs/ENGINE.md'), 'utf8'), lyricContext: shotLyricContext(project, shot), source: shot.source };
}
export function submitShotSource(id, shotId, expectedInputRevision, code, summary = '', addressedFeedbackIds = [], author = 'mcp', feedbackResponses = []) {
  if (typeof code !== 'string' || code.length < 20 || code.length > 200000) throw new ProjectError('invalid scene code');
  if (!['mcp', 'human'].includes(author)) throw new ProjectError('invalid source author');
  return mutateProject(id, undefined, (project) => {
    const shot = shotFor(project, shotId, expectedInputRevision);
    if (shot.locked) throw new ProjectError('镜头已锁定', 409);
    const responses = prepareResponses(shot, addressedFeedbackIds ?? [], feedbackResponses ?? []);
    shot.previousVersion = versionSnapshot(shot);
    const hash = sha256(code);
    const module = `vg-${hash}`;
    const path = join(projectDir(id), `engine/app/src/scenes/${module}.ts`);
    if (!existsSync(path)) writeFileSync(path, code, { flag: 'wx' });
    else if (sha256(readFileSync(path)) !== hash) throw new ProjectError('不可变源码文件已被外部修改', 409);
    shot.module = module;
    shot.codeHash = hash;
    shot.source = author === 'human' ? 'human-authored' : 'mcp-authored';
    shot.summary = String(summary).slice(0, 1000);
    shot.inputRevision++;
    shot.inputToken = randomUUID();
    shot.status = 'needs-validation';
    invalidateResponses(shot);
    applyResponses(shot, responses, { codeHash: hash, inputToken: shot.inputToken, author });
    delete shot.validation;
    return project;
  });
}

/** input 可以是意见文本（旧调用），或 { text, anchor?, preserve?, author? }（FB-01 契约，见 feedback.mjs）。 */
export function addShotFeedback(id, shotId, expectedInputRevision, input, kind = 'shot') {
  const raw = typeof input === 'string' ? { text: input } : (input && typeof input === 'object' && !Array.isArray(input) ? input : { text: undefined });
  return mutateProject(id, undefined, (project) => {
    const shot = targetFor(project, shotId, expectedInputRevision, kind);
    if (shot.locked) throw new ProjectError('镜头已锁定，请先解锁后添加修改意见', 409);
    const pair = kind === 'transition' ? transitionPair(project, shot) : null;
    const prepared = prepareFeedbackInput(raw, { window: feedbackTargetWindow(project, shot, kind, pair), elementIds: lyricElementIds(shot, kind, pair), fps: project.output?.fps ?? 30 });
    shot.feedback ??= [];
    if (!shot.feedback.some((note) => note.status !== 'accepted')) {
      shot.reviewBaseline = versionSnapshot(shot);
      if (kind === 'transition') {
        const { left, right } = transitionPair(project, shot);
        shot.reviewBaselineSources = { left: versionSnapshot(left), right: versionSnapshot(right) };
      }
    }
    invalidateResponses(shot);
    shot.feedback.push(createNote(prepared, shot, randomUUID()));
    shot.inputRevision++;
    shot.inputToken = randomUUID();
    shot.status = 'needs-generation';
    delete shot.validation;
    return project;
  });
}

export function acceptShotFeedback(id, shotId, expectedInputRevision, feedbackIds, kind = 'shot') {
  if (!Array.isArray(feedbackIds) || !feedbackIds.length) throw new ProjectError('需要明确要接受的修改意见 ID');
  return mutateProject(id, undefined, (project) => {
    const shot = targetFor(project, shotId, expectedInputRevision, kind);
    if (kind === 'transition') {
      const { left, right } = transitionPair(project, shot);
      if (shot.validation?.leftInputToken !== left.inputToken || shot.validation?.rightInputToken !== right.inputToken) throw new ProjectError('相邻镜头已变化，请重新验证转场', 409);
    }
    if (shot.status !== 'ready' || shot.validation?.inputToken !== shot.inputToken) throw new ProjectError('先验证并预览当前候选，再接受修改', 409);
    for (const id of feedbackIds) {
      const note = (shot.feedback ?? []).find((entry) => entry.id === id);
      if (!note || note.status !== 'responded' || note.codeHash !== shot.codeHash || note.responseInputToken !== shot.inputToken) throw new ProjectError('只能接受明确响应了意见的当前候选；旧版本响应不可沿用', 409);
      note.status = 'accepted'; note.acceptedAt = Date.now(); note.acceptedInputRevision = shot.inputRevision;
    }
    return project;
  });
}

export function rejectShotFeedback(id, shotId, expectedInputRevision, kind = 'shot') {
  return mutateProject(id, undefined, (project) => {
    const shot = targetFor(project, shotId, expectedInputRevision, kind);
    if (shot.locked) throw new ProjectError('镜头已锁定，请先解锁', 409);
    if (!shot.reviewBaseline || !(shot.feedback ?? []).some((note) => note.status !== 'accepted')) throw new ProjectError('没有可拒绝的候选', 409);
    shot.previousVersion = versionSnapshot(shot);
    restoreSnapshot(shot, structuredClone(shot.reviewBaseline));
    invalidateResponses(shot);
    shot.inputRevision++; shot.inputToken = randomUUID(); shot.status = 'needs-generation'; delete shot.validation;
    for (const note of shot.feedback ?? []) if (note.status !== 'accepted') note.rejectedAt = Date.now();
    return project;
  });
}

export function updateTransition(id, transitionId, expectedInputRevision, patch) {
  if (!patch || typeof patch !== 'object' || Array.isArray(patch) || Object.keys(patch).some((key) => !['intent', 'locked'].includes(key))) throw new ProjectError('这里只编辑转场指导或锁定；效果参数请提交 config');
  return mutateProject(id, undefined, (project) => {
    const transition = targetFor(project, transitionId, expectedInputRevision, 'transition');
    if (transition.locked && patch.intent !== undefined) throw new ProjectError('转场已锁定，请先解锁', 409);
    if (patch.intent !== undefined) {
      if (typeof patch.intent !== 'string' || !patch.intent.trim() || patch.intent.length > 8000) throw new ProjectError('转场指导不能为空或过长');
      transition.intent = patch.intent.trim(); transition.inputRevision++; transition.inputToken = randomUUID();
      transition.status = 'needs-generation'; invalidateResponses(transition); delete transition.validation;
    }
    if (patch.locked !== undefined) {
      if (typeof patch.locked !== 'boolean') throw new ProjectError('locked must be boolean');
      transition.locked = patch.locked;
    }
    return project;
  });
}
export function configureTransition(id, transitionId, expectedInputRevision, config, addressedFeedbackIds = [], author = 'mcp', feedbackResponses = []) {
  if (!['human', 'mcp'].includes(author)) throw new ProjectError('invalid transition author');
  return mutateProject(id, undefined, (project) => {
    const transition = targetFor(project, transitionId, expectedInputRevision, 'transition');
    if (transition.locked) throw new ProjectError('转场已锁定，请先解锁', 409);
    const responses = prepareResponses(transition, addressedFeedbackIds ?? [], feedbackResponses ?? []);
    const checked = validateTransitionConfig(project, transition, config);
    transition.previousVersion = versionSnapshot(transition);
    Object.assign(transition, checked);
    transition.inputRevision++; transition.inputToken = randomUUID(); transition.status = 'needs-validation';
    transition.source = `${author}-configured`; transition.codeHash = sha256(JSON.stringify(transitionConfig(transition)));
    invalidateResponses(transition);
    applyResponses(transition, responses, { codeHash: transition.codeHash, inputToken: transition.inputToken, author });
    delete transition.validation;
    return project;
  });
}

function feedbackTarget(project, kind, targetId) {
  if (kind !== 'shot' && kind !== 'transition') throw new ProjectError('targetKind 只支持 shot / transition');
  const target = (kind === 'shot' ? project.shots : project.transitions).find((entry) => entry.id === targetId);
  if (!target) throw new ProjectError(`${kind} not found`, 404);
  return target;
}
/** AI 提问澄清：不改变输入版本，只改变该意见状态（needs-clarification 不能被接受，导出仍被拦截）。 */
export function askFeedback(id, kind, targetId, feedbackId, question, by = 'mcp') {
  return mutateProject(id, undefined, (project) => { askOnNote(feedbackTarget(project, kind, targetId), feedbackId, question, by); return project; });
}
/** 人回复澄清，意见回到 pending。 */
export function replyFeedback(id, kind, targetId, feedbackId, text, by = 'human') {
  return mutateProject(id, undefined, (project) => { replyOnNote(feedbackTarget(project, kind, targetId), feedbackId, text, by); return project; });
}
/** 待办收件箱；省略 projectId 时汇总全部本地工程。 */
export function feedbackInbox({ projectId, status = 'open' } = {}) {
  const ids = projectId ? [projectId] : listProjects().map((project) => project.id);
  const items = ids.flatMap((pid) => {
    const project = readProject(pid);
    return inboxItems(project, { status, windowOf: (kind, target) => {
      if (kind === 'shot') return { start: target.start, end: target.end };
      try { return transitionWindow(project, target); } catch { return null; }
    } });
  });
  return { status, count: items.length, items, rule: 'AI 只能响应或提问；采用/拒绝由人在界面完成。' };
}

export function saveJob(id, job) {
  const db = open(id);
  try { db.prepare('INSERT INTO jobs(id,kind,status,data,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET status=excluded.status,data=excluded.data,updated_at=excluded.updated_at')
    .run(job.id, job.kind, job.status, JSON.stringify(job), Date.now()); }
  finally { db.close(); }
}
export function listJobs(id) {
  const db = open(id);
  try { return db.prepare('SELECT data FROM jobs ORDER BY updated_at DESC LIMIT 40').all().map(parse); }
  finally { db.close(); }
}
export function readJob(id, jobId) {
  const db = open(id);
  try { const job = parse(db.prepare('SELECT data FROM jobs WHERE id=?').get(jobId)); if (!job) throw new ProjectError('job not found', 404); return job; }
  finally { db.close(); }
}
