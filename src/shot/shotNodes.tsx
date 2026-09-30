// shotNodes.tsx — 单镜头工坊的节点组件：歌曲/风格上下文、规划器、紧凑镜头卡片。
import { Handle, Position, type Node, type NodeProps } from '@xyflow/react';
import { AudioLines, Clapperboard, Palette, Sparkles, WandSparkles, X } from 'lucide-react';
import type { ReactNode } from 'react';
import type { PlannedCard } from './planner';
import type { ShotCardRuntime, ShotCardStatus } from './model';
import { isShotBusy } from './model';
import { MAX_SHOT_REPAIRS } from './validation';
export type { ShotCardRuntime, ShotCardStatus } from './model';

export type ShotCardData = {
  card: PlannedCard;
  index: number;
  selected: boolean;
} & ShotCardRuntime & Record<string, unknown>;

export type ShotCardNode = Node<ShotCardData, 'plan-card'>;

export type PlanDirectorData = {
  state: 'empty' | 'planning' | 'done' | 'error';
  source: 'builtin' | 'llm' | 'mcp' | null;
  cardCount: number;
  warnings: string[];
  concept: string;
  busyLabel: string;
  error?: string;
  hasProvider: boolean;
  /** MCP 队列中等待 agent 的请求数。 */
  queuePending: number;
  queueError: string;
  onConceptChange: (v: string) => void;
  onLlmPlan: () => void;
  onBuiltinPlan: () => void;
  onGenerateAll: () => void;
  onGenerateBuiltin: () => void;
  onCancelAll: () => void;
  generating: number;
  ready: number;
} & Record<string, unknown>;

export type PlanDirectorNode = Node<PlanDirectorData, 'plan-director'>;

export type SongContextData = { variant: 'data' | 'style' } & Record<string, unknown>;
export type SongContextNode = Node<SongContextData, 'song-context'>;

const statusDot: Record<ShotCardStatus, string> = {
  planned: 'stale',
  generating: 'miss',
  validating: 'miss',
  repairing: 'miss',
  ready: 'hit',
  stale: 'stale',
  error: 'miss',
};
const statusLabel: Record<ShotCardStatus, string> = {
  planned: '规划',
  generating: '生成中',
  validating: '校验中',
  repairing: '自动修复中',
  ready: '就绪',
  stale: '待重算',
  error: '出错',
};

export function SongContextNodeView({ data }: NodeProps<SongContextNode>) {
  if (data.variant === 'data') {
    return (
      <div className="studio-node pdoom-node shot-context">
        <div className="node-header pdoom-header-yellow">
          <div className="node-icon icon-yellow"><AudioLines size={15} /></div>
          <div className="node-heading"><span className="node-eyebrow">输入 / 全曲分析</span><strong>歌词 × 节拍 × 段落</strong></div>
        </div>
        <div className="node-body pdoom-body">
          <div className="pdoom-summary">真实管线产物：Demucs → CTC+Whisper 对齐 → librosa 节拍。规划器直接听这份数据。</div>
          <div className="pdoom-details">
            <div><span className="pdoom-check">·</span>46 行词级歌词 · 14 个段落</div>
            <div><span className="pdoom-check">·</span>132.007 BPM · 345 beats / 87 downbeats</div>
            <div><span className="pdoom-check">·</span>30fps 六路包络 + kick/snare onset</div>
          </div>
        </div>
        <div className="node-footer"><span>full-song.json</span><span className="footer-code">DATA</span></div>
        <Handle type="source" position={Position.Right} />
      </div>
    );
  }
  const swatches: Array<[string, string]> = [
    ['ink', '#0A0A0B'], ['ink2', '#151517'], ['graphite', '#5E5B57'], ['ash', '#9C978F'],
    ['bone', '#EEE9DF'], ['signal', '#FF4D12'], ['ember', '#FF8A3D'], ['blood', '#C21D0B'], ['acid', '#D8FF3C'],
  ];
  return (
    <div className="studio-node pdoom-node shot-context">
      <div className="node-header pdoom-header-mint">
        <div className="node-icon icon-mint"><Palette size={15} /></div>
        <div className="node-heading"><span className="node-eyebrow">控制 / 视觉规范</span><strong>风格圣经（mini）</strong></div>
      </div>
      <div className="node-body pdoom-body">
        <div className="pdoom-summary">全片共享一个色板与排版；signal 橙是唯一强调色，只给火花与唱到的词。</div>
        <div className="shot-swatches">
          {swatches.map(([name, hex]) => (
            <span key={name} className="shot-swatch" title={`${name} ${hex}`} style={{ background: hex, borderColor: hex === '#0A0A0B' || hex === '#151517' ? '#3a3a3d' : hex }} />
          ))}
        </div>
        <div className="pdoom-details">
          <div><span className="pdoom-check">·</span>确定性：t 的纯函数，禁 Math.random / Date.now</div>
          <div><span className="pdoom-check">·</span>大变化落在拍上，歌词永不跑在人声前面</div>
        </div>
      </div>
      <div className="node-footer"><span>palette + 排版 + 铁律</span><span className="footer-code">STYLE</span></div>
      <Handle type="source" position={Position.Right} />
    </div>
  );
}

function DirectorButton({ label, icon, onClick, disabled, primary }: { label: string; icon: ReactNode; onClick: () => void; disabled?: boolean; primary?: boolean }) {
  return (
    <button className={`mini-button ${primary ? 'pdoom-run' : ''}`} onClick={onClick} disabled={disabled}>
      {icon} {label}
    </button>
  );
}

export function PlanDirectorNodeView({ data }: NodeProps<PlanDirectorNode>) {
  const stateChip = data.state === 'empty' ? '等待规划'
    : data.state === 'planning' ? (data.busyLabel || '规划中…')
    : data.state === 'error' ? '规划出错'
    : `${data.cardCount} 张卡片 · ${data.source === 'llm' ? 'LLM 规划' : data.source === 'mcp' ? 'MCP agent 规划' : '内置参考'}`;
  const mcp = !data.hasProvider;
  return (
    <div className="studio-node pdoom-node plan-director">
      <div className="node-header pdoom-header-blue">
        <div className="node-icon icon-blue"><Clapperboard size={15} /></div>
        <div className="node-heading"><span className="node-eyebrow">AI 规划器 / 时间线导演</span><strong>听歌 → 规划镜头卡片带</strong></div>
        <span className={`cache-chip cache-${data.state === 'error' ? 'miss' : data.state === 'planning' ? 'miss' : data.state === 'empty' ? 'cold' : 'hit'}`}>
          <span className="cache-dot" />{stateChip}
        </span>
      </div>
      <div className="node-body pdoom-body shot-card-body">
        <label className="group-label shot-prompt-label">概念输入（一句话告诉 AI 这支 MV 想讲什么；留空则按歌曲自身叙事）</label>
        <textarea
          className="shot-prompt"
          rows={2}
          value={data.concept}
          placeholder="例：末日论文的插图版画——P(doom) 每次副歌被上调一格"
          onChange={(event) => data.onConceptChange(event.target.value)}
          spellCheck={false}
        />
        <div className="shot-actions">
          <DirectorButton
            label={data.state === 'planning' ? (mcp ? '已入队，等 agent…' : '规划中…') : mcp ? 'AI 规划全曲（MCP 队列）' : 'AI 规划全曲'}
            icon={<WandSparkles size={12} />}
            onClick={data.onLlmPlan}
            disabled={data.state === 'planning'}
            primary
          />
          <DirectorButton label="内置参考规划" icon={<Sparkles size={12} />} onClick={data.onBuiltinPlan} disabled={data.state === 'planning'} />
          <DirectorButton
            label={data.generating > 0 ? `处理中 ${data.generating}` : data.cardCount === 0 ? '先规划' : mcp ? '批量生成（MCP 队列）' : '批量生成场景'}
            icon={<Sparkles size={12} />}
            onClick={data.onGenerateAll}
            disabled={data.cardCount === 0 || data.generating > 0 || data.ready === data.cardCount}
          />
          {data.generating > 0 && <DirectorButton label="取消全部任务" icon={<X size={12} />} onClick={data.onCancelAll} />}
          {mcp && data.cardCount > 0 && (
            <DirectorButton label="本地模板生成（不等待）" icon={<Sparkles size={12} />} onClick={data.onGenerateBuiltin} disabled={data.generating > 0 || data.ready === data.cardCount} />
          )}
        </div>
        {mcp && <div className="shot-lint">ⓘ MCP 模式：请求写入本地队列（.queue/），由 ZCode agent 通过 shot_queue_* 工具生成并提交——无需 API key。急用时可「本地模板生成」。</div>}
        {data.queuePending > 0 && <div className="plan-progress"><span>队列中 {data.queuePending} 个请求等待 agent…</span></div>}
        {data.queueError && <div className="shot-error" role="status">{data.queueError}</div>}
        {data.error && <div className="shot-error">{data.error}</div>}
        {data.warnings.length > 0 && <div className="shot-lint">{data.warnings.slice(0, 3).map((w) => <div key={w}>⚠ {w}</div>)}</div>}
        {data.cardCount > 0 && (
          <div className="plan-progress">
            <span>就绪 {data.ready}/{data.cardCount}</span>
            <div className="shot-progress"><div className="shot-progress-fill" style={{ width: `${Math.round((data.ready / data.cardCount) * 100)}%` }} /></div>
          </div>
        )}
      </div>
      <div className="node-footer"><span>{data.source === 'llm' ? 'LLM timeline' : data.source === 'mcp' ? 'MCP timeline' : data.source === 'builtin' ? 'reference timeline' : 'waiting'}</span><span className="footer-code">PLAN</span></div>
      <Handle type="target" position={Position.Left} />
      <Handle type="source" position={Position.Right} />
    </div>
  );
}

export function ShotCardNodeView({ data, selected }: NodeProps<ShotCardNode>) {
  const dur = data.card.window.end - data.card.window.start;
  return (
    <div className={`studio-node pdoom-node plan-card ${selected ? 'is-selected' : ''}`}>
      <div className="node-header pdoom-header-violet">
        <div className="node-icon icon-violet"><Clapperboard size={13} /></div>
        <div className="node-heading">
          <span className="node-eyebrow">{String(data.index + 1).padStart(2, '0')} · {data.card.window.start.toFixed(1)}–{data.card.window.end.toFixed(1)}s（{dur.toFixed(1)}s）</span>
          <strong>{data.card.title}</strong>
        </div>
        <span className={`cache-chip cache-${statusDot[data.status]}`}><span className="cache-dot" />{data.status === 'repairing' ? `修复 ${data.validation?.attempt ?? 1}/${MAX_SHOT_REPAIRS}` : statusLabel[data.status]}</span>
      </div>
      <div className="node-body plan-card-body">
        {data.thumb ? (
          <img className="plan-card-thumb" src={data.thumb} alt={data.card.title} />
        ) : (
          <div className="plan-card-thumb plan-card-empty">{isShotBusy(data.status) ? statusLabel[data.status] + '…' : '尚未生成场景'}</div>
        )}
        <div className="plan-card-prompt">{data.card.prompt}</div>
        {data.error && <div className="plan-card-error">{data.error.slice(0, 90)}</div>}
      </div>
      <div className="node-footer">
        <span>{data.source === 'llm' ? 'LLM' : data.source === 'mcp' ? `MCP · ${data.model ?? 'agent'}` : data.source === 'builtin' ? `模板 · ${data.motif ?? ''}` : data.status === 'generating' ? '等待 agent' : '—'}{data.rev > 0 ? ` · rev_${data.rev}` : ''}</span>
        <span className="footer-code">SHOT</span>
      </div>
      <Handle type="target" position={Position.Left} />
    </div>
  );
}

export const shotNodeTypes = {
  'song-context': SongContextNodeView,
  'plan-director': PlanDirectorNodeView,
  'plan-card': ShotCardNodeView,
};
