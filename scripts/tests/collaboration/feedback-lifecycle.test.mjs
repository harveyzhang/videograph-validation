// QA-01 第一切片：人工反馈生命周期多步序列。直接驱动领域存储，不启动服务/浏览器。
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';

const root = mkdtempSync(join(tmpdir(), 'videograph-qa-'));
process.env.VIDEOGRAPH_PROJECTS = root;
const store = await import('../../../src/server/project-store.mjs');
after(() => rmSync(root, { recursive: true, force: true }));

const codeCandidate = 'export default class Scene { render() { return "candidate"; } }';
function fixture() {
  const id = randomUUID(), dir = join(root, id);
  mkdirSync(join(dir, 'engine/app/src/scenes'), { recursive: true });
  writeFileSync(join(dir, 'engine/app/src/scenes/base.ts'), 'export default class Base {}');
  const shot = (id) => ({ id, title: id, module: 'base', params: { keep: true }, prompt: 'original', start: 0, end: 1, inputRevision: 0, inputToken: randomUUID(), source: 'reference-import', status: 'ready', locked: false });
  const p = { id, name: 'qa fixture', revision: 0, createdAt: Date.now(), song: { duration: 1 }, shots: [shot('a'), shot('b')] };
  const db = new DatabaseSync(join(dir, 'project.sqlite'));
  db.exec('CREATE TABLE project(id INTEGER PRIMARY KEY,data TEXT); CREATE TABLE revisions(revision INTEGER PRIMARY KEY,data TEXT,created_at INTEGER); CREATE TABLE jobs(id TEXT PRIMARY KEY,kind TEXT,status TEXT,data TEXT,updated_at INTEGER);');
  db.prepare('INSERT INTO project VALUES(1,?)').run(JSON.stringify(p));
  db.close();
  return id;
}
const shot = (id) => store.readProject(id).shots[0];
const feedbackId = (id) => shot(id).feedback.at(-1).id;
const submit = (id, ids = [], code = codeCandidate, author = 'mcp') => store.submitShotSource(id, 'a', shot(id).inputRevision, code, 'qa', ids, author);
const markValidated = (id) => store.mutateProject(id, undefined, (project) => { const s = project.shots[0]; s.status = 'ready'; s.validation = { samples: 5, inputToken: s.inputToken }; return project; });

test('拒绝后重新响应并接受，整条生命周期保持一致', () => {
  const id = fixture(); store.addShotFeedback(id, 'a', 0, '换掉开场构图'); submit(id, [feedbackId(id)]); markValidated(id);
  store.rejectShotFeedback(id, 'a', shot(id).inputRevision);
  assert.equal(shot(id).module, 'base');
  submit(id, [feedbackId(id)]); markValidated(id);
  store.acceptShotFeedback(id, 'a', shot(id).inputRevision, [feedbackId(id)]);
  const final = shot(id);
  assert.equal(final.source, 'mcp-authored');
  assert.equal(final.feedback[0].status, 'accepted');
  assert.equal(final.feedback[0].codeHash, store.sha256(codeCandidate));
});
test('两次拒绝都完整回到同一基线，且候选源码文件保留可追溯', () => {
  const id = fixture(); store.addShotFeedback(id, 'a', 0, '第一次意见'); submit(id, [], codeCandidate, 'human');
  const candidateModule = shot(id).module;
  store.rejectShotFeedback(id, 'a', shot(id).inputRevision);
  assert.equal(shot(id).source, 'reference-import');
  store.addShotFeedback(id, 'a', shot(id).inputRevision, '第二次意见'); submit(id, [], codeCandidate, 'human');
  store.rejectShotFeedback(id, 'a', shot(id).inputRevision);
  const restored = shot(id);
  assert.equal(restored.module, 'base');
  assert.equal(restored.source, 'reference-import');
  assert.equal(restored.previousVersion.module, candidateModule);
  assert.equal(shot(id).codeHash, undefined);
});
test('接受只认当前候选的响应，拒绝后旧响应不能被沿用', () => {
  const id = fixture(); store.addShotFeedback(id, 'a', 0, '只调参数不改叙事'); submit(id, [feedbackId(id)]); markValidated(id);
  store.rejectShotFeedback(id, 'a', shot(id).inputRevision);
  submit(id, []); markValidated(id);
  assert.throws(() => store.acceptShotFeedback(id, 'a', shot(id).inputRevision, [feedbackId(id)]), /旧版本响应|responded/);
  assert.equal(shot(id).feedback[0].status, 'pending');
});
