export interface ProjectFeedback { id: string; text: string; status: 'pending' | 'responded' | 'accepted'; baseInputRevision: number }
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
  analysis: { source: string; note: string };
  song: { song: string; duration: number; bpm: number };
  output: { fps: number; samples: number };
  credits: string;
  shots: ProjectShot[];
  transitions: ProjectTransition[];
}
export interface ProjectJob {
  id: string;
  kind: 'validate' | 'validate-transition' | 'export';
  status: string;
  progress: number;
  detail?: string;
  error?: string;
  inputRevision: number;
  shotId?: string;
  transitionId?: string;
  result?: { file?: string; frames?: number; seconds?: number; reports?: Array<{ cached: boolean }> };
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
  if (response.status === 401) { token = ''; throw new Error('工程服务已重启，请重试以重新连接'); }
  const data = await response.json();
  if (!response.ok) throw new Error(data.error ?? `HTTP ${response.status}`);
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
