// lyric-elements.mjs — 歌词证据与镜头元素方案；只校验引用，不冒充自动审美判断。
import { createHash } from 'node:crypto';
import { ProjectError } from './errors.mjs';
const normalize = (text) => text.toLowerCase().replace(/[‘’]/g, "'").replace(/[“”]/g, '"').replace(/\s+/g, ' ').trim();
function text(value, name, max) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw new ProjectError(`${name}不能为空或超过 ${max} 字符`);
  return value.trim();
}
export function shotLyricContext(project, shot) {
  const lines = (project.song.lines ?? []).map((line, index) => ({ ...line, lineIndex: index }))
    .filter((line) => line.end > shot.start && line.start < shot.end);
  return { shotId: shot.id, window: { start: shot.start, end: shot.end }, lines, instrumental: lines.length === 0,
    plan: shot.lyricPlan ?? null,
    rule: '先解释歌词含义，再选择具象/动作/隐喻元素；每项附真实歌词引用和呈现方式。方案关联源码不等于画面已通过语义/审美验收。' };
}
export function prepareLyricPlan(project, shot, input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new ProjectError('invalid lyric element plan');
  const context = shotLyricContext(project, shot);
  const summary = text(input.summary, '歌词解读', 4000);
  if (!Array.isArray(input.elements) || input.elements.length > 24) throw new ProjectError('elements 必须是最多 24 项的数组');
  if (!context.instrumental && !input.elements.length) throw new ProjectError('有歌词的镜头至少选择一个有依据的元素');
  const elements = input.elements.map((entry, index) => {
    if (!entry || typeof entry !== 'object') throw new ProjectError('invalid lyric element');
    const name = text(entry.name, '元素名称', 120);
    const quote = text(entry.quote, '歌词引用', 500);
    const meaning = text(entry.meaning, '含义解释', 1500);
    const treatment = text(entry.treatment, '视觉处理', 2000);
    const line = context.lines.find((line) => normalize(line.text).includes(normalize(quote)));
    if (!line) throw new ProjectError(`“${quote}”不是本镜头窗口内的歌词，不能作为画面依据`);
    const kind = entry.kind ?? 'entity';
    if (!['entity', 'action', 'metaphor'].includes(kind)) throw new ProjectError('kind 必须是 entity/action/metaphor');
    const cueWord = typeof entry.cueWord === 'string' ? entry.cueWord.trim() : '';
    const word = cueWord ? line.words.find((word) => normalize(word.w).replace(/[.,!?;:]/g, '') === normalize(cueWord).replace(/[.,!?;:]/g, '')) : null;
    if (cueWord && !word) throw new ProjectError(`触发词 ${cueWord} 不在引用歌词中`);
    return { id: createHash('sha256').update(`${line.lineIndex}|${name}|${index}`).digest('hex').slice(0, 16), name, quote, meaning, treatment, kind,
      lineIndex: line.lineIndex, ...(word ? { cue: { word: word.w, start: word.start, end: word.end } } : {}) };
  });
  return { summary, elements, instrumental: context.instrumental, evidence: context.lines.map(({ lineIndex, text, start, end }) => ({ lineIndex, text, start, end })),
    updatedAt: Date.now(), status: 'proposed', note: '这是创作意图与歌词依据，仍需检查实际画面。' };
}
