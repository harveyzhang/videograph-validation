// 轻量领域测试：使用临时 SQLite 与假源码文件，不启动服务、浏览器或 GPU。
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';

const root = mkdtempSync(join(tmpdir(), 'videograph-domain-'));
process.env.VIDEOGRAPH_PROJECTS = root;
const store = await import('../src/server/project-store.mjs');
after(() => rmSync(root, { recursive: true, force: true }));
const codeA = 'export default class Scene { render() { return "candidate A"; } }';
const codeB = 'export default class Scene { render() { return "candidate B"; } }';
function fixture() {
  const id = randomUUID(), dir = join(root, id);
  mkdirSync(join(dir, 'engine/app/src/scenes'), { recursive: true });
  writeFileSync(join(dir, 'engine/app/src/scenes/base.ts'), 'export default class Base {}');
  const shot = (id) => ({ id, title: id, module: 'base', params: { value: 1 }, prompt: 'original intent', start: 0, end: 1, inputRevision: 0, inputToken: randomUUID(), source: 'reference-import', status: 'ready', locked: false });
  const p = { id, name: 'unit fixture', revision: 0, createdAt: Date.now(), song: { duration: 1 }, shots: [shot('a'), shot('b')] };
  const db = new DatabaseSync(join(dir, 'project.sqlite'));
  db.exec('CREATE TABLE project(id INTEGER PRIMARY KEY,data TEXT); CREATE TABLE revisions(revision INTEGER PRIMARY KEY,data TEXT,created_at INTEGER); CREATE TABLE jobs(id TEXT PRIMARY KEY,kind TEXT,status TEXT,data TEXT,updated_at INTEGER);');
  db.prepare('INSERT INTO project VALUES(1,?)').run(JSON.stringify(p));
  db.prepare('INSERT INTO revisions VALUES(0,?,?)').run(JSON.stringify(p), Date.now()); db.close();
  return id;
}
const first = (id) => store.readProject(id).shots[0];
function add(id) { store.addShotFeedback(id, 'a', first(id).inputRevision, '只改颜色，保留歌词同步'); return first(id).feedback.at(-1).id; }
function submit(id, ids = [], code = codeA, author = 'mcp') { return store.submitShotSource(id, 'a', first(id).inputRevision, code, 'test', ids, author); }
function validateCurrent(id) {
  store.mutateProject(id, undefined, (project) => { const shot = project.shots[0]; shot.status = 'ready'; shot.validation = { samples: 5, inputToken: shot.inputToken }; return project; });
}

test('feedback retains intent and affects only its target', () => {
  const id = fixture(), original = store.readProject(id), note = add(id), p = store.readProject(id);
  assert.equal(p.shots[0].prompt, original.shots[0].prompt);
  assert.equal(p.shots[0].feedback[0].id, note);
  assert.equal(p.shots[0].status, 'needs-generation');
  assert.deepEqual(p.shots[1], original.shots[1]);
  assert.equal(p.shots[0].reviewBaseline.module, 'base');
});
test('stale input cannot submit or add feedback', () => {
  const id = fixture(); add(id);
  assert.throws(() => store.submitShotSource(id, 'a', 0, codeA), /版本已改变/);
  assert.throws(() => store.addShotFeedback(id, 'a', 0, 'late'), /版本已改变/);
  assert.deepEqual(readdirSync(join(root, id, 'engine/app/src/scenes')), ['base.ts']);
});
test('locking blocks feedback and code writes', () => {
  const id = fixture(); store.updateShot(id, 'a', 0, { locked: true });
  assert.throws(() => add(id), /锁定/);
  assert.throws(() => submit(id), /锁定/);
});
test('technical validation does not automatically accept human feedback', () => {
  const id = fixture(), note = add(id); submit(id, [note]);
  assert.equal(first(id).feedback[0].status, 'responded');
  assert.throws(() => store.acceptShotFeedback(id, 'a', first(id).inputRevision, [note]), /先验证/);
  validateCurrent(id);
  assert.equal(first(id).feedback[0].status, 'responded');
  store.acceptShotFeedback(id, 'a', first(id).inputRevision, [note]);
  assert.equal(first(id).feedback[0].status, 'accepted');
});
test('new code invalidates a previous feedback response unless explicitly re-addressed', () => {
  const id = fixture(), note = add(id); submit(id, [note]); submit(id, [], codeB); validateCurrent(id);
  assert.equal(first(id).feedback[0].status, 'pending');
  assert.throws(() => store.acceptShotFeedback(id, 'a', first(id).inputRevision, [note]), /旧版本响应/);
});
test('parameter changes invalidate response identity even if source code is unchanged', () => {
  const id = fixture(), note = add(id); submit(id, [note]);
  store.updateShot(id, 'a', first(id).inputRevision, { params: { value: 2 } }); validateCurrent(id);
  assert.equal(first(id).feedback[0].status, 'pending');
  assert.throws(() => store.acceptShotFeedback(id, 'a', first(id).inputRevision, [note]), /旧版本响应/);
});
test('re-addressing binds feedback to the latest candidate token and hash', () => {
  const id = fixture(), note = add(id); submit(id, [note]); submit(id, [note], codeB); validateCurrent(id);
  const shot = first(id);
  assert.equal(shot.feedback[0].codeHash, store.sha256(codeB));
  assert.equal(shot.feedback[0].responseInputToken, shot.inputToken);
  store.acceptShotFeedback(id, 'a', shot.inputRevision, [note]);
  assert.equal(first(id).feedback[0].acceptedInputRevision, shot.inputRevision);
});
test('reject restores the baseline, preserves feedback, and never changes other shots', () => {
  const id = fixture(), before = store.readProject(id), note = add(id); submit(id, [note]);
  const candidate = first(id).module;
  store.rejectShotFeedback(id, 'a', first(id).inputRevision);
  const p = store.readProject(id);
  assert.equal(p.shots[0].module, 'base');
  assert.equal(p.shots[0].feedback[0].status, 'pending');
  assert.equal(p.shots[0].status, 'needs-generation');
  assert.equal(p.shots[0].previousVersion.module, candidate);
  assert.equal(p.shots[0].codeHash, undefined);
  assert.equal(p.shots[0].summary, undefined);
  assert.equal(p.shots[0].source, 'reference-import');
  assert.deepEqual(p.shots[0].params, before.shots[0].params);
  assert.equal(p.shots[0].validation, undefined);
  assert.deepEqual(p.shots[1], before.shots[1]);
  assert.equal(readFileSync(join(root, id, `engine/app/src/scenes/${candidate}.ts`), 'utf8'), codeA);
});
test('manual source edits are not labelled as MCP-authored', () => {
  const id = fixture(); submit(id, [], codeA, 'human');
  assert.equal(first(id).source, 'human-authored');
});
test('same source shares an immutable module and never overwrites modified files', () => {
  const id = fixture(); submit(id);
  const module = first(id).module;
  store.submitShotSource(id, 'b', 0, codeA);
  assert.equal(store.readProject(id).shots[1].module, module);
  const path = join(root, id, `engine/app/src/scenes/${module}.ts`);
  writeFileSync(path, 'externally changed fixture');
  assert.throws(() => submit(id), /外部修改/);
});
test('renaming metadata does not invalidate a validated image', () => {
  const id = fixture(); validateCurrent(id); const before = first(id);
  store.updateShot(id, 'a', before.inputRevision, { title: 'new title' });
  assert.equal(first(id).inputToken, before.inputToken);
  assert.deepEqual(first(id).validation, before.validation);
});
test('adding a new opinion resets earlier responses but retains the original baseline', () => {
  const id = fixture(), note = add(id); submit(id, [note]); add(id);
  assert.equal(first(id).feedback[0].status, 'pending');
  assert.equal(first(id).reviewBaseline.module, 'base');
});
test('a submission only marks the feedback it explicitly addresses', () => {
  const id = fixture(), firstNote = add(id), secondNote = add(id); submit(id, [firstNote]);
  const shot = first(id);
  assert.equal(shot.feedback.find((note) => note.id === firstNote).status, 'responded');
  assert.equal(shot.feedback.find((note) => note.id === secondNote).status, 'pending');
});
