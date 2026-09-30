// codegen.ts — 镜头卡片的代码生成：引擎契约 + 卡片提示词 → LLM → 一个 draw() 场景文件。
import type { ProviderConfig } from '../llm/types';
import { cachedChat, parseSceneResponse } from '../llm/adapters';
import { linesInWindow, type FullSongData } from './engine';
import type { PlannedCard } from './planner';
import { describeShotIssue, MAX_SHOT_REPAIRS, type ShotValidationIssue } from './validation';

/** 引擎契约：注入给 LLM 的唯一接口说明（与 src/shot/engine.ts 保持一致）。 */
export const ENGINE_CONTRACT = `
## 引擎契约（必须严格遵守）

导出签名：
\`\`\`ts
export function draw(ctx: CanvasRenderingContext2D, f: Frame, api: Api): void
\`\`\`

Frame f 的字段：
- f.t: 全曲时间（秒）；f.lt: 镜头内局部时间（秒）；f.p: 0..1 镜头进度
- f.W, f.H: 画布逻辑尺寸（运行时决定，可能是 1920×1080 或更小的预览）——所有布局都用比例推导，绝不硬编码像素
- f.audio: { rms, low, mid, high, vocal, drums }（0..1 包络）+ { beat, downbeat }（脉冲 1→0 衰减）+ { beatPhase }（0..1 拍内相位）
- f.lyric.lines: 本镜头窗口内的歌词行数组（已过滤），每行 { text, start, end, words: [{ w, start, end }] }，时间均为全曲秒

Api api 的成员：
- api.palette: { ink '#0A0A0B', ink2 '#151517', graphite '#5E5B57', ash '#9C978F', bone '#EEE9DF', signal '#FF4D12', ember '#FF8A3D', blood '#C21D0B', acid '#D8FF3C' }（墨黑底、骨白主字、信号橙唯一强调色）
- api.ease: { outExpo, inOutCubic, inOutQuad, outBack }
- api.rng(seed): 返回确定性随机函数（mulberry32）
- api.clamp(x, a, b), api.lerp(a, b, x)
- api.wordProgress(word, f.t): 词的已唱进度 0..1 —— 卡拉OK高亮的唯一时间来源
- api.lineCharProgress(line, f.t): 整行已唱字符数
- api.pulse(t, events, halfLife): 事件脉冲；api.beatEvents / api.downbeatEvents / api.kickEvents / api.snareEvents 事件数组（已按本窗口过滤）

硬规则：
1. 纯函数：输出只依赖 f（和 api.rng 种子）。禁止 Math.random() / Date.now() / performance.now()。
2. 禁止 import、fetch、动态导入、外部图片/字体资源。只用 Canvas 2D。
3. 每帧先铺背景（fillRect 覆盖全画布），save/restore 必须配平。
4. 字体只用系统栈：'Arial, sans-serif' 或 'monospace'，字号用 f.H 的比例。
5. 歌词卡拉OK：未唱部分 bone 30% 透明度，已唱 bone；正在唱的词用 signal 橙。绝不跑在人声前面。
6. 大变化落在拍上（用 f.audio.beat / downbeat / api.pulse），重音用 signal/ember 的辉光（shadowBlur + shadowColor）。
7. 代码 ≤ 120 行，只输出一个 fence 代码块 + 一行 "SUMMARY: <一句话>"。
`.trim();

/** 最小范例（展示惯用法，让 LLM 模仿而不是重新发明）。 */
const MINI_EXAMPLE = `
// 范例（惯用法）：
export function draw(ctx, f, api) {
  const W = f.W, H = f.H, P = api.palette;
  ctx.fillStyle = P.ink; ctx.fillRect(0, 0, W, H);
  const line = f.lyric.lines[0];
  if (line) {
    ctx.font = '600 ' + Math.round(H * 0.06) + 'px Arial, sans-serif';
    ctx.textAlign = 'center';
    for (const w of line.words) {
      const wp = api.wordProgress(w, f.t);
      ctx.fillStyle = wp > 0 && wp < 1 ? P.signal : P.bone;
      ctx.globalAlpha = wp === 0 ? 0.3 : 1;
      ctx.fillText(w.w, W / 2, H * 0.5);
    }
    ctx.globalAlpha = 1; ctx.textAlign = 'left';
  }
  ctx.strokeStyle = P.signal; ctx.lineWidth = Math.max(1.5, H * 0.004);
  ctx.shadowColor = P.ember; ctx.shadowBlur = 14;
  ctx.beginPath();
  ctx.moveTo(W * 0.15, H * 0.8 - f.audio.rms * H * 0.1);
  ctx.lineTo(W * (0.15 + 0.5 * f.p), H * 0.35 - f.audio.beat * H * 0.05);
  ctx.stroke(); ctx.shadowBlur = 0;
}
`.trim();

export function buildShotMessages(card: PlannedCard, song: FullSongData): { system: string; user: string } {
  const lines = linesInWindow(song, card.window)
    .map((l) => `  - "${l.text}" (${l.start}s → ${l.end}s)\n    words: ${l.words.map((w) => `${w.w}@${w.start}`).join(' · ')}`)
    .join('\n') || '  （无歌词 —— 器乐段落）';
  const system = [
    '你是 VideoGraph 的镜头场景程序员：把一张镜头卡片的提示词变成一个确定性的 Canvas 2D 场景文件。',
    '这支视频的美术基调：末日论文的插图版画——墨黑底、骨白字、信号橙唯一强调色、hairline 精确、幽默是一板一眼的科学家式冷幽默；禁止紫色霓虹赛博朋克、发光大脑、Matrix 代码雨。',
    ENGINE_CONTRACT,
    '输出格式：只回复一个 ```ts 代码块，随后一行 "SUMMARY: <一句话>"。不要输出任何其他内容。',
  ].join('\n\n');
  const user = [
    `## 镜头卡片\n「${card.title}」 · 锚定：${card.anchor}`,
    `## 镜头提示词（人类可编辑的需求来源）\n${card.prompt}`,
    `## 镜头窗口\n全曲 ${card.window.start.toFixed(2)}s → ${card.window.end.toFixed(2)}s（lt 0 → ${(card.window.end - card.window.start).toFixed(2)}s）。`,
    `## 本镜头歌词（词级时间，f.lyric.lines 就是它们）\n${lines}`,
    `## 音频特征\n恒定 ${song.bpm} BPM；f.audio 六路包络 0..1；beat/downbeat 是衰减脉冲；拍内相位 beatPhase。重音应落在 downbeat 上。`,
    MINI_EXAMPLE,
  ].join('\n\n');
  return { system, user };
}

export interface ShotGenResult {
  code: string;
  summary: string;
  source: 'llm' | 'builtin';
  model?: string;
  usage?: { input?: number; output?: number };
}

export interface ShotRepair {
  attempt: number;
  code: string;
  issue: ShotValidationIssue;
}

/** 修复与首次生成使用同一份契约/需求，额外上下文也参与精确缓存 key。 */
export function buildShotRepairMessages(card: PlannedCard, song: FullSongData, repair: ShotRepair): { system: string; user: string } {
  const messages = buildShotMessages(card, song);
  return {
    system: messages.system,
    user: [
      messages.user,
      `## 自动修复 ${repair.attempt}/${MAX_SHOT_REPAIRS}`,
      '上一版未通过本地校验。保持镜头提示词、时间窗、歌词同步和视觉意图不变，只修复错误。返回完整场景文件，不要返回 diff。',
      `## 校验诊断\n${describeShotIssue(repair.issue)}`,
      `## 上一版失败代码\n\`\`\`ts\n${repair.code}\n\`\`\``,
    ].join('\n\n'),
  };
}

/** 这里只负责传输/解析；校验与有限重试由工坊统一协调。 */
export async function generateShotScene(provider: ProviderConfig, card: PlannedCard, song: FullSongData, repair?: ShotRepair, signal?: AbortSignal): Promise<ShotGenResult> {
  const { system, user } = repair ? buildShotRepairMessages(card, song, repair) : buildShotMessages(card, song);
  const { result, hit } = await cachedChat(provider, [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ], { temperature: 0.3, maxTokens: 4096, signal });
  const parsed = parseSceneResponse(result.text);
  return {
    code: parsed.code,
    summary: (hit ? '[缓存命中] ' : '') + parsed.summary,
    source: 'llm',
    model: provider.model,
    usage: result.usage,
  };
}
