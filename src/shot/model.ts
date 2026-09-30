// model.ts — 卡片输入、运行状态与已验证产物；不依赖 React/ReactFlow。
import type { PlannedCard } from './planner';
import type { ShotDraw } from './engine';
import type { ShotValidationReport } from './validation';

export type ShotSource = 'llm' | 'mcp' | 'builtin';
export type ShotCardStatus = 'planned' | 'generating' | 'validating' | 'repairing' | 'ready' | 'stale' | 'error';
export const isShotBusy = (status: ShotCardStatus): boolean =>
  status === 'generating' || status === 'validating' || status === 'repairing';

export interface ShotCardRuntime {
  status: ShotCardStatus;
  /** 成功产物版本，区别于用户编辑的 inputRevision。 */
  rev: number;
  source: ShotSource | null;
  model?: string;
  summary?: string;
  error?: string;
  lint: string[];
  thumb?: string;
  motif?: string;
  validation?: ShotValidationReport;
}

export interface ShotArtifact {
  code: string;
  draw: ShotDraw;
  inputRevision: number;
  rev: number;
  source: ShotSource;
  summary: string;
  model?: string;
  motif?: string;
  thumb: string;
  validation: ShotValidationReport;
}

export interface ShotCardEntry extends ShotCardRuntime {
  card: PlannedCard;
  inputRevision: number;
  /** 只在校验成功后替换；失败/编辑时保留上一次好结果，不冒充当前版本。 */
  artifact?: ShotArtifact;
}
