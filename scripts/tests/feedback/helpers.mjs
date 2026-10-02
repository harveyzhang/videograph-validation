// helpers.mjs — FB-02/FB-03 验收共用夹具：最小“引擎”应用 + 工程 SQLite。
// 引擎是刻意简化的 canvas 2D 播放器：满足 reference-server 的 main.ts/timeline.ts 注入点、
// render-worker 依赖的 window.__pdoom 契约（ready/errors/still/png）与 #info/#c 播放器 UI。
// 本机没有 ../pdoom-video 参考仓库时，用它在真实服务/渲染进程路径上验证协议与数据流；
// 真实引擎的画面验证仍需在有参考仓库与 GPU 的机器上跑（见 ROADMAP FB-03 备注）。
import { DatabaseSync } from 'node:sqlite';
import { createHash, randomUUID } from 'node:crypto';
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const sha256 = (value) => createHash('sha256').update(value).digest('hex');

function hashTree(dir, prefix = '') {
  return readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    const key = prefix + entry.name;
    return entry.isDirectory() ? hashTree(join(dir, entry.name), key + '/') : [[key, sha256(readFileSync(join(dir, entry.name)))]];
  });
}

export const fixtureScene = (hue) => `// 测试夹具场景：颜色随 hue 参数变化，画面内容随时间 t 变化。
export default class FixtureScene {
  render(f, out) {
    out.fillStyle = 'hsl(${hue}, 48%, 14%)';
    out.fillRect(0, 0, f.W, f.H);
    out.fillStyle = 'hsl(${hue}, 78%, 58%)';
    const bar = Math.round(f.W * (f.p ?? 0));
    out.fillRect(0, f.H * .4, bar, f.H * .2);
    out.fillStyle = '#EEE9DF';
    out.font = '28px monospace';
    out.fillText(\`t=\${Number(f.t ?? 0).toFixed(2)}\`, 24, 48);
  }
}
`;

export function writeFixtureEngine(dir) {
  mkdirSync(join(dir, 'artifacts'), { recursive: true });
  mkdirSync(join(dir, 'exports'), { recursive: true });
  const app = join(dir, 'engine/app');
  mkdirSync(join(app, 'src/scenes'), { recursive: true });
  mkdirSync(join(app, 'src/engine'), { recursive: true });
  writeFileSync(join(app, 'index.html'), `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>fixture engine</title>
<style>body{margin:0;background:#0b0d11;color:#EEE9DF;font:12px monospace}canvas{display:block}</style></head>
<body><canvas id="c" width="1920" height="1080"></canvas><div id="info">0.00 · fixture</div>
<script type="module" src="/src/main.ts"></script></body></html>`);
  writeFileSync(join(app, 'src/engine/gl.ts'), `// 夹具占位：reference-server 注入的 transition-runtime 顶层 import 需要它能解析；cut-only 时不会被调用。
export class FSPass { constructor() { throw new Error('fixture engine has no WebGL'); } }
export const makeRT = () => { throw new Error('fixture engine has no WebGL'); };
`);
  writeFileSync(join(app, 'src/timeline.ts'), `// reference-server 会把 makeTimeline 的返回值替换为注入的镜头表（含 load()）。
export function makeTimeline() { return []; }
`);
  writeFileSync(join(app, 'src/main.ts'), `import { makeTimeline } from '/src/timeline.ts';
const canvas = document.getElementById('c');
const info = document.getElementById('info');
const params = new URLSearchParams(location.search);
const only = params.get('only')?.split(',').filter(Boolean) ?? null;
let entries = makeTimeline();
if (only?.length) { const set = new Set(only); entries = entries.filter((entry) => set.has(entry.id)); }
const loaded = [];
for (const entry of entries) loaded.push({ entry, scene: new (await (await entry.load()).default)({}) });
let current = Number(params.get('t') ?? 0);
let playing = false;
function drawAt(t) {
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#101014';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  const hit = loaded.find(({ entry }) => t >= entry.start && t < entry.end) ?? loaded[loaded.length - 1];
  hit?.scene.render({ t, lt: t - hit.entry.start, p: hit ? (t - hit.entry.start) / (hit.entry.end - hit.entry.start) : 0, W: canvas.width, H: canvas.height }, ctx);
  info.textContent = \`\${current.toFixed(2)} · fixture\`;
}
canvas.addEventListener('click', () => { playing = !playing; });
setInterval(() => { if (playing) { current += 0.25; drawAt(current); } }, 250);
drawAt(current);
window.__pdoom = {
  ready: true, errors: [], error: null,
  async still(t) { drawAt(t); },
  png() { return canvas.toDataURL('image/png').split(',')[1]; },
  async stream({ from, to, fps, ws }) {
    const socket = new WebSocket(ws);
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    const frames = Math.round((to - from) * fps);
    for (let i = 0; i < frames; i++) {
      drawAt(from + i / fps);
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
      socket.send(pixels);
      await new Promise((resolve, reject) => { socket.onmessage = resolve; socket.onerror = reject; });
    }
    socket.close();
  },
};
document.body.classList.add('vg-ready');
`);
  writeFileSync(join(app, 'src/scenes/base.ts'), fixtureScene(18));
  const files = hashTree(join(dir, 'engine'));
  writeFileSync(join(dir, 'engine-manifest.json'), JSON.stringify({ schema: 1, engineHash: sha256(JSON.stringify({ files, dependencies: {} })), dependencies: {}, files }, null, 2));
}

/** 建一个两镜头工程（0–4s / 4–8s，cut 转场由 normalizeProject 补齐），镜头 a 带“火花”元素方案。 */
export function createFixtureProject(projectsRoot, { name = 'fb fixture', engine = true } = {}) {
  const id = randomUUID();
  const dir = join(projectsRoot, id);
  if (engine) writeFixtureEngine(dir);
  else mkdirSync(join(dir, 'engine/app/src/scenes'), { recursive: true }), writeFileSync(join(dir, 'engine/app/src/scenes/base.ts'), fixtureScene(18));
  const element = { id: 'el-spark', name: '火花', quote: 'sparks fly', meaning: '能量的具象', treatment: '橙色粒子', kind: 'entity', lineIndex: 0 };
  const shot = (sid, start, end) => ({ id: sid, title: sid === 'a' ? '火花窗口' : '收束窗口', module: 'base', params: {}, prompt: `intent ${sid}`, start, end, inputRevision: 0, inputToken: randomUUID(), source: 'reference-import', status: 'ready', locked: false });
  const project = {
    id, name, revision: 0, createdAt: Date.now(), updatedAt: Date.now(), engineHash: 'fixture', dependencies: {},
    audio: { name: 'fixture.mp3', hash: 'fixture' }, analysis: { source: 'fixture', note: '测试夹具，无真实分析' },
    song: { song: 'fixture', duration: 8, bpm: 120, lines: [{ lineIndex: 0, text: 'sparks fly tonight', start: 0.5, end: 3.5, words: [{ w: 'sparks', start: 0.5, end: 1.1 }, { w: 'fly', start: 1.1, end: 1.6 }] }] },
    shots: [{ ...shot('a', 0, 4), lyricPlan: { summary: '能量迸发', elements: [element] } }, shot('b', 4, 8)],
    transitions: [{ id: 'tr-fixture', fromShotId: 'a', toShotId: 'b', intent: '夹具硬切', mode: 'cut', duration: 0, easing: 'smooth', direction: 'left', inputRevision: 0, inputToken: 'tr-fixture:0', status: 'ready', locked: false, feedback: [] }],
    output: { fps: 30, width: 1920, height: 1080, samples: 1 },
    credits: 'fixture',
  };
  const db = new DatabaseSync(join(dir, 'project.sqlite'));
  db.exec('CREATE TABLE project(id INTEGER PRIMARY KEY,data TEXT); CREATE TABLE revisions(revision INTEGER,data TEXT,created_at INTEGER); CREATE TABLE jobs(id TEXT PRIMARY KEY,kind TEXT,status TEXT,data TEXT,updated_at INTEGER);');
  db.prepare('INSERT INTO project VALUES(1,?)').run(JSON.stringify(project));
  db.prepare('INSERT INTO revisions VALUES(0,?,?)').run(JSON.stringify(project), Date.now());
  db.close();
  return id;
}
