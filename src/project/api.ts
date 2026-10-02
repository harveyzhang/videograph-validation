export type FeedbackAspect = 'composition' | 'motion' | 'typography' | 'color' | 'timing' | 'lyrics' | 'other';
export interface FeedbackAnchor { t?: number; range?: { start: number; end: number }; lyricElementId?: string; region?: { x: number; y: number; w: number; h: number }; aspect?: FeedbackAspect }
export interface FeedbackThreadEntry { by: 'human' | 'mcp'; kind: 'question' | 'reply'; text: string; at: number }
export interface FeedbackResponse { outcome: 'addressed' | 'partial'; how: string; by: 'human' | 'mcp'; at: number; codeHash: string }
export interface ProjectFeedback {
  id: string; text: string; status: 'pending' | 'needs-clarification' | 'responded' | 'accepted'; baseInputRevision: number;
  author?: 'human' | 'mcp'; anchor?: FeedbackAnchor; preserve?: string[]; thread?: FeedbackThreadEntry[]; response?: FeedbackResponse;
}
export interface LyricElement { id?: string; name: string; quote: string; meaning: string; treatment: string; kind: 'entity' | 'action' | 'metaphor'; cueWord?: string; cue?: { word: string; start: number; end: number } }
export interface LyricPlan { summary: string; elements: LyricElement[]; instrumental?: boolean; status?: string }
export interface ShotLyricContext { lines: Array<{ lineIndex: number; text: string; start: number; end: number; words: Array<{ w: string; start: number; end: number }> }>; instrumental: boolean; rule: string }
export interface ProjectTransition {
  id: string; fromShotId: string; toShotId: string; intent: string; mode: 'cut' | 'dissolve' | 'wipe' | 'dip'; duration: number;
  easing: 'linear' | 'smooth'; direction: 'left' | 'right'; inputRevision: number; inputToken: string; status: string; locked: boolean;
  feedback?: ProjectFeedback[]; reviewBaseline?: { mode: string }; validation?: { samples: number; thumb: string; leftInputToken?: string; rightInputToken?: string };
}
export interface ProjectShot {
  id: string;
  title: string;
  module: string;
  start: number;
  end: number;
  params: Record<string, unknown>;
  prompt: string;
  inputRevision: number;
  inputToken: string;
  source: string;
  status: string;
  locked: boolean;
  feedback?: ProjectFeedback[];
  lyricPlan?: LyricPlan;
  reviewBaseline?: { module: string; validation?: { thumb: string } };
  validation?: { samples: number; thumb: string; checkedAt: number };
}
export interface VideoProject {
  id: string;
  name: string;
  revision: number;
  engineHash: string;
  audio: { name: string; hash: string };
  /** 新歌工程的阶段状态（SONG-05）；参考导入工程没有该字段。 */
  status?: 'analysis-pending' | 'analysis-failed' | 'analysis-draft' | 'analysis-confirmed' | 'planned';
  analysis: {
    source: string;
    note: string;
    error?: string;
    confirmedBy?: 'human' | 'mcp';
    stages?: string[];
    task?: string;
    cached?: boolean;
  };
  /** 新歌分析完成前歌曲派生数据尚未发布，必须允许为 null。 */
  song: { song: string; duration: number; bpm: number } | null;
  output: { fps: number; samples: number };
  credits: string;
  shots: ProjectShot[];
  transitions: ProjectTransition[];
}

export interface DirectorBrief {
  intent: string;
  audience: string;
  mustKeep: string[];
  mustAvoid: string[];
}
export interface DirectorStyle {
  medium: unknown;
  palette: unknown;
  typography: unknown;
  composition: unknown;
  motion: unknown;
  motif: unknown;
}
export interface DirectorRhythmSection { sectionIndex: number; energy: number; intent: string }
export interface DirectorShotPlan { shotId: string; subject: string; action: string; entrance: string; exit: string }
export interface DirectorPlan {
  version: string | number;
  brief: DirectorBrief;
  style: DirectorStyle;
  rhythm: { sections: DirectorRhythmSection[]; accents: unknown[] };
  shots: DirectorShotPlan[];
  [key: string]: unknown;
}
export interface DirectorAction {
  id: string;
  kind: string;
  targetKind?: string;
  targetId?: string;
  tool: string;
  args: Record<string, unknown>;
  reason: string;
  blocked?: boolean;
}
export interface DirectorReviewEvidence { jobId: string; file?: string; [key: string]: unknown }
export interface DirectorReviewIssue { severity: 'blocking' | 'warning' | 'intentional'; targetId?: string; t?: number; detail?: string }
export interface DirectorReview { current: boolean; humanAccepted?: boolean; acceptedAt?: number; summary?: string; evidence?: DirectorReviewEvidence[]; issues?: DirectorReviewIssue[] }
export interface DirectorSnapshot {
  projectId: string;
  revision: number;
  director: DirectorPlan | null;
  phase: string;
  actions: DirectorAction[];
  blockers: string[];
  review: DirectorReview;
  exportReady: boolean;
}

export class ProjectApiError extends Error {
  constructor(message: string, public readonly status: number) { super(message); this.name = 'ProjectApiError'; }
}
export interface StillsImage { t: number; file: string }
export interface StillsSummary { targetKind: 'shot' | 'transition'; targetId: string; times: number[]; version: 'current' | 'before-feedback'; width: number }
export interface ProjectJob {
  id: string;
  kind: 'validate' | 'validate-transition' | 'export' | 'stills' | 'filmstrip' | 'contact-sheet' | 'rhythm' | 'analysis';
  status: string;
  progress: number;
  detail?: string;
  error?: string;
  inputRevision: number;
  shotId?: string;
  transitionId?: string;
  stills?: StillsSummary;
  result?: { file?: string; frames?: number; seconds?: number; reports?: Array<{ cached: boolean }>; stills?: { images: StillsImage[] } };
}
export interface ProjectSummary { id: string; name: string; shots: number; duration: number; revision: number }

export const serviceUrl = (import.meta.env.VITE_VIDEOGRAPH_SERVICE_URL || 'http://127.0.0.1:5191').replace(/\/$/, '');
let token = '';
async function authorize() {
  const response = await fetch(`${serviceUrl}/session`);
  if (!response.ok) throw new Error('无法连接本地工程服务，请运行 npm run service');
  token = (await response.json() as { token: string }).token;
}
export async function projectApi<T>(path: string, body?: unknown): Promise<T> {
  if (!token) await authorize();
  const response = await fetch(serviceUrl + path, { method: body === undefined ? 'GET' : 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  if (response.status === 401) { token = ''; throw new ProjectApiError('工程服务已重启，请重试以重新连接', response.status); }
  const data = await response.json();
  if (!response.ok) throw new ProjectApiError(data.error ?? `HTTP ${response.status}`, response.status);
  return data as T;
}
export async function importBgm(file: File): Promise<VideoProject> {
  if (!token) await authorize();
  const response = await fetch(`${serviceUrl}/import-audio`, { method: 'POST', headers: { authorization: `Bearer ${token}`, 'x-file-name': encodeURIComponent(file.name) }, body: file });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error ?? `HTTP ${response.status}`);
  return data;
}
export const projectFile = (projectId: string, file: string) => `${serviceUrl}/projects/${projectId}/files/${file}`;
