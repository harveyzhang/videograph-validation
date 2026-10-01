// FB-01 HTTP 路由冒烟：独立端口 + 临时 projects 目录 + 独立令牌，不触碰正在运行的实例与真实工程。
import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const productRoot = fileURLToPath(new URL('../../..', import.meta.url));
const root = mkdtempSync(join(tmpdir(), 'videograph-fb01-http-'));
const projects = join(root, 'projects'), tokenFile = join(root, 'service-token');
const port = 5391 + Math.floor(Math.random() * 300);
const base = `http://127.0.0.1:${port}`;
let child, token, projectId;

function fixture() {
  const id = randomUUID(), dir = join(projects, id);
  mkdirSync(join(dir, 'engine/app/src/scenes'), { recursive: true });
  writeFileSync(join(dir, 'engine/app/src/scenes/base.ts'), 'export default class Base {}');
  const shot = (sid, start, end) => ({ id: sid, title: sid, module: 'base', params: {}, prompt: `intent ${sid}`, start, end, inputRevision: 0, inputToken: randomUUID(), source: 'reference-import', status: 'ready', locked: false });
  const p = { id, name: 'http fixture', revision: 0, createdAt: Date.now(), song: { duration: 8 }, output: { fps: 30 }, shots: [shot('a', 0, 4), shot('b', 4, 8)] };
  const db = new DatabaseSync(join(dir, 'project.sqlite'));
  db.exec('CREATE TABLE project(id INTEGER PRIMARY KEY,data TEXT); CREATE TABLE revisions(revision INTEGER PRIMARY KEY,data TEXT,created_at INTEGER); CREATE TABLE jobs(id TEXT PRIMARY KEY,kind TEXT,status TEXT,data TEXT,updated_at INTEGER);');
  db.prepare('INSERT INTO project VALUES(1,?)').run(JSON.stringify(p));
  db.prepare('INSERT INTO revisions VALUES(0,?,?)').run(JSON.stringify(p), Date.now()); db.close();
  return id;
}
async function call(path, body, auth = true) {
  const response = await fetch(base + path, { method: body === undefined ? 'GET' : 'POST', headers: { 'content-type': 'application/json', ...(auth ? { authorization: `Bearer ${token}` } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  return { status: response.status, data: await response.json() };
}

before(async () => {
  mkdirSync(projects, { recursive: true });
  projectId = fixture();
  child = spawn(process.execPath, ['--no-warnings', 'src/server/index.mjs'], { cwd: productRoot, stdio: 'pipe',
    env: { ...process.env, VIDEOGRAPH_SERVICE_PORT: String(port), VIDEOGRAPH_PROJECTS: projects, VIDEOGRAPH_SERVICE_TOKEN_FILE: tokenFile } });
  for (let i = 0; i < 100 && !existsSync(tokenFile); i++) await new Promise((resolve) => setTimeout(resolve, 100));
  token = readFileSync(tokenFile, 'utf8');
});
after(() => { child?.kill(); rmSync(root, { recursive: true, force: true }); });

test('HTTP：带锚点意见 → 收件箱 → 提问 → 回复 → 逐条响应', async () => {
  assert.equal((await call('/feedback', undefined, false)).status, 401, '收件箱需要服务令牌');
  assert.equal((await call(`/projects/${projectId}/shots/a/feedback`, { expectedInputRevision: 0, text: 'x', anchor: { t: 99 } })).status, 400);
  const added = await call(`/projects/${projectId}/shots/a/feedback`, { expectedInputRevision: 0, text: '火花再亮', anchor: { t: 1.5, aspect: 'color' }, preserve: ['歌词时序'] });
  assert.equal(added.status, 200, JSON.stringify(added.data));
  const note = added.data.shots[0].feedback[0];
  assert.deepEqual(note.anchor, { t: 1.5, aspect: 'color' });

  const inbox = await call(`/feedback?projectId=${projectId}`);
  assert.equal(inbox.data.count, 1); assert.equal(inbox.data.items[0].note.id, note.id);
  assert.equal((await call('/feedback?projectId=../x')).status, 400);

  const asked = await call(`/projects/${projectId}/shots/a/feedback/${note.id}/ask`, { question: '亮到什么程度？' });
  assert.equal(asked.data.shots[0].feedback[0].status, 'needs-clarification');
  assert.equal((await call(`/projects/${projectId}/shots/a/feedback/${note.id}/reply`, { text: 'x', author: 'mcp' })).status, 403);
  const replied = await call(`/projects/${projectId}/shots/a/feedback/${note.id}/reply`, { text: '和信号橙一样亮' });
  assert.equal(replied.data.shots[0].feedback[0].status, 'pending');

  const revision = replied.data.shots[0].inputRevision;
  const submitted = await call(`/projects/${projectId}/shots/a/source`, { expectedInputRevision: revision, code: 'export default class Scene { render() { return 1; } }', summary: 't', author: 'mcp', feedbackResponses: [{ feedbackId: note.id, how: '提亮到 signal' }] });
  assert.equal(submitted.status, 200, JSON.stringify(submitted.data));
  assert.equal(submitted.data.shots[0].feedback[0].response.how, '提亮到 signal');
  assert.equal((await call(`/feedback?projectId=${projectId}&status=responded`)).data.count, 1);
});
