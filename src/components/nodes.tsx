import { useEffect, useRef, useState } from 'react';
import { Position, Handle, type Edge, type Node, type NodeProps } from '@xyflow/react';
import {
  Check,
  ChevronDown,
  CircleDashed,
  Clapperboard,
  Code2,
  Database,
  Film,
  Gauge,
  GitBranch,
  LoaderCircle,
  Lock,
  MessageSquareText,
  Navigation,
  Play,
  Sparkles,
  Terminal,
  Unlock,
  WandSparkles,
} from 'lucide-react';
import type { NodeStatus, PromptSpec, SceneCode, TechStack } from '../types';
import { techLabels } from '../types';
import { layerMeta, type MemoryLayer } from '../memory/store';
import { runPreview } from '../render/preview';

export type PromptData = {
  kind: 'prompt';
  status: NodeStatus;
  value: PromptSpec;
  onChange: (value: PromptSpec) => void;
};

export type SteerData = {
  kind: 'steer';
  status: NodeStatus;
  direction: string;
  onChange: (value: string) => void;
};

export type CodeData = {
  kind: 'code';
  status: NodeStatus;
  techStack: TechStack;
  output?: SceneCode;
  providerLabel: string;
  locked: boolean;
  directionReady: boolean;
  onTechChange: (techStack: TechStack) => void;
  onGenerate: () => void;
  onToggleLock: () => void;
};

export type RenderDone = { frames: number; seconds: number; unsupported?: boolean; message?: string };

export type RenderData = {
  kind: 'render';
  status: NodeStatus;
  code: { code: string; techStack: TechStack; seed: number } | null;
  fps: number;
  resolution: string;
  onRender: () => void;
  onRendered: (result: RenderDone) => void;
};

export type ActShotRef = { label: string; revision?: number; locked: boolean };

export type ActData = {
  kind: 'act';
  status: NodeStatus;
  name: string;
  brief: string;
  shots: ActShotRef[];
  onNameChange: (value: string) => void;
  onBriefChange: (value: string) => void;
};

export type MemoryCardData = {
  kind: 'memory';
  counts: Array<{ layer: MemoryLayer; count: number }>;
  recent: string[];
};

export type StudioNodeData = PromptData | SteerData | CodeData | RenderData | ActData | MemoryCardData;
export type StudioNode = Node<StudioNodeData>;
export type AnyGraphNode = StudioNode | import('./pdoomNodes').PdoomNode;

const statusLabels: Record<NodeStatus, string> = {
  idle: '空闲',
  ready: '就绪',
  running: '运行中',
  success: '完成',
  stale: '待更新',
  error: '错误',
};

function NodeHeader({
  icon,
  eyebrow,
  title,
  status,
  accent,
  extra,
}: {
  icon: React.ReactNode;
  eyebrow: string;
  title: string;
  status: NodeStatus;
  accent: 'mint' | 'blue' | 'orange' | 'violet';
  extra?: React.ReactNode;
}) {
  return (
    <div className="node-header">
      <div className={`node-icon icon-${accent}`}>{icon}</div>
      <div className="node-heading">
        <span className="node-eyebrow">{eyebrow}</span>
        <strong>{title}</strong>
      </div>
      {extra}
      <span className={`status status-${status}`}>{statusLabels[status]}</span>
    </div>
  );
}

function Field({ label, value, onChange, rows = 2 }: { label: string; value: string; onChange: (value: string) => void; rows?: number }) {
  return (
    <label className="field">
      <span className="control-label">{label}</span>
      <textarea value={value} onChange={(event) => onChange(event.target.value)} rows={rows} />
    </label>
  );
}

export function PromptNode({ data, selected }: NodeProps<StudioNode>) {
  const prompt = data as PromptData;
  const update = (key: keyof PromptSpec, value: string) => prompt.onChange({ ...prompt.value, [key]: value });
  return (
    <div className={`studio-node prompt-node ${selected ? 'is-selected' : ''}`}>
      <Handle type="source" position={Position.Right} id="prompt-output" className="handle handle-mint" />
      <NodeHeader icon={<MessageSquareText size={15} />} eyebrow="输入 / 提示词" title="场景提示词" status={prompt.status} accent="mint" />
      <div className="node-body prompt-body">
        <Field label="镜头描述" value={prompt.value.scene} onChange={(value) => update('scene', value)} />
        <Field label="视觉风格" value={prompt.value.style} onChange={(value) => update('style', value)} />
        <Field label="镜头运动" value={prompt.value.motion} onChange={(value) => update('motion', value)} />
        <Field label="约束条件" value={prompt.value.constraints} onChange={(value) => update('constraints', value)} />
      </div>
      <div className="node-footer"><span><Sparkles size={12} /> 4 路提示词输入</span><span className="footer-code">PROMPT_SPEC</span></div>
    </div>
  );
}

export function SteerNode({ data, selected }: NodeProps<StudioNode>) {
  const steer = data as SteerData;
  return (
    <div className={`studio-node steer-node ${selected ? 'is-selected' : ''}`}>
      <Handle type="source" position={Position.Right} id="steer-output" className="handle handle-violet" />
      <NodeHeader icon={<Navigation size={15} />} eyebrow="输入 / 修改方向" title="修改方向补丁" status={steer.status} accent="violet" />
      <div className="node-body">
        <Field label="修改方向" value={steer.direction} onChange={steer.onChange} rows={4} />
        <div className="steer-note">接入「镜头编译器」后，这段方向会连同当前代码一起作为「修订指令」注入下一次生成，产出新版本。</div>
      </div>
      <div className="node-footer"><span><Navigation size={12} /> 附属 / 可选</span><span className="footer-code">STEER_SPEC</span></div>
    </div>
  );
}

export function CodeNode({ data, selected }: NodeProps<StudioNode>) {
  const code = data as CodeData;
  const preview = code.output
    ? code.output.code.split('\n').slice(0, 9).join('\n') + (code.output.lines > 9 ? `\n… +${code.output.lines - 9} 行` : '')
    : '// 连接「场景提示词」后开始生成';
  const buttonLabel = code.locked
    ? '已锁定 · 解锁后可重新生成'
    : code.directionReady
      ? '应用修改方向 → 新版本'
      : '生成镜头代码';
  return (
    <div className={`studio-node code-node ${selected ? 'is-selected' : ''} ${code.locked ? 'is-locked' : ''}`}>
      <Handle type="target" position={Position.Left} id="prompt-input" className="handle handle-mint" />
      <Handle type="target" position={Position.Left} id="steer-input" className="handle handle-violet handle-low" />
      <Handle type="source" position={Position.Right} id="code-output" className="handle handle-blue" />
      <NodeHeader
        icon={<Code2 size={15} />}
        eyebrow="LLM / 镜头代码生成"
        title="镜头编译器"
        status={code.status}
        accent="blue"
        extra={code.locked ? <span className="lock-chip"><Lock size={11} /> 已锁定</span> : null}
      />
      <div className="node-body">
        <label className="control-label">目标技术栈</label>
        <div className="select-wrap">
          <select value={code.techStack} disabled={code.locked} onChange={(event) => code.onTechChange(event.target.value as TechStack)}>
            {Object.entries(techLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}
          </select>
          <ChevronDown size={14} />
        </div>
        <div className="code-preview">
          <div className="code-preview-top">
            <span><Terminal size={12} /> scene.ts</span>
            <span>{code.output ? `rev_${String(code.output.revision).padStart(2, '0')} · ${code.output.source === 'llm' ? code.output.model ?? 'llm' : '模拟'}` : '等待输入'}</span>
          </div>
          <code>{preview}</code>
        </div>
        <button className="action-button button-blue" onClick={code.onGenerate} disabled={code.status === 'running' || code.locked}>
          {code.status === 'running' ? <LoaderCircle className="spin" size={14} /> : code.locked ? <Lock size={14} /> : <WandSparkles size={14} />}
          {buttonLabel}
        </button>
        <div className="code-actions">
          <button className={`mini-button ${code.locked ? 'accent-violet' : ''}`} onClick={code.onToggleLock}>
            {code.locked ? <><Unlock size={12} /> 解锁以修改</> : <><Lock size={12} /> 生成后自动锁定</>}
          </button>
          <div className="provider-line">{code.providerLabel}</div>
        </div>
      </div>
      <div className="node-footer"><span><GitBranch size={12} /> 镜头级 / 沙箱隔离</span><span className="footer-code">SCENE_CODE</span></div>
    </div>
  );
}

export function RenderNode({ data, selected }: NodeProps<StudioNode>) {
  const render = data as RenderData;
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const taskRef = useRef(render.code);
  taskRef.current = render.code;
  const [progress, setProgress] = useState<number | null>(null);
  const [done, setDone] = useState<{ frames: number; seconds: number } | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const taskKey = render.code ? `${render.code.techStack}:${render.code.seed}` : 'none';

  useEffect(() => {
    if (render.status !== 'running') return;
    const canvas = canvasRef.current;
    const task = taskRef.current;
    if (!canvas || !task) return;
    let cancelled = false;
    setDone(null);
    setPreviewError(null);
    setProgress(0);
    runPreview(canvas, task, (frame) => { if (!cancelled) setProgress(frame); }, () => cancelled)
      .then((result) => {
        if (cancelled) return;
        setProgress(null);
        setDone(result);
        render.onRendered(result);
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        setProgress(null);
        const message = error instanceof Error ? error.message : String(error);
        setPreviewError(message);
        render.onRendered({ frames: 0, seconds: 0, unsupported: true, message });
      });
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [render.status, taskKey]);

  return (
    <div className={`studio-node render-node ${selected ? 'is-selected' : ''}`}>
      <Handle type="target" position={Position.Left} id="code-input" className="handle handle-blue" />
      <NodeHeader icon={<Film size={15} />} eyebrow="输出 / 渲染" title="帧渲染器" status={render.status} accent="orange" />
      <div className="node-body">
        <div className="render-settings">
          <div><label className="control-label">分辨率</label><div className="readout">{render.resolution}</div></div>
          <div><label className="control-label">帧率</label><div className="readout">{render.fps}</div></div>
        </div>
        <div className="render-preview">
          <canvas ref={canvasRef} className="preview-canvas" width={480} height={270} />
          {previewError
            ? <div className="preview-label bad">{previewError}</div>
            : progress !== null
              ? <div className="preview-label"><LoaderCircle className="spin" size={12} /> 渲染中… {progress + 1}/180 帧</div>
              : done
                ? <div className="preview-label"><Check size={12} /> {done.frames} 帧 · {done.seconds.toFixed(1)}s · 60fps</div>
                : render.code
                  ? <div className="preview-label muted"><CircleDashed size={12} /> 就绪 · 点击下方按钮渲染 3 秒</div>
                  : <div className="preview-label muted"><CircleDashed size={12} /> 未生成画面</div>}
        </div>
        <button className="action-button button-orange" onClick={render.onRender} disabled={render.status === 'running' || !render.code}>
          {render.status === 'running' ? <LoaderCircle className="spin" size={14} /> : <Play size={14} />}
          {render.status === 'running' ? '正在渲染…' : '渲染 3 秒预览'}
        </button>
      </div>
      <div className="node-footer"><span><Gauge size={12} /> 预览 / 3 秒 · 180 帧</span><span className="footer-code">FRAME_PREVIEW</span></div>
    </div>
  );
}

export function ActNode({ data, selected }: NodeProps<StudioNode>) {
  const act = data as ActData;
  return (
    <div className={`studio-node act-node ${selected ? 'is-selected' : ''}`}>
      <Handle type="target" position={Position.Left} id="shots-in" className="handle handle-blue" />
      <Handle type="source" position={Position.Right} id="act-output" className="handle handle-mint" />
      <NodeHeader icon={<Clapperboard size={15} />} eyebrow="编排 / 幕" title={act.name || '幕导演'} status={act.status} accent="violet" />
      <div className="node-body">
        <label className="field">
          <span className="control-label">幕名称</span>
          <input className="act-name-input" value={act.name} onChange={(event) => act.onNameChange(event.target.value)} disabled={false} />
        </label>
        <Field label="幕简报（自动注入镜头生成）" value={act.brief} onChange={act.onBriefChange} rows={3} />
        <div className="shot-list">
          <span className="control-label">成员镜头 · {act.shots.length}</span>
          {act.shots.length === 0 && <div className="shot-row muted">未连接镜头——把「镜头编译器」的输出连到本卡。</div>}
          {act.shots.map((shot) => (
            <div className="shot-row" key={shot.label}>
              <Code2 size={12} />
              <span>{shot.label}</span>
              <span className="shot-rev">{shot.revision !== undefined ? `rev_${String(shot.revision).padStart(2, '0')}` : '—'}</span>
              <span className={`shot-lock ${shot.locked ? 'on' : ''}`}>{shot.locked ? <Lock size={11} /> : <Unlock size={11} />}</span>
            </div>
          ))}
        </div>
      </div>
      <div className="node-footer"><span><Clapperboard size={12} /> 幕级管控</span><span className="footer-code">ACT_BRIEF</span></div>
    </div>
  );
}

export function MemoryNode({ data, selected }: NodeProps<StudioNode>) {
  const memory = data as MemoryCardData;
  const max = Math.max(1, ...memory.counts.map((c) => c.count));
  return (
    <div className={`studio-node memory-node ${selected ? 'is-selected' : ''}`}>
      <Handle type="target" position={Position.Left} id="act-input" className="handle handle-mint" />
      <NodeHeader icon={<Database size={15} />} eyebrow="工作区 / 记忆" title="工作区记忆" status="success" accent="mint" />
      <div className="node-body">
        <div className="mem-rows">
          {memory.counts.map(({ layer, count }) => (
            <div className="mem-row" key={layer}>
              <span className={`layer-badge tone-${layerMeta[layer].tone}`}>{layerMeta[layer].label}</span>
              <div className="mem-bar"><span style={{ width: `${Math.round((count / max) * 100)}%` }} /></div>
              <span className="mem-count">{count}</span>
            </div>
          ))}
        </div>
        <div className="mem-recent">
          <span className="control-label">最近情节记忆</span>
          {memory.recent.length === 0 && <div className="shot-row muted">暂无生成记录。</div>}
          {memory.recent.map((title) => <div className="mem-recent-item" key={title}>{title}</div>)}
        </div>
        <div className="steer-note">生成时自动注入：L5 硬规则 + L4 风格法则 + 最近 3 条情节记忆 + 幕级上下文。</div>
      </div>
      <div className="node-footer"><span><Database size={12} /> 工作区级</span><span className="footer-code">MEMORY_STORE</span></div>
    </div>
  );
}

export const nodeTypes = {
  prompt: PromptNode,
  steer: SteerNode,
  code: CodeNode,
  render: RenderNode,
  act: ActNode,
  memory: MemoryNode,
};

export interface CanvasModel {
  prompt: PromptSpec;
  onPromptChange: (value: PromptSpec) => void;
  steer: { status: NodeStatus; direction: string; onChange: (value: string) => void };
  code: Omit<CodeData, 'kind'>;
  render: Omit<RenderData, 'kind'>;
  act: Omit<ActData, 'kind'>;
  memory: Omit<MemoryCardData, 'kind'>;
}

export type NodeKind = 'prompt' | 'steer' | 'code' | 'render' | 'act' | 'memory';

/** 按节点种类从当前工作区模型构造 data（预置节点与拖拽新增节点共用）。 */
export function nodeData(kind: NodeKind, model: CanvasModel): StudioNodeData {
  switch (kind) {
    case 'prompt':
      return { kind: 'prompt', status: 'ready', value: { ...model.prompt }, onChange: model.onPromptChange };
    case 'steer':
      return { kind: 'steer', status: 'ready', direction: '', onChange: model.steer.onChange };
    case 'code':
      return { kind: 'code', ...model.code };
    case 'render':
      return { kind: 'render', ...model.render };
    case 'act':
      return { kind: 'act', ...model.act };
    case 'memory':
      return { kind: 'memory', ...model.memory };
  }
}

export function createNodes(model: CanvasModel): StudioNode[] {
  return [
    { id: 'prompt-1', type: 'prompt', position: { x: 40, y: 110 }, data: nodeData('prompt', model) },
    { id: 'steer-1', type: 'steer', position: { x: 40, y: 470 }, data: nodeData('steer', model) },
    { id: 'code-1', type: 'code', position: { x: 460, y: 210 }, data: nodeData('code', model) },
    { id: 'render-1', type: 'render', position: { x: 950, y: 80 }, data: nodeData('render', model) },
    { id: 'act-1', type: 'act', position: { x: 950, y: 400 }, data: nodeData('act', model) },
    { id: 'memory-1', type: 'memory', position: { x: 950, y: 680 }, data: nodeData('memory', model) },
  ];
}

export const initialEdges: Edge[] = [
  { id: 'prompt-code', source: 'prompt-1', sourceHandle: 'prompt-output', target: 'code-1', targetHandle: 'prompt-input', animated: true, className: 'edge-mint' },
  { id: 'steer-code', source: 'steer-1', sourceHandle: 'steer-output', target: 'code-1', targetHandle: 'steer-input', animated: true, className: 'edge-violet' },
  { id: 'code-render', source: 'code-1', sourceHandle: 'code-output', target: 'render-1', targetHandle: 'code-input', animated: true, className: 'edge-blue' },
  { id: 'code-act', source: 'code-1', sourceHandle: 'code-output', target: 'act-1', targetHandle: 'shots-in', animated: true, className: 'edge-blue' },
  { id: 'act-memory', source: 'act-1', sourceHandle: 'act-output', target: 'memory-1', targetHandle: 'act-input', animated: true, className: 'edge-mint' },
];
