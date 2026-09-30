// builtinScenes.ts — 无 LLM 时的确定性模板场景：每张卡按其 id/prompt 哈希从 6 种
// 视觉 motif 中选一种，保证内置规划下整条卡片带风格统一、卡卡不同、卡拉OK齐全。
import type { PlannedCard } from './planner';

function hashStr(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

const MOTIFS = ['curve', 'rings', 'grid', 'particles', 'bars', 'typo'] as const;
export type Motif = (typeof MOTIFS)[number];

export function motifForCard(card: PlannedCard): Motif {
  return MOTIFS[hashStr(card.id + '|' + card.prompt) % MOTIFS.length]!;
}

const MOTIF_LABEL: Record<Motif, string> = {
  curve: '火花轨迹曲线',
  rings: '同心环雷达',
  grid: '示波器网格',
  particles: '粒子场',
  bars: '频谱柱',
  typo: '大字排版',
};

/** 各 motif 的主体绘制代码片段（共享骨架在 builtinSceneForCard 里拼装）。 */
const MOTIF_BODY: Record<Motif, string> = {
  curve: `
  // 火花沿一条随包络起伏的轨迹行进
  const pts = [];
  for (let i = 0; i <= 60; i++) {
    const u = i / 60;
    pts.push([W * (0.1 + 0.8 * u), H * 0.62 - Math.sin(u * 3.1 + seedF * 6) * H * 0.16 - f.audio.rms * H * 0.06 * Math.sin(u * 17)]);
  }
  ctx.strokeStyle = P.graphite; ctx.lineWidth = Math.max(1, H * 0.0016);
  ctx.beginPath(); pts.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)); ctx.stroke();
  const head = Math.min(pts.length - 1, Math.floor(f.p * (pts.length - 1)));
  const [hx, hy] = pts[head];
  ctx.strokeStyle = P.signal; ctx.lineWidth = Math.max(1.5, H * 0.003); ctx.shadowColor = P.ember; ctx.shadowBlur = 12;
  ctx.beginPath(); for (let i = 0; i <= head; i++) { const [x, y] = pts[i]!; i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); } ctx.stroke();
  ctx.shadowBlur = 0;`,
  rings: `
  // 同心环在 downbeat 上扩张，唱到的词驱动内环
  const cx = W / 2, cy = H * 0.6;
  for (let i = 0; i < 7; i++) {
    const r = (H * 0.05) + i * H * 0.055 + f.audio.downbeat * H * 0.03;
    ctx.strokeStyle = i === 0 ? P.signal : 'rgba(156,151,143,' + (0.4 - i * 0.045).toFixed(3) + ')';
    ctx.lineWidth = i === 0 ? Math.max(1.5, H * 0.003) : Math.max(1, H * 0.0014);
    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
  }
  const sweep = f.p * Math.PI * 2;
  ctx.strokeStyle = P.ember; ctx.lineWidth = Math.max(1.5, H * 0.003); ctx.shadowColor = P.ember; ctx.shadowBlur = 10;
  ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(sweep) * H * 0.4, cy + Math.sin(sweep) * H * 0.4); ctx.stroke();
  ctx.shadowBlur = 0;`,
  grid: `
  // 示波器网格 + 骑在波形上的歌词
  ctx.strokeStyle = 'rgba(94,91,87,0.5)'; ctx.lineWidth = Math.max(1, H * 0.0012);
  for (let i = 1; i < 12; i++) { const x = (i / 12) * W; ctx.beginPath(); ctx.moveTo(x, H * 0.35); ctx.lineTo(x, H * 0.9); ctx.stroke(); }
  for (let j = 1; j < 6; j++) { const y = H * 0.35 + (j / 6) * H * 0.55; ctx.beginPath(); ctx.moveTo(W * 0.04, y); ctx.lineTo(W * 0.96, y); ctx.stroke(); }
  ctx.strokeStyle = P.signal; ctx.lineWidth = Math.max(1.5, H * 0.0032); ctx.shadowColor = P.ember; ctx.shadowBlur = 14;
  ctx.beginPath();
  for (let i = 0; i <= 120; i++) {
    const u = i / 120;
    if (u > f.p) break;
    const y = H * 0.62 + Math.sin(u * 40 + f.lt * 6) * H * 0.09 * (0.3 + f.audio.rms) + Math.sin(u * 9) * H * 0.05;
    const x = W * (0.04 + 0.92 * u);
    i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
  }
  ctx.stroke(); ctx.shadowBlur = 0;`,
  particles: `
  // 确定性粒子场：downbeat 时向心收拢，beat 呼吸
  const rand = api.rng(seed);
  const cx = W / 2, cy = H * 0.58;
  for (let i = 0; i < 160; i++) {
    const bx = rand(), by = rand(), bs = rand();
    const ang = bs * Math.PI * 2 + f.lt * (0.2 + bs * 0.5);
    const rad = H * (0.08 + bx * 0.42) * (1 - f.audio.downbeat * 0.18);
    const x = cx + Math.cos(ang) * rad * 1.6;
    const y = cy + Math.sin(ang) * rad;
    const size = Math.max(1, H * 0.0022 * (0.4 + bs));
    ctx.fillStyle = i % 9 === 0 ? P.signal : 'rgba(238,233,223,' + (0.16 + bs * 0.3).toFixed(3) + ')';
    ctx.fillRect(x, y, size, size);
  }`,
  bars: `
  // 频谱柱：柱高混合包络与确定性噪声，唱到的词点亮对应柱组
  const bars = 48;
  const rand = api.rng(seed + 1);
  const progress = f.p;
  for (let i = 0; i < bars; i++) {
    const u = i / bars;
    const env = 0.25 + f.audio.rms * 0.5 + f.audio.mid * 0.3;
    const hgt = H * 0.32 * env * (0.35 + rand() * 0.75) * (u <= progress ? 1 : 0.42);
    const x = W * 0.06 + u * W * 0.88;
    ctx.fillStyle = u <= progress && progress - u < 0.06 ? P.signal : 'rgba(238,233,223,0.3)';
    ctx.fillRect(x, H * 0.88 - hgt, W * 0.88 / bars - 3, hgt);
  }
  ctx.fillStyle = 'rgba(156,151,143,0.6)'; ctx.fillRect(W * 0.06, H * 0.88, W * 0.88, 1);`,
  typo: `
  // 大字排版：每记 downbeat 换一个关键词满屏，宽度随唱拉伸
  const words = [];
  for (const line of f.lyric.lines) for (const w of line.words) words.push(w);
  const idx = words.length ? Math.min(words.length - 1, Math.floor(f.p * words.length)) : 0;
  const word = words[idx];
  const wp = word ? api.wordProgress(word, f.t) : 1;
  if (word) {
    const size = H * (0.16 + 0.05 * f.audio.downbeat);
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = '900 ' + Math.round(size * (1 + 0.06 * (1 - wp))) + 'px Arial, sans-serif';
    ctx.fillStyle = wp > 0 && wp < 1 ? P.signal : P.bone;
    ctx.save();
    ctx.translate(W / 2, H * 0.55);
    ctx.rotate((1 - wp) * 0.04 * Math.sin(seedF * 9));
    ctx.fillText(word.w.toUpperCase(), 0, 0);
    ctx.restore();
    ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
  }`,
};

/** 为一张卡生成确定性的模板场景代码（诚实标注：非 LLM 产物）。 */
export function builtinSceneForCard(card: PlannedCard): { code: string; motif: Motif } {
  const motif = motifForCard(card);
  const seed = hashStr(card.id + '|' + card.prompt) % 100000;
  const code = `// ${card.title} — 内置模板场景（motif: ${motif} · ${MOTIF_LABEL[motif]}，未配置 LLM）
// 卡片提示词（模板只做了形似，配置 LLM 后请重新生成）：
// ${card.prompt.replace(/\n/g, ' ').slice(0, 120)}
const SEED = ${seed};
const seed = SEED;
const seedF = (SEED % 97) / 97;

export function draw(ctx, f, api) {
  const W = f.W, H = f.H, t = f.t, P = api.palette;
  ctx.fillStyle = P.ink;
  ctx.fillRect(0, 0, W, H);
  if (f.audio.beat > 0.02) {
    ctx.fillStyle = 'rgba(238,233,223,' + (0.015 * f.audio.beat).toFixed(4) + ')';
    ctx.fillRect(0, 0, W, H);
  }
${MOTIF_BODY[motif]}

  // 逐词卡拉OK（所有模板共享：未唱 30% 骨白、正在唱 signal、唱完 bone）
  const lines = f.lyric.lines.slice(0, 3);
  const size = Math.min(H * 0.05, W * 1.1 / Math.max(18, lines[0] ? lines[0].text.length : 18));
  ctx.textBaseline = 'alphabetic';
  lines.forEach((line, li) => {
    const y = H * (0.14 + li * 0.085);
    ctx.font = '600 ' + Math.round(size) + 'px Arial, sans-serif';
    const widths = line.words.map((w) => ctx.measureText(w.w).width);
    const space = ctx.measureText(' ').width;
    let x = W / 2 - (widths.reduce((a, b) => a + b, 0) + space * (line.words.length - 1)) / 2;
    for (let i = 0; i < line.words.length; i++) {
      const w = line.words[i], wp = api.wordProgress(w, t);
      ctx.fillStyle = 'rgba(238,233,223,0.3)';
      ctx.fillText(w.w, x, y);
      if (wp > 0) {
        ctx.save();
        ctx.beginPath(); ctx.rect(x - 1, y - size, widths[i] * wp + 2, size * 1.4); ctx.clip();
        ctx.fillStyle = wp < 1 ? P.signal : P.bone;
        ctx.fillText(w.w, x, y);
        ctx.restore();
      }
      x += widths[i] + space;
    }
  });

  // 角落读数
  ctx.font = Math.round(H * 0.02) + 'px monospace';
  ctx.fillStyle = 'rgba(156,151,143,0.7)';
  ctx.fillText('P(doom) — ${card.id.toUpperCase()}', W * 0.03, H * 0.955);
  ctx.textAlign = 'right';
  ctx.fillText('lt ' + f.lt.toFixed(1) + 's · bpm-synced', W * 0.97, H * 0.955);
  ctx.textAlign = 'left';
}
`;
  return { code, motif: motif };
}
