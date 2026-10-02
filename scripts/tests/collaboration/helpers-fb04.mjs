// helpers-fb04.mjs — FB-04 专用夹具：带 __pdoom.stream 的 1920×1080 canvas 引擎 + 8 秒两镜头工程。
// 与 scripts/tests/feedback/helpers.mjs 的区别：render-worker 的导出走 window.__pdoom.stream(ws) 逐帧推流，
// 那份夹具只有 still/png，导不通导出；这里补齐 stream，让"导出清单记录新版本"能在秒级工程上真实断言。
// 画面契约：底部 22% 是字幕带（逐词卡拉OK，确定性），中上部一条 hue 色条（agent 改写目标）——两者不重叠。
import { DatabaseSync } from 'node:sqlite';
import { createHash, randomUUID } from 'node:crypto';
import { copyFileSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const sha256 = (value) => createHash('sha256').update(value).digest('hex');
function hashTree(dir, prefix = '') {
  return readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    const key = prefix + entry.name;
    return entry.isDirectory() ? hashTree(join(dir, entry.name), key + '/') : [[key, sha256(readFileSync(join(dir, entry.name)))]];
  });
}

export const microScene = (hue) => `// FB-04 微型夹具场景：色条随 HUE 常量变化；字幕带逐词卡拉OK（确定性，随 song.words）。
const HUE = ${hue};
const WORDS = ${JSON.stringify(MICRO_WORDS)};
export default class MicroScene {
  render(f, out) {
    out.fillStyle = '#101014';
    out.fillRect(0, 0, f.W, f.H);
    out.fillStyle = \`hsl(\${HUE}, 78%, 58%)\`;
    out.fillRect(f.W * .2, f.H * .3, f.W * (.1 + .6 * (f.p ?? 0)), f.H * .16);
    out.fillStyle = '#EEE9DF';
    out.font = '30px monospace';
    out.fillText(\`t=\${Number(f.t ?? 0).toFixed(2)}\`, 24, 48);
    // 字幕带（底部 22%）：当前词橙色，未唱暗、唱完骨白——与参考片卡拉OK同一时间语义
    const bandY = f.H * .86;
    out.textAlign = 'center';
    let x = f.W * .5 - 180;
    for (const word of WORDS) {
      const sung = f.t >= word.end ? 1 : 0;
      const active = f.t >= word.start && f.t < word.end;
      out.fillStyle = active ? '#FF4D12' : sung ? '#EEE9DF' : 'rgba(238,233,223,.32)';
      out.fillText(word.w, x, bandY);
      x += 130;
    }
    out.textAlign = 'left';
  }
}
`;
const MICRO_WORDS = [
  { w: 'alpha', start: 0.6, end: 1.6 },
  { w: 'beta', start: 1.6, end: 2.6 },
  { w: 'gamma', start: 2.6, end: 3.6 },
];

export function writeStreamEngine(dir, referenceBgm) {
  mkdirSync(join(dir, 'artifacts'), { recursive: true });
  mkdirSync(join(dir, 'exports'), { recursive: true });
  const app = join(dir, 'engine/app');
  mkdirSync(join(app, 'src/scenes'), { recursive: true });
  mkdirSync(join(app, 'src/engine'), { recursive: true });
  mkdirSync(join(dir, 'engine/audio'), { recursive: true });
  copyFileSync(referenceBgm, join(dir, 'engine/audio/pdoom.mp3'));
  writeFileSync(join(app, 'index.html'), `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>fb04 stream engine</title>
<style>body{margin:0;background:#101014;color:#EEE9DF;font:12px monospace}canvas{display:block}</style></head>
<body><canvas id="c" width="1920" height="1080"></canvas><div id="info">0.00 · micro</div>
<script type="module" src="/src/main.ts"></script></body></html>`);
  // transition-runtime 的顶层 import 需要这两个导出可解析（cut-only 不会被调用，与 feedback 夹具同款）。
  writeFileSync(join(app, 'src/engine/gl.ts'), `export class FSPass { constructor() { throw new Error('micro engine has no WebGL'); } }\nexport const makeRT = () => { throw new Error('micro engine has no WebGL'); };\n`);
  mkdirSync(join(dir, 'engine/docs'), { recursive: true });
  // readShotSource 会把 engine/docs/ENGINE.md 作为契约返回给 agent；微型引擎只承诺 scene.render(f, out)。
  writeFileSync(join(dir, 'engine/docs/ENGINE.md'), `# Micro engine contract (FB-04 fixture)\n\n- One file per shot: \`app/src/scenes/<module>.ts\`, default export class with \`render(f, out)\`.\n- \`f\`: \`{ t, lt, p, W, H }\` logical 1920x1080; \`out\`: CanvasRenderingContext2D of the frame canvas.\n- Deterministic: output is a pure function of \`f.t\` (no Math.random/Date.now/import).\n`);
  writeFileSync(join(app, 'src/timeline.ts'), `export function makeTimeline() { return []; }\n`);
  writeFileSync(join(app, 'src/main.ts'), `import { makeTimeline } from '/src/timeline.ts';
const canvas = document.getElementById('c');
const info = document.getElementById('info');
const params = new URLSearchParams(location.search);
const only = params.get('only')?.split(',').filter(Boolean) ?? null;
let entries = makeTimeline();
if (only?.length) { const set = new Set(only); entries = entries.filter((entry) => set.has(entry.id)); }
const loaded = [];
for (const entry of entries) loaded.push({ entry, scene: new (await (await entry.load()).default)({}) });
function drawAt(t) {
  const ctx = canvas.getContext('2d');
  const hit = loaded.find(({ entry }) => t >= entry.start && t < entry.end) ?? loaded[loaded.length - 1];
  ctx.fillStyle = '#101014';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  hit?.scene.render({ t, lt: t - hit.entry.start, p: hit ? (t - hit.entry.start) / (hit.entry.end - hit.entry.start) : 0, W: canvas.width, H: canvas.height }, ctx);
  info.textContent = \`\${Number(t).toFixed(2)} · micro\`;
}
drawAt(Number(params.get('t') ?? 0));
window.__pdoom = {
  ready: true, errors: [], error: null,
  async still(t) { drawAt(t); },
  png() { return canvas.toDataURL('image/png').split(',')[1]; },
  // render-worker 导出协议：逐帧渲染 1920×1080 RGBA，经 WebSocket 推给 ffmpeg stdin（vflip 由 worker 侧 vf 补）。
  async stream({ from, to, fps, ws }) {
    const socket = new WebSocket(ws);
    socket.binaryType = 'arraybuffer';
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = () => reject(new Error('ws 连接失败')); });
    const count = Math.round((to - from) * fps);
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    const row = canvas.width * 4;
    const flipped = new Uint8ClampedArray(row * canvas.height);
    for (let i = 0; i < count; i++) {
      drawAt(from + i / fps);
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      for (let y = 0; y < canvas.height; y++) flipped.set(data.subarray((canvas.height - 1 - y) * row, (canvas.height - y) * row), y * row);
      socket.send(flipped.buffer.slice(0));
      while (socket.bufferedAmount > row * canvas.height * 4) await new Promise((resolve) => setTimeout(resolve, 2));
    }
  },
};
`);
  writeFileSync(join(app, 'src/scenes/base.ts'), microScene(18));
  const files = hashTree(join(dir, 'engine'));
  writeFileSync(join(dir, 'engine-manifest.json'), JSON.stringify({ schema: 1, engineHash: sha256(JSON.stringify({ files, dependencies: {} })), dependencies: {}, files }, null, 2));
}

/** 8 秒两镜头工程（0–4 / 4–8），镜头 a 带“歌词”元素方案与词级歌词（字幕带断言用）。 */
export function createStreamProject(projectsRoot, referenceBgm) {
  const id = randomUUID();
  const dir = join(projectsRoot, id);
  writeStreamEngine(dir, referenceBgm);
  const element = { id: 'el-alpha', name: '起点', quote: 'alpha', meaning: '开始', treatment: '色条推进', kind: 'action', lineIndex: 0 };
  const shot = (sid, start, end) => ({ id: sid, title: sid === 'a' ? '色条窗口' : '收束窗口', module: 'base', params: {}, prompt: `intent ${sid}`, start, end, inputRevision: 0, inputToken: randomUUID(), source: 'reference-import', status: 'ready', locked: false });
  const project = {
    id, name: 'fb04 micro', revision: 0, createdAt: Date.now(), updatedAt: Date.now(), engineHash: 'micro', dependencies: {},
    audio: { name: 'pdoom.mp3', hash: sha256(readFileSync(referenceBgm)) },
    analysis: { source: 'fixture', note: 'FB-04 导出夹具' },
    song: { song: 'micro', duration: 8, bpm: 120, lines: [{ lineIndex: 0, text: 'alpha beta gamma', start: 0.6, end: 3.6, words: MICRO_WORDS.map((word) => ({ ...word })) }] },
    shots: [{ ...shot('a', 0, 4), lyricPlan: { summary: '起点推进', elements: [element] } }, shot('b', 4, 8)],
    transitions: [{ id: 'tr-micro', fromShotId: 'a', toShotId: 'b', intent: '夹具硬切', mode: 'cut', duration: 0, easing: 'smooth', direction: 'left', inputRevision: 0, inputToken: 'tr-micro:0', status: 'ready', locked: false, feedback: [] }],
    output: { fps: 24, width: 1920, height: 1080, samples: 1 },
    credits: 'fb04 micro fixture',
  };
  const db = new DatabaseSync(join(dir, 'project.sqlite'));
  db.exec('CREATE TABLE project(id INTEGER PRIMARY KEY,data TEXT); CREATE TABLE revisions(revision INTEGER,data TEXT,created_at INTEGER); CREATE TABLE jobs(id TEXT PRIMARY KEY,kind TEXT,status TEXT,data TEXT,updated_at INTEGER);');
  db.prepare('INSERT INTO project VALUES(1,?)').run(JSON.stringify(project));
  db.prepare('INSERT INTO revisions VALUES(0,?,?)').run(JSON.stringify(project), Date.now());
  db.close();
  return id;
}
