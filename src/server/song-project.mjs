// song-project.mjs — SONG-03/05：任意歌曲工程。建工程（通用引擎快照）→ 分析落盘 → 确认 → 规划。
// 参考曲走 project-store 的指纹导入；本模块只服务新歌工程，不读取 pdoom 的歌词/时间轴。
import { DatabaseSync } from 'node:sqlite';
import { randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync, cpSync, copyFileSync, renameSync } from 'node:fs';
import { join, extname, basename, resolve } from 'node:path';
import { ProjectError } from './errors.mjs';
import { fileURLToPath } from 'node:url';
import { mutateProject, readProject, projectDir, projectsRoot, sha256 } from './project-store.mjs';
import { validateAnalysis, SongError } from '../song/contract.mjs';
import { toEngineAudio, toEngineLyrics } from '../song/adapters/toEngine.mjs';
import { toFullSong } from '../song/adapters/toFullSong.mjs';
import { validatePlan, planFromSections } from '../song/planner.mjs';

// project-store 与本模块互相引用：顶层常量在本模块内自算，避免循环加载时的 TDZ。
const productRoot = fileURLToPath(new URL('../..', import.meta.url));
const referenceRoot = resolve(productRoot, '../pdoom-video');
export const ANALYSIS_STAGES = ['t0', 't1', 't3'];
const ANALYSIS_FILE = 'analysis/analysis-v2.json';
// engine-base/SCENES.md：绑定 pdoom 原句（ly.get）的场景不进新歌工程。
const BOUND_SCENES = new Set(['open', 'open-geo', 'loss', 'room', 'room-geo', 'room-shrooms', 'shoggoth', 'shoggoth-glsl', 'spacetime', 'spacetime-lens',
  'ascent', 'ascent-eye', 'ascent-note', 'ascent-odo', 'leftturn', 'leftturn-gantt', 'leftturn-map', 'paperclips', 'paperclips-geo', 'paperclips-glsl',
  'loom', 'loom-glsl', 'loom-tree', 'ilya-room']);
// 新歌工程的时间轴完全由工程镜头决定（reference-server 覆盖 makeTimeline）；这里不得引用任何原曲歌词。
const GENERIC_TIMELINE = `// 新歌工程时间轴：镜头窗口来自工程数据（VideoGraph 渲染宿主注入），不含原曲歌词锚点。
import type { TimelineEntry } from './engine/engine';
import type { Lyrics } from './engine/lyrics';
import type { AudioData } from './engine/audio';

export function makeTimeline(_ly: Lyrics, _au: AudioData): TimelineEntry[] {
  return [];
}
`;

const CREDITS = `# Credits

- 引擎核心（engine/、main.ts）与通用场景：pdoom-video，MIT License，见 LICENSE。
- 本工程镜头场景（scenes/vg-*.ts）为本工程新写，来源与作者记录在工程数据库的镜头版本中。
- 歌曲、歌词与音频版权归原权利人所有。
`;

function check(fn) {
  try { return fn(); } catch (error) { if (error instanceof SongError) throw new ProjectError(error.message, 400); throw error; }
}

/** 通用引擎快照：引擎核心 + 通用场景 + 字体/底图；data/ 等分析完成后由 publishAnalysis 写入。 */
function createSongEngine(dir, audio, ext) {
  const engine = join(dir, 'engine');
  mkdirSync(join(engine, 'app/src/scenes'), { recursive: true });
  cpSync(join(referenceRoot, 'app/src/engine'), join(engine, 'app/src/engine'), { recursive: true });
  copyFileSync(join(referenceRoot, 'app/src/main.ts'), join(engine, 'app/src/main.ts'));
  writeFileSync(join(engine, 'app/src/timeline.ts'), GENERIC_TIMELINE);
  for (const file of readdirSync(join(referenceRoot, 'app/src/scenes'))) {
    if (!BOUND_SCENES.has(basename(file, '.ts'))) copyFileSync(join(referenceRoot, 'app/src/scenes', file), join(engine, 'app/src/scenes', file));
  }
  copyFileSync(join(productRoot, 'engine-base/scenes/_window-template.ts'), join(engine, 'app/src/scenes/_window-template.ts'));
  cpSync(join(referenceRoot, 'app/public/fonts'), join(engine, 'app/public/fonts'), { recursive: true });
  cpSync(join(referenceRoot, 'app/public/plates'), join(engine, 'app/public/plates'), { recursive: true });
  copyFileSync(join(referenceRoot, 'app/index.html'), join(engine, 'app/index.html'));
  copyFileSync(join(referenceRoot, 'LICENSE'), join(engine, 'LICENSE'));
  writeFileSync(join(engine, 'CREDITS.md'), CREDITS);
  cpSync(join(referenceRoot, 'docs'), join(engine, 'docs'), { recursive: true });
  mkdirSync(join(engine, 'audio'), { recursive: true });
  mkdirSync(join(engine, 'data'), { recursive: true });
  const engineFile = `audio/song${ext}`;
  writeFileSync(join(engine, engineFile), audio, { flag: 'wx' });
  return engineFile;
}

function hashTree(dir, prefix = '') {
  return readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    const key = prefix + entry.name;
    return entry.isDirectory() ? hashTree(join(dir, entry.name), key + '/') : [[key, sha256(readFileSync(join(dir, entry.name)))]];
  });
}
function writeManifest(dir) {
  const dependencies = Object.fromEntries(['three', 'opentype.js'].map((pkg) => [pkg, JSON.parse(readFileSync(join(productRoot, `node_modules/${pkg}/package.json`), 'utf8')).version]));
  // 不可变场景模块（vg-*.ts）由 codeHash 单独追踪，不计入引擎指纹。
  const files = hashTree(join(dir, 'engine')).filter(([key]) => !/^app\/src\/scenes\/vg-[0-9a-f]{64}\.ts$/.test(key));
  const engineHash = sha256(JSON.stringify({ files, dependencies }));
  writeFileSync(join(dir, 'engine-manifest.json'), JSON.stringify({ schema: 1, engineHash, dependencies, files }, null, 2));
  return { engineHash, dependencies };
}
function writeAtomic(path, data) {
  const temporary = `${path}.${process.pid}.tmp`;
  writeFileSync(temporary, data);
  renameSync(temporary, path);
}

export function createSongProject(path, audio, audioHash, name, opts = {}) {
  const { lyricsText, lrcPath, language } = opts;
  const stages = opts.stages ?? ANALYSIS_STAGES;
  if (!Array.isArray(stages) || !stages.length || stages.some((stage) => !ANALYSIS_STAGES.includes(stage))) throw new ProjectError('stages 只能是 t0/t1/t3 的组合');
  if (!stages.includes('t1')) throw new ProjectError('建工程至少需要 t1（节拍/段落）分析');
  if (lyricsText !== undefined && (typeof lyricsText !== 'string' || lyricsText.length > 50000)) throw new ProjectError('lyricsText 必须是 ≤50000 字的文本');
  if (lrcPath !== undefined && (typeof lrcPath !== 'string' || !existsSync(lrcPath))) throw new ProjectError('lrcPath 不存在');
  const id = randomUUID();
  const dir = join(projectsRoot, id);
  mkdirSync(join(dir, 'analysis'), { recursive: true });
  mkdirSync(join(dir, 'artifacts'), { recursive: true });
  mkdirSync(join(dir, 'exports'), { recursive: true });
  const engineFile = createSongEngine(dir, audio, extname(path).toLowerCase());
  const now = Date.now();
  const project = {
    id, name: name?.trim() || basename(path, extname(path)), schema: 'videograph-project/v1', revision: 0,
    createdAt: now, updatedAt: now,
    audio: { name: basename(path), hash: audioHash, engineFile },
    status: 'analysis-pending',
    analysis: {
      source: 'pending', stages: [...new Set(['t0', ...stages])],
      params: { language: language ?? null, hasLyricsText: Boolean(lyricsText), lrcPath: lrcPath ? resolve(lrcPath) : null },
      note: '等待音频分析（节拍/段落/歌词）完成后才能规划镜头。',
    },
    song: null, shots: [], transitions: [],
    output: { fps: 30, width: 1920, height: 1080, samples: 1 },
    credits: 'Engine core and generic scenes: pdoom-video (MIT). Song and lyrics remain the rights holder\'s; see engine/CREDITS.md.',
  };
  // 歌词原文只放在工程目录内的分析输入里，不进 project 快照/MCP 输出。
  if (lyricsText) writeFileSync(join(dir, 'analysis/lyrics.txt'), lyricsText, 'utf8');
  const db = new DatabaseSync(join(dir, 'project.sqlite'));
  try {
    db.exec(`PRAGMA journal_mode=WAL;
      CREATE TABLE project(id INTEGER PRIMARY KEY CHECK(id=1),data TEXT NOT NULL);
      CREATE TABLE revisions(revision INTEGER PRIMARY KEY,data TEXT NOT NULL,created_at INTEGER NOT NULL);
      CREATE TABLE jobs(id TEXT PRIMARY KEY,kind TEXT NOT NULL,status TEXT NOT NULL,data TEXT NOT NULL,updated_at INTEGER NOT NULL);`);
    db.prepare('INSERT INTO project VALUES(1,?)').run(JSON.stringify(project));
    db.prepare('INSERT INTO revisions VALUES(0,?,?)').run(JSON.stringify(project), now);
  } finally { db.close(); }
  return project;
}

/** 分析器输入（给 analysis-jobs）：路径只在服务进程内使用。 */
export function analysisInput(id) {
  const project = readProject(id);
  const dir = projectDir(id);
  const lyricsPath = join(dir, 'analysis/lyrics.txt');
  return {
    audioPath: join(dir, 'engine', project.audio.engineFile),
    stages: project.analysis.stages,
    language: project.analysis.params?.language ?? undefined,
    lyricsText: existsSync(lyricsPath) ? readFileSync(lyricsPath, 'utf8') : undefined,
    lrcPath: project.analysis.params?.lrcPath ?? undefined,
    title: project.name,
  };
}

function readAnalysis(id) {
  const file = join(projectDir(id), ANALYSIS_FILE);
  if (!existsSync(file)) throw new ProjectError('工程还没有歌曲分析数据', 404);
  return JSON.parse(readFileSync(file, 'utf8'));
}

/** 校验并发布分析：落盘 v2、写引擎 data/、重算引擎指纹，返回工程级派生字段。 */
function publishAnalysis(id, raw, title) {
  const analysis = check(() => validateAnalysis(raw));
  const dir = projectDir(id);
  const audioJson = check(() => toEngineAudio(analysis));
  const lyricsJson = analysis.lyrics ? toEngineLyrics(analysis) : { lines: [], extras: [], notes: '器乐：无歌词层' };
  const song = check(() => toFullSong(analysis, { title }));
  writeAtomic(join(dir, ANALYSIS_FILE), JSON.stringify(analysis));
  writeAtomic(join(dir, 'engine/data/audio.json'), JSON.stringify(audioJson));
  writeAtomic(join(dir, 'engine/data/lyrics.json'), JSON.stringify(lyricsJson));
  return { song, ...writeManifest(dir) };
}

export function completeAnalysis(id, raw, { cached = false } = {}) {
  const project = readProject(id);
  if (project.status !== 'analysis-pending') throw new ProjectError(`只有 analysis-pending 工程能写入分析结果，当前是 ${project.status ?? 'normal'}`, 409);
  const published = publishAnalysis(id, raw, project.name);
  return mutateProject(id, undefined, (next) => {
    if (next.status !== 'analysis-pending') throw new ProjectError('分析期间工程状态已改变', 409);
    Object.assign(next, published);
    next.status = 'analysis-draft';
    next.analysis = { ...next.analysis, source: 'analyzer', cached, completedAt: Date.now(), instrumental: !published.song.lines.length,
      note: '分析草稿：确认节拍/歌词/段落后才能规划镜头。' };
    return next;
  });
}

export function failAnalysis(id, message) {
  return mutateProject(id, undefined, (project) => {
    if (project.status !== 'analysis-pending') return project;
    project.status = 'analysis-failed';
    project.analysis = { ...project.analysis, error: String(message).slice(0, 2000), failedAt: Date.now() };
    return project;
  });
}

/** 重新排队分析（分析失败后由人或 agent 发起）。 */
export function retryAnalysis(id) {
  return mutateProject(id, undefined, (project) => {
    if (project.status !== 'analysis-failed') throw new ProjectError(`只有分析失败的工程能重试，当前是 ${project.status ?? 'normal'}`, 409);
    project.status = 'analysis-pending';
    delete project.analysis.error;
    return project;
  });
}

const LAYERS = ['audio', 'rhythm', 'sections', 'lyrics', 'envelopes', 'onsets'];
/** 读取 v2 分析；可按时间段（秒）与层过滤。包络默认不返回（体积大），需显式请求。 */
export function getSongAnalysis(id, params = new URLSearchParams()) {
  const project = readProject(id);
  const analysis = readAnalysis(id);
  const num = (key) => { const raw = params.get(key); if (raw === null || raw === '') return undefined; const value = Number(raw); if (!Number.isFinite(value)) throw new ProjectError(`${key} 必须是数字`); return value; };
  const start = num('startTime') ?? 0, end = num('endTime') ?? Infinity;
  const requested = params.get('layers')?.split(',').filter(Boolean) ?? ['audio', 'rhythm', 'sections', 'lyrics'];
  const unknown = requested.filter((layer) => !LAYERS.includes(layer));
  if (unknown.length) throw new ProjectError(`未知分析层：${unknown.join(',')}`);
  const inRange = (t) => t >= start && t < end;
  const data = {};
  for (const layer of requested) {
    const value = analysis[layer];
    if (value === undefined) continue;
    if (layer === 'rhythm') data.rhythm = { ...value, beats: value.beats.filter(inRange), downbeats: value.downbeats.filter(inRange) };
    else if (layer === 'sections') data.sections = value.filter((section) => section.start < end && section.end > start);
    else if (layer === 'lyrics') data.lyrics = { ...value, lines: value.lines.filter((line) => line.start < end && line.end > start) };
    else if (layer === 'onsets') data.onsets = Object.fromEntries(Object.entries(value).map(([key, list]) => [key, list.filter(([t]) => inRange(t))]));
    else data[layer] = value;
  }
  const { params: _inputs, ...analysisMeta } = project.analysis ?? {};
  return { projectId: id, status: project.status ?? 'normal', inputRevision: project.revision, analysis: analysisMeta, provenance: analysis.provenance, data };
}

export function confirmSongAnalysis(id, confirmedBy = 'human') {
  if (!['human', 'mcp'].includes(confirmedBy)) throw new ProjectError('confirmedBy 只能是 human 或 mcp', 400);
  return mutateProject(id, undefined, (project) => {
    if (project.status !== 'analysis-draft') throw new ProjectError(`工程状态必须是 analysis-draft，当前是 ${project.status ?? 'normal'}`, 409);
    project.status = 'analysis-confirmed';
    project.analysis = { ...project.analysis, confirmedAt: Date.now(), confirmedBy,
      note: confirmedBy === 'mcp' ? 'agent 已确认节拍/歌词/段落，可以进入规划阶段；人仍可在界面复核。' : '人工已确认节拍/歌词/段落，可以进入规划阶段。' };
    return project;
  });
}

/** 提交歌词层（v2 lyrics 结构，整层替换）；规划前可改，确认后再改会退回 analysis-draft。 */
export function submitSongLyrics(id, expectedInputRevision, lyrics, source = 'mcp') {
  if (!['mcp', 'human'].includes(source)) throw new ProjectError('source 只能是 mcp 或 human');
  if (!lyrics || typeof lyrics !== 'object' || !Array.isArray(lyrics.lines)) throw new ProjectError('lyrics 必须是 { lines: [{ text, start, end, words: [{ w, start, end }] }] }');
  const project = readProject(id);
  if (project.revision !== expectedInputRevision) throw new ProjectError('工程已更新，请重新读取后再操作', 409);
  if (!['analysis-draft', 'analysis-confirmed'].includes(project.status)) throw new ProjectError(`只能在规划前提交歌词，当前是 ${project.status ?? 'normal'}`, 409);
  const analysis = readAnalysis(id);
  // 歌词层的 humanConfirmed 只表示“文本经人校对”，agent 修正一律记 false（与工程级分析确认分开）。
  const layer = { language: lyrics.language ?? analysis.lyrics?.language ?? 'und', textSource: lyrics.textSource ?? analysis.lyrics?.textSource ?? 'user',
    lines: lyrics.lines, ...(lyrics.extras ? { extras: lyrics.extras } : {}), humanConfirmed: source === 'human' };
  const next = { ...analysis, lyrics: layer, provenance: { ...analysis.provenance, lyrics: { ...(analysis.provenance?.lyrics ?? {}), tool: `videograph/${source}-edit`, version: '1', startedAt: Date.now(), params: { editedBy: source } } } };
  const published = publishAnalysis(id, next, project.name);
  return mutateProject(id, expectedInputRevision, (current) => {
    Object.assign(current, published);
    current.status = 'analysis-draft';
    current.analysis = { ...current.analysis, lyricsEditedBy: source, lyricsEditedAt: Date.now(), instrumental: !published.song.lines.length,
      note: '歌词已修改，需要重新确认后才能规划镜头。' };
    delete current.analysis.confirmedAt; delete current.analysis.confirmedBy;
    return current;
  });
}

/**
 * 提交镜头规划。plan 为 [{ lineText | sectionIndex | t, title?, prompt?, id? }]，切点由锚点推导（吸附拍、不切词）；
 * 省略 plan 时使用确定性兜底（每段一镜，明确标注非 AI 创作）。
 */
export function submitPlan(id, expectedInputRevision, plan, reasoning = '', author = 'mcp') {
  const project = readProject(id);
  if (project.status !== 'analysis-confirmed') throw new ProjectError(`只能在 analysis-confirmed 状态提交规划，当前是 ${project.status ?? 'normal'}`, 409);
  const analysis = readAnalysis(id);
  const fps = project.output?.fps ?? 30;
  const fallback = plan === undefined || plan === null;
  const { shots, warnings } = check(() => fallback ? planFromSections(analysis, { fps }) : validatePlan(plan, analysis, { fps }));
  return mutateProject(id, expectedInputRevision, (current) => {
    if (current.status !== 'analysis-confirmed') throw new ProjectError('工程状态已改变', 409);
    current.shots = shots.map((shot) => ({
      id: shot.id, module: null, title: shot.title, start: shot.start, end: shot.end, params: {},
      prompt: shot.prompt || `${shot.title}（${shot.anchor}）：待 agent 按本窗口歌词与节拍创作场景。`,
      anchor: shot.anchor, inputRevision: 0, inputToken: randomUUID(), source: shot.source, status: 'needs-generation', locked: false,
    }));
    delete current.transitions; // normalizeProject 按新镜头重建默认硬切转场
    current.status = 'planned';
    current.plan = { mode: fallback ? 'fallback-deterministic' : 'agent', reasoning: String(reasoning ?? '').slice(0, 4000), warnings, submittedAt: Date.now(), submittedBy: author };
    return current;
  });
}
