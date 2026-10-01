// feedback.mjs — 人工修改意见的数据契约（FB-01）：定位锚点、保留项、澄清对话、逐条响应与待办收件箱。
// 只做纯数据校验与状态迁移；持久化、版本检查和事务由 project-store.mjs 负责。
// 状态：pending（待 AI 响应）→ needs-clarification（AI 提问，等人回复）→ pending
//       pending → responded（AI 已响应，待人确认）→ accepted（只能由人在界面完成）
import { ProjectError } from './errors.mjs';

export const FEEDBACK_STATUSES = ['pending', 'needs-clarification', 'responded', 'accepted'];
export const FEEDBACK_ASPECTS = ['composition', 'motion', 'typography', 'color', 'timing', 'lyrics', 'other'];
export const RESPONSE_OUTCOMES = ['addressed', 'partial'];
const MAX_TEXT = 8000, MAX_PRESERVE = 12, MAX_PRESERVE_ITEM = 300, MAX_HOW = 2000, MAX_THREAD = 40, MAX_HISTORY = 10;

const finite = (value) => typeof value === 'number' && Number.isFinite(value);
function cleanText(value, label, max) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw new ProjectError(`${label}不能为空或超过 ${max} 字符`);
  return value.trim();
}

/** 意见锚点允许的时间范围：镜头为自身窗口；转场为前后两个镜头的合并窗口。 */
export function feedbackTargetWindow(project, target, kind, pair) {
  if (kind === 'shot') return { start: target.start, end: target.end };
  return { start: pair.left.start, end: pair.right.end };
}
export function lyricElementIds(target, kind, pair) {
  const plans = kind === 'shot' ? [target.lyricPlan] : [pair.left.lyricPlan, pair.right.lyricPlan];
  return new Set(plans.flatMap((plan) => plan?.elements ?? []).map((element) => element.id));
}

/**
 * 校验并规范化新意见。旧调用只传 text 时与原行为一致。
 * @param {{ text: string, anchor?: object, preserve?: string[], author?: 'human'|'mcp' }} input
 * @param {{ window: {start:number,end:number}, elementIds: Set<string>, fps: number }} scope
 */
export function prepareFeedbackInput(input, scope) {
  const text = cleanText(input.text, '修改意见', MAX_TEXT);
  const author = input.author ?? 'human';
  if (!['human', 'mcp'].includes(author)) throw new ProjectError('意见作者只能是 human 或 mcp');
  const prepared = { text, author };
  if (input.anchor !== undefined && input.anchor !== null) prepared.anchor = prepareAnchor(input.anchor, scope);
  if (input.preserve !== undefined && input.preserve !== null) {
    if (!Array.isArray(input.preserve) || input.preserve.length > MAX_PRESERVE) throw new ProjectError(`保留项必须是最多 ${MAX_PRESERVE} 条的数组`);
    const preserve = input.preserve.map((item) => cleanText(item, '保留项', MAX_PRESERVE_ITEM));
    if (new Set(preserve).size !== preserve.length) throw new ProjectError('保留项不能重复');
    if (preserve.length) prepared.preserve = preserve;
  }
  return prepared;
}

function prepareAnchor(anchor, { window, elementIds, fps }) {
  if (typeof anchor !== 'object' || Array.isArray(anchor)) throw new ProjectError('anchor 必须是对象');
  const allowed = ['t', 'range', 'lyricElementId', 'region', 'aspect'];
  if (Object.keys(anchor).some((key) => !allowed.includes(key))) throw new ProjectError(`anchor 只支持 ${allowed.join('/')}`);
  const tolerance = 0.5 / fps;
  const inWindow = (t) => t >= window.start - tolerance && t <= window.end + tolerance;
  const result = {};
  if (anchor.t !== undefined) {
    if (!finite(anchor.t) || !inWindow(anchor.t)) throw new ProjectError(`锚点时间必须在目标时间窗 ${window.start.toFixed(3)}–${window.end.toFixed(3)}s 内`);
    result.t = Math.round(anchor.t * 1000) / 1000;
  }
  if (anchor.range !== undefined) {
    const { start, end } = anchor.range ?? {};
    if (!finite(start) || !finite(end) || start >= end || !inWindow(start) || !inWindow(end)) throw new ProjectError('锚点区间必须递增且落在目标时间窗内');
    result.range = { start: Math.round(start * 1000) / 1000, end: Math.round(end * 1000) / 1000 };
  }
  if (anchor.lyricElementId !== undefined) {
    if (typeof anchor.lyricElementId !== 'string' || !elementIds.has(anchor.lyricElementId)) throw new ProjectError('lyricElementId 必须是当前歌词元素方案中的元素');
    result.lyricElementId = anchor.lyricElementId;
  }
  if (anchor.region !== undefined) {
    const { x, y, w, h } = anchor.region ?? {};
    const unit = (value) => finite(value) && value >= 0 && value <= 1;
    if (![x, y, w, h].every(unit) || w <= 0 || h <= 0 || x + w > 1 + 1e-6 || y + h > 1 + 1e-6) throw new ProjectError('画面区域使用 0..1 归一化坐标，且不能超出画面');
    result.region = { x, y, w, h };
  }
  if (anchor.aspect !== undefined) {
    if (!FEEDBACK_ASPECTS.includes(anchor.aspect)) throw new ProjectError(`aspect 只支持 ${FEEDBACK_ASPECTS.join('/')}`);
    result.aspect = anchor.aspect;
  }
  if (!Object.keys(result).length) throw new ProjectError('anchor 不能为空对象');
  return result;
}

export function createNote(prepared, target, id, now = Date.now()) {
  return { id, ...prepared, status: 'pending', baseInputRevision: target.inputRevision, createdAt: now, thread: [] };
}

/** 输入（源码/参数/提示词/配置）一变，旧响应针对的是旧版本：退回 pending 并保留响应历史。 */
export function invalidateResponses(target, now = Date.now()) {
  const reverted = [];
  for (const note of target.feedback ?? []) if (note.status === 'responded') {
    note.status = 'pending'; note.invalidatedAt = now;
    if (note.response) note.responseHistory = [...(note.responseHistory ?? []), { ...note.response, invalidatedAt: now }].slice(-MAX_HISTORY);
    delete note.response; delete note.codeHash; delete note.responseInputToken;
    reverted.push(note.id);
  }
  return reverted;
}

/**
 * 合并旧参数 addressedFeedbackIds 与新参数 feedbackResponses，返回逐条响应。
 * 同一 ID 以 feedbackResponses 为准；ID 必须属于该目标、未接受、且不在等待澄清。
 */
export function prepareResponses(target, addressedFeedbackIds = [], feedbackResponses = []) {
  if (!Array.isArray(addressedFeedbackIds) || !Array.isArray(feedbackResponses)) throw new ProjectError('addressedFeedbackIds / feedbackResponses 必须是数组');
  const responses = new Map();
  for (const feedbackId of addressedFeedbackIds) responses.set(feedbackId, { feedbackId, outcome: 'addressed', how: '' });
  const seen = new Set();
  for (const entry of feedbackResponses) {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) throw new ProjectError('feedbackResponses 每项必须是对象');
    if (Object.keys(entry).some((key) => !['feedbackId', 'outcome', 'how'].includes(key))) throw new ProjectError('feedbackResponses 只支持 feedbackId/outcome/how');
    if (seen.has(entry.feedbackId)) throw new ProjectError('feedbackResponses 中的意见 ID 不能重复');
    seen.add(entry.feedbackId);
    const outcome = entry.outcome ?? 'addressed';
    if (!RESPONSE_OUTCOMES.includes(outcome)) throw new ProjectError('outcome 只支持 addressed / partial');
    const how = entry.how === undefined ? '' : String(entry.how).trim();
    if (how.length > MAX_HOW) throw new ProjectError(`how 不能超过 ${MAX_HOW} 字符`);
    if (outcome === 'partial' && !how) throw new ProjectError('部分响应必须说明完成了什么、还缺什么');
    responses.set(entry.feedbackId, { feedbackId: entry.feedbackId, outcome, how });
  }
  for (const { feedbackId } of responses.values()) {
    const note = (target.feedback ?? []).find((entry) => entry.id === feedbackId);
    if (typeof feedbackId !== 'string' || !note || note.status === 'accepted') throw new ProjectError('反馈 ID 必须来自本目标尚未接受的意见');
    if (note.status === 'needs-clarification') throw new ProjectError('该意见正在等待人回复澄清问题，回复前不能标记为已响应', 409);
  }
  return [...responses.values()];
}

/** 在新版本 codeHash/inputToken 确定之后调用；只标记明确响应的意见。 */
export function applyResponses(target, responses, { codeHash, inputToken, author, now = Date.now() }) {
  for (const response of responses) {
    const note = target.feedback.find((entry) => entry.id === response.feedbackId);
    note.status = 'responded'; note.respondedAt = now; note.codeHash = codeHash; note.responseInputToken = inputToken;
    note.response = { outcome: response.outcome, how: response.how, by: author, at: now, codeHash };
  }
}

function threadNote(target, feedbackId) {
  const note = (target.feedback ?? []).find((entry) => entry.id === feedbackId);
  if (!note) throw new ProjectError('feedback not found', 404);
  if (note.status === 'accepted') throw new ProjectError('意见已被接受，不能再追加对话', 409);
  note.thread ??= [];
  if (note.thread.length >= MAX_THREAD) throw new ProjectError('对话过长，请新建意见');
  return note;
}
/** AI 无法确定意图时提问；意见转为 needs-clarification，旧的已响应状态失效。 */
export function askOnNote(target, feedbackId, question, by = 'mcp', now = Date.now()) {
  if (!['human', 'mcp'].includes(by)) throw new ProjectError('invalid author');
  const note = threadNote(target, feedbackId);
  if (note.status === 'responded') throw new ProjectError('该意见已有候选响应；如需澄清，请等人拒绝或补充意见', 409);
  note.thread.push({ by, kind: 'question', text: cleanText(question, '澄清问题', MAX_HOW), at: now });
  note.status = 'needs-clarification';
}
/** 只有人可以回复澄清问题；回复后回到 pending，等待 AI 重新处理。 */
export function replyOnNote(target, feedbackId, text, by = 'human', now = Date.now()) {
  if (by !== 'human') throw new ProjectError('澄清回复只能由人提交', 403);
  const note = threadNote(target, feedbackId);
  if (note.status !== 'needs-clarification') throw new ProjectError('该意见当前没有待回复的问题', 409);
  note.thread.push({ by, kind: 'reply', text: cleanText(text, '回复', MAX_TEXT), at: now });
  note.status = 'pending';
}

function nextStep(kind, target, note) {
  if (target.locked) return '目标已锁定：等待人解锁，不要自行解锁。';
  if (note.status === 'needs-clarification') return '已向人提问，等待回复；回复前不要改写。';
  if (note.status === 'responded') return '已响应，等待人在界面对比并采用或拒绝；AI 不能接受意见。';
  if (note.status === 'accepted') return '人已采用，无需处理。';
  return kind === 'shot'
    ? 'project_shot_lyrics + project_shot_source 读上下文 → 只改意见指向处、保留 preserve 列表 → project_shot_submit 带 feedbackResponses 逐条说明 → project_validate。意图含糊先提问澄清。'
    : 'project_transition_get 读前后镜头与时间窗 → project_transition_configure 带 feedbackResponses → project_transition_validate。意图含糊先提问澄清。';
}
const publicNote = ({ id, text, status, author, anchor, preserve, thread, response, baseInputRevision, createdAt }) =>
  ({ id, text, status, author: author ?? 'human', ...(anchor ? { anchor } : {}), ...(preserve ? { preserve } : {}), thread: thread ?? [], ...(response ? { response } : {}), baseInputRevision, createdAt });

/**
 * 待办收件箱：一个工程内所有镜头/转场意见，按创建时间排序。
 * status: 'open'（默认，全部未接受）或具体状态。不返回 inputToken、本机绝对路径或服务令牌。
 */
export function inboxItems(project, { status = 'open', windowOf }) {
  if (status !== 'open' && !FEEDBACK_STATUSES.includes(status)) throw new ProjectError(`status 只支持 open/${FEEDBACK_STATUSES.join('/')}`);
  const match = (note) => status === 'open' ? note.status !== 'accepted' : note.status === status;
  const targets = [
    ...project.shots.map((target) => ({ kind: 'shot', target })),
    ...(project.transitions ?? []).map((target) => ({ kind: 'transition', target })),
  ];
  const items = targets.flatMap(({ kind, target }) => (target.feedback ?? []).filter(match).map((note) => ({
    projectId: project.id, projectName: project.name, targetKind: kind, targetId: target.id,
    title: kind === 'shot' ? target.title : `${target.fromShotId} → ${target.toShotId}`,
    window: windowOf(kind, target), inputRevision: target.inputRevision, locked: Boolean(target.locked), targetStatus: target.status,
    intent: kind === 'shot' ? target.prompt : target.intent,
    ...(kind === 'shot' && target.lyricPlan ? { lyricPlanSummary: target.lyricPlan.summary } : {}),
    hasBaseline: Boolean(target.reviewBaseline),
    ...(target.validation?.thumb ? { thumb: `artifacts/${target.validation.thumb}` } : {}),
    note: publicNote(note), nextStep: nextStep(kind, target, note),
  })));
  return items.sort((a, b) => a.note.createdAt - b.note.createdAt);
}
