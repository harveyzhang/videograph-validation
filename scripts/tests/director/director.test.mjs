import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';
import { createFixtureProject, fixtureScene } from '../feedback/helpers.mjs';

const root = mkdtempSync(join(tmpdir(), 'vg-director-'));
process.env.VIDEOGRAPH_PROJECTS = root;
const store = await import('../../../src/server/project-store.mjs');
const director = await import('../../../src/server/director.mjs');
test.after(() => rmSync(root, { recursive: true, force: true }));
function fixture() {
  const id = createFixtureProject(root);
  store.mutateProject(id, undefined, (p) => {
    p.song.sections = [{ name: 'intro', start: 0, end: 4 }, { name: 'verse', start: 4, end: 8 }];
    p.song.beats = [0, 1, 2, 3, 4, 5, 6, 7];
    for (const s of p.shots) s.validation = { inputToken: s.inputToken, samples: 5 };
    return p;
  });
  return id;
}
const direction = () => ({ brief: { intent: 'A spark becomes a signal', audience: 'music listeners', mustKeep: ['music'], mustAvoid: ['flashing'] }, style: { medium: 'paper', palette: ['#121212', '#eeeeee'], typography: 'mono', composition: 'one subject', motion: 'beat pulse', motif: 'spark' }, rhythm: { sections: [{ sectionIndex: 0, energy: 2, intent: 'prepare' }, { sectionIndex: 1, energy: 4, intent: 'release' }], accents: [{ beatIndex: 4, intent: 'reveal' }] }, shots: ['a', 'b'].map((shotId) => ({ shotId, subject: 'paper', action: 'fold', entrance: 'line', exit: 'square' })), maxRepairs: 2 });
function attach(id) { return director.submitDirector(id, store.readProject(id).revision, direction()); }
function apply(id, action) {
  const claimed = director.claimDirector(id, action.id, 'test', 900);
  const p = store.readProject(id);
  if (action.kind === 'generate') {
    const s = p.shots.find((s) => s.id === action.targetId);
    store.submitShotSource(id, s.id, s.inputRevision, fixtureScene(25), 'director', [], 'mcp', [], claimed.operation.attemptToken);
  } else {
    const t = p.transitions.find((t) => t.id === action.targetId);
    store.configureTransition(id, t.id, t.inputRevision, { mode: 'cut', duration: 0 }, [], 'mcp', [], claimed.operation.attemptToken);
  }
  director.completeDirector(id, action.id, claimed.operation.attemptToken);
  return claimed;
}
function markTechnical(id) {
  store.mutateProject(id, undefined, (p) => {
    for (const s of p.shots) { s.status = 'ready'; s.validation = { inputToken: s.inputToken, samples: 5 }; }
    for (const t of p.transitions) { t.status = 'ready'; t.validation = { inputToken: t.inputToken, leftInputToken: p.shots.find((s) => s.id === t.fromShotId).inputToken, rightInputToken: p.shots.find((s) => s.id === t.toShotId).inputToken }; }
    return p;
  });
}
function evidence(id) {
  const p = store.readProject(id), result = [];
  const add = (kind, shotId) => {
    const bytes = Buffer.from(`test image ${randomUUID()}`);
    const file = `artifacts/${store.sha256(bytes)}.png`;
    writeFileSync(join(store.projectDir(id), file), bytes);
    const job = { id: randomUUID(), projectId: id, kind, status: 'done', input: { project: p, ...(shotId ? { shotId } : {}), ae: { start: 0, end: 8 } }, result: kind === 'stills' ? { stills: { images: [{ file, t: 1 }], times: [1] } } : { images: [{ file }], times: kind === 'filmstrip' ? [1] : undefined } };
    job.result.stills ? job.result.stills.images[0].contentHash = store.sha256(bytes) : job.result.images[0].contentHash = store.sha256(bytes);
    store.saveJob(id, job); result.push({ jobId: job.id, file, observation: 'actual frame observed' });
  };
  for (const s of p.shots) { add('stills', s.id); add('filmstrip', s.id); }
  add('contact-sheet'); add('rhythm'); return result;
}
const review = (evidence) => ({ summary: 'Reviewed actual images', assessments: Object.fromEntries(['composition', 'hierarchy', 'readability', 'semantics', 'rhythm', 'consistency', 'originality'].map((k) => [k, 'Checked with sampled frames'])), evidence, issues: [], protect: ['music timing'] });

test('direction persists, rejects stale revision and invalid anchors', () => {
  const id = fixture(), initial = store.readProject(id);
  const p = attach(id);
  assert.equal(p.director.version, 1);
  assert.equal(p.director.rhythm.accents[0].t, 4);
  assert.throws(() => director.submitDirector(id, initial.revision, direction()), /更新/);
  const invalid = direction(); invalid.rhythm.accents = [{ beatIndex: 999, intent: 'bad' }];
  assert.throws(() => director.submitDirector(id, p.revision, invalid), /beatIndex/);
  assert.equal(store.readProject(id).director.version, 1);
});

test('claim competes safely, renews same token and rejects false completion', () => {
  const id = fixture(); attach(id);
  const item = director.getDirector(id).actions.find((a) => a.targetId === 'a');
  const first = director.claimDirector(id, item.id, 'one');
  assert.equal(director.claimDirector(id, item.id, 'one').operation.attemptToken, first.operation.attemptToken);
  assert.throws(() => director.claimDirector(id, item.id, 'two'), /另一/);
  assert.throws(() => director.completeDirector(id, item.id, first.operation.attemptToken), /凭据/);
  assert.throws(() => director.completeDirector(id, item.id, 'wrong'), /token/);
});

test('claimed preparation can update lyric brief then commit code; completion is idempotent', () => {
  const id = fixture(); attach(id);
  const item = director.getDirector(id).actions.find((a) => a.targetId === 'a');
  const c = director.claimDirector(id, item.id, 'one');
  const p = store.updateShot(id, 'a', 0, { prompt: 'new scene' }, c.operation.attemptToken);
  assert.throws(() => director.completeDirector(id, item.id, c.operation.attemptToken), /凭据/);
  store.submitShotSource(id, 'a', p.shots[0].inputRevision, fixtureScene(42), '', [], 'mcp', [], c.operation.attemptToken);
  director.completeDirector(id, item.id, c.operation.attemptToken);
  assert.equal(director.completeDirector(id, item.id, c.operation.attemptToken).idempotent, true);
  assert.equal(store.readProject(id).director.appliedShots.a, 1);
});

test('external edit and expired lease reject claimed writes', () => {
  const id = fixture(); attach(id);
  const item = director.getDirector(id).actions.find((a) => a.targetId === 'a');
  const c = director.claimDirector(id, item.id, 'one');
  const p = store.updateShot(id, 'a', 0, { params: { changed: true } });
  assert.throws(() => store.submitShotSource(id, 'a', p.shots[0].inputRevision, fixtureScene(1), '', [], 'mcp', [], c.operation.attemptToken), /基线/);
  store.mutateProject(id, undefined, (p) => { p.director.operations[item.id].leaseExpiresAt = 0; return p; });
  assert.throws(() => store.submitShotSource(id, 'a', p.shots[0].inputRevision, fixtureScene(1), '', [], 'mcp', [], c.operation.attemptToken), /租约/);
});

test('operation completes against actual validation job, not a made-up done flag', () => {
  const id = fixture(); attach(id);
  for (;;) {
    const item = director.getDirector(id).actions.find((a) => ['generate', 'transition'].includes(a.kind));
    if (!item) break;
    apply(id, item);
  }
  const item = director.getDirector(id).actions.find((a) => a.kind === 'validate');
  const c = director.claimDirector(id, item.id, 'one');
  assert.throws(() => director.completeDirector(id, item.id, c.operation.attemptToken), /验证/);
  markTechnical(id);
  const job = { id: randomUUID(), projectId: id, kind: 'validate', status: 'done', input: { project: store.readProject(id), shotId: item.targetId }, result: {} };
  store.saveJob(id, job);
  director.completeDirector(id, item.id, c.operation.attemptToken, { jobIds: [job.id] });
});

test('review needs current real artifacts, coverage, technical readiness and version-bound evidence', () => {
  const id = fixture(); attach(id);
  for (;;) {
    const item = director.getDirector(id).actions.find((a) => ['generate', 'transition'].includes(a.kind));
    if (!item) break;
    apply(id, item);
  }
  markTechnical(id);
  const ev = evidence(id);
  const bad = review(structuredClone(ev)); bad.evidence[0] = { ...ev[0], file: 'artifacts/' + 'f'.repeat(64) + '.png' };
  assert.throws(() => director.submitReview(id, store.readProject(id).revision, bad), /文件/);
  assert.throws(() => director.submitReview(id, store.readProject(id).revision, review(ev.slice(1))), /stills/);
  director.submitReview(id, store.readProject(id).revision, review(ev));
  assert.equal(director.getDirector(id).exportReady, false);
  assert.throws(() => director.assertDirectorExport(store.readProject(id)), /人工接受/);
  director.acceptDirectorReview(id, store.readProject(id).revision);
  assert.doesNotThrow(() => director.assertDirectorExport(store.readProject(id)));
  const p = store.readProject(id);
  store.updateShot(id, 'a', p.shots[0].inputRevision, { params: { scale: 2 } });
  assert.equal(director.getDirector(id).review.current, false);
  assert.throws(() => director.submitReview(id, store.readProject(id).revision, review(ev)), /过期/);
  assert.throws(() => director.assertDirectorExport(store.readProject(id)), /验证/);
});

test('analysis pending is safe and legacy exports keep their existing gate', () => {
  const id = fixture();
  assert.doesNotThrow(() => director.assertDirectorExport(store.readProject(id)));
  store.mutateProject(id, undefined, (p) => { p.song = null; p.shots = []; p.transitions = []; p.status = 'analysis-pending'; return p; });
  assert.equal(director.getDirector(id).phase, 'analysis');
  assert.equal(director.getDirector(id).exportReady, false);
});

test('new-song source submissions reject foreign lyric literals without saving a new source', () => {
  const id = fixture();
  const p = store.mutateProject(id, undefined, (p) => { p.status = 'planned'; return p; });
  assert.throws(() => store.submitShotSource(id, 'a', p.shots[0].inputRevision, "export default class Scene { render(){ ly.get('foreign lyric'); } }"), /静态检查/);
  assert.equal(store.readProject(id).shots[0].module, 'base');
});

test('回归：没有导演方案的已有工程（参考导入/旧工程）读取导演状态不崩溃，第一步是提交方案', () => {
  const id = fixture();
  const state = director.getDirector(id);
  assert.equal(state.director, null);
  assert.ok(state.actions.length >= 1, '应给出下一步');
  assert.ok(state.actions.every((action) => !action.blocked));
  assert.equal(state.exportReady, false);
});

test('回归：旧任务快照缺 shots/transitions（2026-09-30 前的反馈流程）时签名不崩溃，正常工程签名不变', () => {
  const id = fixture();
  const project = store.readProject(id);
  const normal = director.productionSignature(project);
  assert.equal(director.productionSignature(structuredClone(project)), normal, '正常工程签名稳定');
  const { transitions, ...legacy } = project;
  assert.doesNotThrow(() => director.productionSignature(legacy));
  assert.notEqual(director.productionSignature(legacy), normal, '缺字段的旧快照签名自然不匹配');
});
