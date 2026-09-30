export type LyricResearchKind = 'literal' | 'slang' | 'meme' | 'cultural-reference' | 'brand-risk';

export interface LyricResearchFinding {
  phrase: string;
  kind: LyricResearchKind;
  meaning: string;
  visualImplication: string;
  confidence: 'high' | 'medium' | 'low';
  sources: string[];
  sensitive?: boolean;
}

export interface LyricResearchArtifact {
  lineId: string;
  text: string;
  language: string;
  literalMeaning: string;
  findings: LyricResearchFinding[];
  visualDirection: string;
  contentHash: string;
  cacheKey: string;
  status: 'draft' | 'researched' | 'approved' | 'needs-review';
}

export interface ShotLyricContext {
  shotId: string;
  lineIds: string[];
  lyricText: string;
  timeRange: { start: number; end: number };
  beatRange?: { start: number; end: number };
  semanticSummary: string;
  findings: LyricResearchFinding[];
  visualIntent: string;
  interpretationNotes: string;
  approved: boolean;
}

export function buildShotLyricPrompt(context: ShotLyricContext): string {
  const findings = context.findings.length
    ? context.findings.map((finding) => `- [${finding.kind}/${finding.confidence}] ${finding.phrase}: ${finding.meaning} → 视觉含义：${finding.visualImplication}`).join('\n')
    : '- 没有额外黑话或文化引用；不要臆造语境。';
  return [
    `SHOT LYRIC CONTEXT (${context.shotId})`,
    `时间：${context.timeRange.start.toFixed(2)}s - ${context.timeRange.end.toFixed(2)}s`,
    `歌词：${context.lyricText}`,
    `语义总结：${context.semanticSummary}`,
    `研究发现：\n${findings}`,
    `视觉意图：${context.visualIntent}`,
    `创作者备注：${context.interpretationNotes || '无'}`,
    `研究审批：${context.approved ? '已审批，可作为创作事实使用' : '未审批，只能作为候选解释，不得当作确定事实'}`,
  ].join('\n');
}
