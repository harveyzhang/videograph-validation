export type NodeStatus = 'idle' | 'ready' | 'running' | 'success' | 'stale' | 'error';
export type TechStack = 'three-webgl' | 'remotion-react' | 'canvas-2d';

export interface PromptSpec {
  scene: string;
  style: string;
  motion: string;
  constraints: string;
}

export interface UsageInfo {
  input?: number;
  output?: number;
}

export interface SceneCode {
  revision: number;
  techStack: TechStack;
  summary: string;
  code: string;
  lines: number;
  source: 'simulation' | 'llm';
  model?: string;
  usage?: UsageInfo;
}

export interface RenderResult {
  frame: string;
  duration: string;
  artifact: string;
}

export const techLabels: Record<TechStack, string> = {
  'three-webgl': 'Three / WebGL',
  'remotion-react': 'Remotion / React',
  'canvas-2d': 'Canvas 2D',
};

export const pad = (value: number) => String(value).padStart(2, '0');
