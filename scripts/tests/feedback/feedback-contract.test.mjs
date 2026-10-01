// FB-01 意见数据契约：锚点、保留项、逐条响应、澄清对话、收件箱。临时 SQLite，不启服务/浏览器/GPU。
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';

const root = mkdtempSync(join(tmpdir(), 'videograph-fb01-'));
process.env.VIDEOGRAPH_PROJECTS = root;
const store = await import('../../../src/server/project-store.mjs');
after(() => rmSync(root, { recursive: true, force: true }));

const codeA = 'export default class Scene { render() { return "candidate A"; } }';
const codeB = 'export default class Scene { render() { return "candidate B"; } }';
const element = { id: 'el-spark', name: '火花', quote: 'sparks', meaning: 'm', treatment: 't', kind: 'entity', lineIndex: 0 };
function fixture() {
  const id = randomUUID(), dir = join(root, id);
  mkdirSync(join(dir, 'engine/app/src/scenes'), { recursive: true });
  writeFileSync(join(dir, 'engine/app/src/scenes/base.ts'), 'export default class Base {}');
  const shot = (sid, start, end) => ({ id: sid, title: sid, module: 'base', params: {}, prompt: `intent ${sid}`, start, end, inputRevision: 0, inputToken: randomUUID(), source: 'reference-import', status: 'ready', locked: false });
  const a = { ...shot('a', 0, 4), lyricPlan: { summary: 's', elements: [element] } };
  const p = { id, name: 'fb01 fixture', revision: 0, createdAt: Date.now(), song: { duration: 8 }, output: { fps: 30 }, shots: [a, shot('b', 4, 8)] };
  const db = new DatabaseSync(join(dir, 'project.sqlite'));
  db.exec('CREATE TABLE project(id INTEGER PRIMARY KEY,data TEXT); CREATE TABLE revisions(revision INTEGER PRIMARY KEY,data TEXT,created_at INTEGER); CREATE TABLE jobs(id TEXT PRIMARY KEY,kind TEXT,status TEXT,data TEXT,updated_at INTEGER);');
  db.prepare('INSERT INTO project VALUES(1,?)').run(JSON.stringify(p));
  db.prepare('INSERT INTO revisions VALUES(0,?,?)').run(JSON.stringify(p), Date.now()); db.close();
  return id;
}
const shotA = (id) => store.readProject(id).shots[0];
const add = (id, input) => { store.addShotFeedback(id, 'a', shotA(id).inputRevision, input); return shotA(id).feedback.at(-1); };
const submit = (id, opts = {}) => store.submitShotSource(id, 'a', shotA(id).inputRevision, opts.code ?? codeA, 'test', opts.ids ?? [], opts.author ?? 'mcp', opts.responses ?? []);
const validate = (id) => store.mutateProject(id, undefined, (p) => { const s = p.shots[0]; s.status = 'ready'; s.validation = { samples: 5, inputToken: s.inputToken, thumb: 'k.png' }; return p; });

test('锚点与保留项被校验并保存；旧格式文本意见仍可用', () => {
  const id = fixture();
  const legacy = add(id, '只改颜色');
  assert.equal(legacy.text, '只改颜色'); assert.equal(legacy.author, 'human'); assert.deepEqual(legacy.thread, []);
  assert.equal(legacy.anchor, undefined);
  const rich = add(id, { text: '火花再亮一点', anchor: { t: 2.5, range: { start: 2, end: 3 }, lyricElementId: 'el-spark', region: { x: .1, y: .2, w: .3, h: .4 }, aspect: 'color' }, preserve: ['歌词时序', '镜头时长'] });
  assert.deepEqual(rich.anchor, { t: 2.5, range: { start: 2, end: 3 }, lyricElementId: 'el-spark', region: { x: .1, y: .2, w: .3, h: .4 }, aspect: 'color' });
  assert.deepEqual(rich.preserve, ['歌词时序', '镜头时长']);
  assert.equal(rich.status, 'pending');
});

test('越界或无效锚点被拒绝，且不改变工程', () => {
  const id = fixture(), before = store.readProject(id).revision;
  for (const [anchor, pattern] of [
    [{ t: 5 }, /时间窗/], [{ range: { start: 3, end: 2 } }, /区间/], [{ lyricElementId: 'missing' }, /歌词元素/],
    [{ region: { x: .8, y: 0, w: .5, h: .5 } }, /归一化/], [{ aspect: 'vibe' }, /aspect/], [{}, /空对象/], [{ foo: 1 }, /只支持/],
  ]) assert.throws(() => add(id, { text: 'x', anchor }), pattern);
  assert.throws(() => add(id, { text: 'x', preserve: ['a', 'a'] }), /重复/);
  assert.throws(() => add(id, { text: 'x', preserve: Array(13).fill(0).map((_, i) => `p${i}`) }), /最多/);
  assert.throws(() => add(id, { text: 'x', author: 'robot' }), /作者/);
  assert.equal(store.readProject(id).revision, before);
});

test('逐条响应：partial 需要说明，响应绑定版本，接受仍要人', () => {
  const id = fixture(), n1 = add(id, '火花再亮'), n2 = add(id, { text: '字更大', anchor: { aspect: 'typography' } });
  assert.throws(() => submit(id, { responses: [{ feedbackId: n2.id, outcome: 'partial' }] }), /部分响应/);
  assert.throws(() => submit(id, { responses: [{ feedbackId: n1.id }, { feedbackId: n1.id }] }), /重复/);
  assert.throws(() => submit(id, { responses: [{ feedbackId: 'nope' }] }), /反馈 ID/);
  submit(id, { responses: [{ feedbackId: n1.id, how: '火花亮度 ×1.6' }, { feedbackId: n2.id, outcome: 'partial', how: '字号放大，字距未调' }] });
  const [r1, r2] = shotA(id).feedback;
  assert.equal(r1.status, 'responded'); assert.equal(r1.response.how, '火花亮度 ×1.6'); assert.equal(r1.response.outcome, 'addressed'); assert.equal(r1.response.by, 'mcp');
  assert.equal(r2.response.outcome, 'partial'); assert.equal(r1.response.codeHash, shotA(id).codeHash);
  assert.throws(() => store.acceptShotFeedback(id, 'a', shotA(id).inputRevision, [n1.id]), /先验证/);
  validate(id);
  store.acceptShotFeedback(id, 'a', shotA(id).inputRevision, [n1.id, n2.id]);
  assert.ok(shotA(id).feedback.every((note) => note.status === 'accepted'));
});

test('旧参数 addressedFeedbackIds 兼容；再次提交使旧响应失效并留下历史', () => {
  const id = fixture(), note = add(id, '更暗');
  submit(id, { ids: [note.id] });
  assert.equal(shotA(id).feedback[0].response.how, '');
  submit(id, { code: codeB });
  const after = shotA(id).feedback[0];
  assert.equal(after.status, 'pending'); assert.equal(after.response, undefined);
  assert.equal(after.responseHistory.length, 1); assert.ok(after.responseHistory[0].invalidatedAt);
});

test('提问 → 人回复 → 响应 → 接受；等待澄清时不能标记响应，只有人能回复', () => {
  const id = fixture(), note = add(id, '是不是有点太素了'), rev = shotA(id).inputRevision;
  store.askFeedback(id, 'shot', 'a', note.id, '是指加转场，还是镜头内元素更多？');
  let current = shotA(id).feedback[0];
  assert.equal(current.status, 'needs-clarification'); assert.equal(current.thread[0].by, 'mcp');
  assert.equal(shotA(id).inputRevision, rev, '提问不改变输入版本');
  assert.throws(() => submit(id, { ids: [note.id] }), /等待人回复/);
  assert.throws(() => store.replyFeedback(id, 'shot', 'a', note.id, '加元素', 'mcp'), /只能由人/);
  store.replyFeedback(id, 'shot', 'a', note.id, '镜头内加元素，转场不动');
  current = shotA(id).feedback[0];
  assert.equal(current.status, 'pending'); assert.deepEqual(current.thread.map((entry) => entry.kind), ['question', 'reply']);
  assert.throws(() => store.replyFeedback(id, 'shot', 'a', note.id, '再说一次'), /没有待回复/);
  submit(id, { responses: [{ feedbackId: note.id, how: '加入档案碎片层' }] });
  assert.throws(() => store.askFeedback(id, 'shot', 'a', note.id, '还要更多吗？'), /已有候选响应/);
  validate(id); store.acceptShotFeedback(id, 'a', shotA(id).inputRevision, [note.id]);
  assert.throws(() => store.askFeedback(id, 'shot', 'a', note.id, 'late'), /已被接受/);
});

test('转场意见支持锚点（前后镜头合并窗口）与逐条响应', () => {
  const id = fixture(), tr = store.readProject(id).transitions[0];
  assert.throws(() => store.addShotFeedback(id, tr.id, tr.inputRevision, { text: 'x', anchor: { t: 9 } }, 'transition'), /时间窗/);
  store.addShotFeedback(id, tr.id, tr.inputRevision, { text: '换成溶解', anchor: { t: 4.1, aspect: 'motion', lyricElementId: 'el-spark' } }, 'transition');
  const current = store.readProject(id).transitions[0], note = current.feedback[0];
  assert.equal(note.anchor.t, 4.1);
  store.configureTransition(id, tr.id, current.inputRevision, { mode: 'dissolve', duration: .5 }, [], 'mcp', [{ feedbackId: note.id, how: '0.5s 溶解' }]);
  const done = store.readProject(id).transitions[0].feedback[0];
  assert.equal(done.status, 'responded'); assert.equal(done.response.how, '0.5s 溶解');
});

test('收件箱：汇总镜头和转场、按状态筛选、给出下一步、不泄露令牌与路径', () => {
  const id = fixture(), other = fixture();
  const n1 = add(id, { text: '火花再亮', anchor: { t: 1 }, preserve: ['歌词时序'] });
  const tr = store.readProject(id).transitions[0];
  store.addShotFeedback(id, tr.id, tr.inputRevision, '加转场', 'transition');
  store.addShotFeedback(other, 'a', 0, '其他工程意见');
  const inbox = store.feedbackInbox({ projectId: id });
  assert.equal(inbox.count, 2);
  const shotItem = inbox.items.find((item) => item.targetKind === 'shot');
  assert.equal(shotItem.note.id, n1.id); assert.equal(shotItem.title, 'a'); assert.deepEqual(shotItem.window, { start: 0, end: 4 });
  assert.equal(shotItem.intent, 'intent a'); assert.equal(shotItem.lyricPlanSummary, 's'); assert.equal(shotItem.hasBaseline, true);
  assert.deepEqual(shotItem.note.preserve, ['歌词时序']); assert.match(shotItem.nextStep, /project_shot_submit/);
  assert.match(inbox.items.find((item) => item.targetKind === 'transition').nextStep, /project_transition_configure/);
  assert.ok(store.feedbackInbox({}).count >= 3, '省略 projectId 时汇总所有工程');
  store.askFeedback(id, 'shot', 'a', n1.id, '多亮？');
  assert.equal(store.feedbackInbox({ projectId: id, status: 'needs-clarification' }).count, 1);
  assert.match(store.feedbackInbox({ projectId: id, status: 'needs-clarification' }).items[0].nextStep, /等待回复/);
  assert.throws(() => store.feedbackInbox({ projectId: id, status: 'bogus' }), /status/);
  const text = JSON.stringify(store.feedbackInbox({}));
  assert.doesNotMatch(text, /inputToken/); assert.ok(!text.includes(root), '不含本机工程目录');
  store.updateShot(id, 'a', shotA(id).inputRevision, { locked: true });
  assert.match(store.feedbackInbox({ projectId: id, status: 'needs-clarification' }).items[0].nextStep, /锁定/);
});

test('未接受（含等待澄清）的意见仍拦截导出前置条件', () => {
  const id = fixture(), note = add(id, '再改改');
  store.askFeedback(id, 'shot', 'a', note.id, '改哪里？');
  const unaccepted = store.readProject(id).shots.some((shot) => (shot.feedback ?? []).some((entry) => entry.status !== 'accepted'));
  assert.equal(unaccepted, true);
});
