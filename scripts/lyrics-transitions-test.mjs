import test from 'node:test';
import assert from 'node:assert/strict';
import { prepareLyricPlan, shotLyricContext } from '../src/server/lyric-elements.mjs';
import { defaultTransitions, validateTransitionConfig, transitionWindow, renderShotsWithTransitions } from '../src/server/transitions.mjs';

const project = {
  output: { fps: 30 },
  shots: [{ id: 'a', start: 0, end: 2 }, { id: 'b', start: 2, end: 4 }, { id: 'c', start: 4, end: 7 }],
  song: { lines: [
    { text: 'There was a sudden drop in your training loss,', start: .2, end: 1.8, words: [{ w: 'drop', start: .6, end: .9 }, { w: 'loss,', start: 1.3, end: 1.8 }] },
    { text: 'Please don’t eat me alive', start: 2.1, end: 3.8, words: [{ w: 'don’t', start: 2.3, end: 2.6 }] },
  ] },
};
const element = { name: '训练损失骤降', quote: 'sudden drop', meaning: '性能突变', treatment: '在 drop 词开始时使曲线坠落', kind: 'action', cueWord: 'drop' };

test('lyric context is scoped to the actual shot window', () => {
  const context = shotLyricContext(project, project.shots[0]);
  assert.equal(context.lines.length, 1);
  assert.equal(context.lines[0].lineIndex, 0);
  assert.equal(context.instrumental, false);
});
test('element evidence and cue timing are derived, not supplied by the client', () => {
  const plan = prepareLyricPlan(project, project.shots[0], { summary: '描绘歌词中的骤降', elements: [element] });
  assert.equal(plan.status, 'proposed');
  assert.equal(plan.elements[0].lineIndex, 0);
  assert.deepEqual(plan.elements[0].cue, { word: 'drop', start: .6, end: .9 });
  assert.equal(plan.evidence[0].text, project.song.lines[0].text);
});
test('invented or out-of-window lyric quotes are rejected', () => {
  assert.throws(() => prepareLyricPlan(project, project.shots[0], { summary: 'bad', elements: [{ ...element, quote: 'eat me alive' }] }), /不是本镜头/);
  assert.throws(() => prepareLyricPlan(project, project.shots[0], { summary: 'bad', elements: [{ ...element, quote: 'the moon is blue' }] }), /不是本镜头/);
});
test('a cue word must be in the quoted lyric line', () => {
  assert.throws(() => prepareLyricPlan(project, project.shots[0], { summary: 'bad', elements: [{ ...element, cueWord: 'moon' }] }), /触发词/);
});
test('typographic apostrophes are normalized without changing the source', () => {
  const plan = prepareLyricPlan(project, project.shots[1], { summary: '恳求', elements: [{ ...element, quote: "Please don't", cueWord: "don't" }] });
  assert.equal(plan.elements[0].cue.word, 'don’t');
});
test('instrumental windows cannot manufacture lyric evidence', () => {
  const plan = prepareLyricPlan(project, project.shots[2], { summary: '器乐段承接前面的主题', elements: [] });
  assert.equal(plan.instrumental, true);
  assert.throws(() => prepareLyricPlan(project, project.shots[2], { summary: 'bad', elements: [element] }), /不是本镜头/);
  assert.throws(() => prepareLyricPlan(project, project.shots[0], { summary: 'no evidence', elements: [] }), /至少选择/);
});
test('defaults create one hard-cut node per adjacent pair', () => {
  const transitions = defaultTransitions(project.shots);
  assert.equal(transitions.length, 2);
  assert.equal(transitions[0].fromShotId, 'a');
  assert.equal(transitions[0].toShotId, 'b');
  assert.ok(transitions.every((entry) => entry.mode === 'cut' && entry.duration === 0));
  assert.deepEqual(defaultTransitions(project.shots), transitions);
});
test('transition duration is bounded and hard cuts have zero duration', () => {
  const tr = defaultTransitions(project.shots)[0];
  assert.deepEqual(validateTransitionConfig(project, tr, { mode: 'wipe', duration: .2 }), { mode: 'wipe', duration: .2, easing: 'smooth', direction: 'left' });
  for (const duration of [-1, 0, .001, 2, NaN, Infinity]) assert.throws(() => validateTransitionConfig(project, tr, { mode: 'dissolve', duration }));
  assert.throws(() => validateTransitionConfig(project, tr, { mode: 'cut', duration: .2 }), /硬切/);
  assert.throws(() => validateTransitionConfig(project, tr, { mode: 'invented' }), /类型/);
});
test('only adjacent shots may be connected by a transition', () => {
  const tr = { ...defaultTransitions(project.shots)[0], toShotId: 'c' };
  assert.throws(() => validateTransitionConfig(project, tr, { mode: 'dip', duration: .2 }), /相邻/);
});
test('transition happens after the cut and never shortens the timeline', () => {
  const tr = { ...defaultTransitions(project.shots)[0], mode: 'dissolve', duration: .2 };
  const window = transitionWindow(project, tr);
  assert.equal(window.start, 2);
  assert.equal(window.end, 2.2);
  assert.equal(window.frames, 6);
  assert.equal(window.holdTime, 2 - 1 / 30);
  const rendered = renderShotsWithTransitions(project.shots, [tr], 30);
  assert.equal(rendered[0].end, 2.2);
  assert.equal(rendered[0].logicalEnd, 2);
  assert.equal(rendered[1].start, 2);
  assert.equal(rendered.at(-1).end, 7);
  assert.equal(project.shots[0].end, 2, 'original shot specifications remain unchanged');
});
test('adjacent transitions cannot produce three simultaneously active scenes', () => {
  const transitions = defaultTransitions(project.shots).map((tr) => ({ ...tr, mode: 'wipe', duration: .5 }));
  const rendered = renderShotsWithTransitions(project.shots, transitions, 30);
  for (let n = 0; n < 210; n++) assert.ok(rendered.filter((shot) => n / 30 >= shot.start && n / 30 < shot.end).length <= 2);
});
