import { lazy, Suspense, useCallback, useEffect, useMemo, useRef, useState, type DragEvent } from 'react';
import { createRoot } from 'react-dom/client';
import {
  addEdge,
  Background,
  BackgroundVariant,
  Controls,
  MiniMap,
  ReactFlow,
  ReactFlowProvider,
  useEdgesState,
  useNodesState,
  useReactFlow,
  type Connection,
  type Edge,
} from '@xyflow/react';
import {
  Activity,
  Braces,
  BriefcaseBusiness,
  Camera,
  CircleDashed,
  Download,
  Film,
  GitBranch,
  Layers3,
  Plug,
  Plus,
  Palette,
  RotateCcw,
  Settings2,
  Sparkles,
  WandSparkles,
  Zap,
} from 'lucide-react';
import '@xyflow/react/dist/style.css';
import './styles.css';
import { createNodes, initialEdges, nodeData, nodeTypes, type AnyGraphNode, type NodeKind, type RenderDone, type StudioNode } from './components/nodes';
import { pdoomInitialEdges, pdoomInitialNodes, pdoomNodeTypes, type PdoomNode } from './components/pdoomNodes';
import { creativeInitialEdges, creativeInitialNodes, creativeNodeTypes, type CreativeNode } from './components/creativeNodes';
import { researchInitialNodes, researchNodeTypes, type CreativeResearchNode } from './components/researchNodes';
import { SettingsModal } from './components/SettingsModal';
import { MemoryPanel } from './components/MemoryPanel';
import { BlackboardPanel } from './components/BlackboardPanel';
import { generateSceneCode, simulateSceneCode } from './llm/adapters';
import { useProviders } from './llm/storage';
import { useMemory } from './memory/store';
import type { MemoryLayer } from './memory/store';
import { useBlackboard } from './blackboard/store';
import { ShotWorkshop } from './shot/ShotWorkshop';
import { pad, type NodeStatus, type PromptSpec, type SceneCode } from './types';

const ProjectStudio = lazy(() => import('./project/ProjectStudio'));

const initialPrompt: PromptSpec = {
  scene: 'A lone signal tower rises through a midnight ocean of data.',
  style: 'Cinematic cybernetic, graphite black, electric mint highlights.',
  motion: 'Slow orbital camera, then a sharp forward push on the beat.',
  constraints: 'No photoreal people. Keep typography legible. Deterministic motion.',
};

const initialDirection = 'Push density up on the beat: more particles, tighter camera, keep the mint palette.';

const initialActBrief = 'Act I — Emergence. Cold open, sparse geometry, one signal growing. Shots stay low-density and slow until the final bar, then snap.';

const nodeNames: Record<string, string> = {
  'prompt-1': '场景提示词',
  'steer-1': '修改方向补丁',
  'code-1': '镜头编译器（镜头级）',
  'render-1': '帧渲染器',
  'act-1': '幕导演（幕级）',
  'memory-1': '工作区记忆（工作区级）',
};

function Studio() {
  const [prompt, setPrompt] = useState(initialPrompt);
  const [direction, setDirection] = useState(initialDirection);
  const [actName, setActName] = useState('Act I · Emergence');
  const [actBrief, setActBrief] = useState(initialActBrief);
  const [techStack, setTechStack] = useState<'three-webgl' | 'remotion-react' | 'canvas-2d'>('three-webgl');
  const [codeStatus, setCodeStatus] = useState<NodeStatus>('ready');
  const [steerStatus, setSteerStatus] = useState<NodeStatus>('ready');
  const [renderStatus, setRenderStatus] = useState<NodeStatus>('idle');
  const [locked, setLocked] = useState(false);
  const [codeOutput, setCodeOutput] = useState<SceneCode>();
  const [renderOutput, setRenderOutput] = useState<{ frames: number; seconds: number }>();
  const [selectedId, setSelectedId] = useState('code-1');
  const [runCount, setRunCount] = useState(0);
  const [lastError, setLastError] = useState<string | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);
  // ?view=shot|pdoom|legacy 直达某个工作区（分享/书签用）；默认创意工作区。
  const [initialView] = useState(() => new URLSearchParams(window.location.search).get('view'));
  const [pdoomMode, setPdoomMode] = useState(initialView === 'pdoom');
  const [creativeMode, setCreativeMode] = useState(initialView !== 'shot' && initialView !== 'pdoom' && initialView !== 'legacy');
  const [shotMode, setShotMode] = useState(initialView === 'shot');
  const [nodes, setNodes, onNodesChange] = useNodesState<StudioNode>([]);
  const [pdoomNodes, setPdoomNodes, onPdoomNodesChange] = useNodesState<PdoomNode>(pdoomInitialNodes);
  const [creativeNodes, setCreativeNodes, onCreativeNodesChange] = useNodesState<CreativeNode>(creativeInitialNodes);
  const [researchNodes, setResearchNodes, onResearchNodesChange] = useNodesState<CreativeResearchNode>(researchInitialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>(initialEdges);
  const [pdoomEdges, setPdoomEdges, onPdoomEdgesChange] = useEdgesState<Edge>(pdoomInitialEdges as Edge[]);
  const [creativeEdges, setCreativeEdges, onCreativeEdgesChange] = useEdgesState<Edge>(creativeInitialEdges as Edge[]);
  const providers = useProviders();
  const memory = useMemory();
  const blackboard = useBlackboard();
  const sessionStarted = useRef(false);
  const seeded = useRef(false);

  useEffect(() => {
    if (sessionStarted.current) return;
    sessionStarted.current = true;
    memory.record({
      layer: 'session',
      scope: 'studio',
      kind: 'session-start',
      title: 'Studio session started',
      text: `Canvas opened · provider=${providers.active?.name ?? 'simulation'}`,
    });
  }, [memory, providers.active]);

  const hasEdge = useCallback((id: string) => edges.some((edge) => edge.id === id), [edges]);
  const directionActive = hasEdge('steer-code') && direction.trim().length > 0;
  const actActive = hasEdge('code-act') && actBrief.trim().length > 0;

  const markStale = () => {
    setCodeStatus('stale');
    setRenderStatus('stale');
  };

  const generateCode = useCallback(async () => {
    if (locked) return;
    setCodeStatus('running');
    setRenderStatus('stale');
    setLastError(null);
    const revision = (codeOutput?.revision ?? 0) + 1;
    const provider = providers.active;
    const revising = directionActive;
    const actBriefCtx = actActive ? actBrief : undefined;

    const finish = (result: SceneCode) => {
      setCodeOutput(result);
      setCodeStatus('success');
      setLocked(true);
      if (revising) setSteerStatus('success');
      setRunCount((count) => count + 1);
      memory.record({
        layer: 'episodic',
        scope: 'scene',
        kind: revising ? 'revision' : 'generation',
        title: `rev_${pad(revision)} · ${revising ? 'steered' : ''} ${result.source === 'llm' ? result.model ?? 'llm' : 'simulation'}`.replace(/\s+/g, ' '),
        text: result.summary,
        meta: { techStack, usage: result.usage, direction: revising ? direction : undefined, act: actName },
      });
      memory.record({
        layer: 'node',
        scope: 'node:code-1',
        kind: 'revision',
        title: `rev_${pad(revision)}`,
        text: result.summary,
        meta: { techStack, source: result.source, locked: true },
      });
      memory.record({
        layer: 'session',
        scope: 'studio',
        kind: 'lock',
        title: `rev_${pad(revision)} auto-locked`,
        text: 'Generation succeeded — card locked until manual unlock.',
      });
    };

    if (!provider) {
      window.setTimeout(() => {
        const simulated = simulateSceneCode(prompt, techStack);
        finish({
          revision,
          techStack,
          summary: revising ? `${simulated.summary} (direction applied: ${direction.slice(0, 40)}…)` : simulated.summary,
          code: simulated.code,
          lines: simulated.code.split('\n').length,
          source: 'simulation',
        });
      }, 600);
      return;
    }

    try {
      const result = await generateSceneCode(provider, prompt, techStack, memory.entries, {
        actBrief: actBriefCtx,
        direction: revising ? direction : undefined,
        currentCode: revising ? codeOutput?.code : undefined,
      });
      finish({
        revision,
        techStack,
        summary: result.summary,
        code: result.code,
        lines: result.code.split('\n').length,
        source: 'llm',
        model: provider.model,
        usage: result.usage,
      });
    } catch (error) {
      const message = String(error).slice(0, 300);
      setCodeStatus('error');
      setLastError(message);
      memory.record({
        layer: 'episodic',
        scope: 'scene',
        kind: 'error',
        title: `rev_${pad(revision)} failed`,
        text: message,
        meta: { provider: provider.name, model: provider.model },
      });
    }
  }, [actActive, actBrief, actName, codeOutput, direction, directionActive, locked, memory, prompt, providers.active, techStack]);

  const toggleLock = useCallback(() => {
    setLocked((prev) => {
      const next = !prev;
      memory.record({
        layer: 'session',
        scope: 'studio',
        kind: next ? 'lock' : 'unlock',
        title: next ? `rev_${pad(codeOutput?.revision ?? 0)} locked` : `rev_${pad(codeOutput?.revision ?? 0)} unlocked`,
        text: next ? 'Manual lock — regeneration blocked.' : 'Manual unlock — regeneration allowed again.',
      });
      return next;
    });
    setCodeStatus(codeOutput ? 'stale' : 'ready');
  }, [codeOutput, memory]);

  const renderFrame = useCallback(() => {
    if (!codeOutput) {
      setCodeStatus('error');
      setLastError('请先生成镜头代码，再渲染预览。');
      return;
    }
    setLastError(null);
    setRenderStatus('running');
  }, [codeOutput]);

  const handleRendered = useCallback((result: RenderDone) => {
    if (result.unsupported) {
      setRenderStatus('error');
      setLastError(result.message ?? '该技术栈暂不支持浏览器预览。');
      return;
    }
    setRenderStatus('success');
    setRenderOutput({ frames: result.frames, seconds: result.seconds });
    if (codeOutput) {
      memory.record({
        layer: 'episodic',
        scope: 'render',
        kind: 'render',
        title: `3 秒预览 · ${result.frames} 帧`,
        text: `来自 rev_${pad(codeOutput.revision)}（${codeOutput.techStack}）的实时渲染。`,
        meta: { revision: codeOutput.revision },
      });
    }
  }, [codeOutput, memory]);

  const reset = useCallback(() => {
    setPrompt(initialPrompt);
    setDirection(initialDirection);
    setActName('Act I · Emergence');
    setActBrief(initialActBrief);
    setTechStack('three-webgl');
    setCodeOutput(undefined);
    setRenderOutput(undefined);
    setCodeStatus('ready');
    setSteerStatus('ready');
    setRenderStatus('idle');
    setLocked(false);
    setRunCount(0);
    setLastError(null);
    setSelectedId('code-1');
    setEdges(initialEdges);
  }, [setEdges]);

  const actShots = useMemo(
    () => hasEdge('code-act') ? [{ label: 'shot · scene.ts', revision: codeOutput?.revision, locked }] : [],
    [codeOutput?.revision, hasEdge, locked],
  );

  const memoryCounts = useMemo(() => {
    const layers: MemoryLayer[] = ['procedural', 'style', 'workspace', 'node', 'episodic', 'session'];
    return layers.map((layer) => ({ layer, count: memory.entries.filter((entry) => entry.layer === layer).length }));
  }, [memory.entries]);

  const memoryRecent = useMemo(
    () => memory.entries.filter((entry) => entry.layer === 'episodic').slice(-3).reverse().map((entry) => entry.title),
    [memory.entries],
  );

  const model = useMemo(() => ({
    prompt,
    onPromptChange: (value: PromptSpec) => { setPrompt(value); markStale(); },
    steer: {
      status: steerStatus,
      direction,
      onChange: (value: string) => {
        setDirection(value);
        setSteerStatus(value.trim() ? 'ready' : 'idle');
        markStale();
      },
    },
    code: {
      techStack,
      status: codeStatus,
      output: codeOutput,
      providerLabel: providers.active ? `LLM: ${providers.active.name} · ${providers.active.model}` : 'LLM: 未配置 · 使用本地模拟',
      locked,
      directionReady: directionActive,
      onTechChange: (value: 'three-webgl' | 'remotion-react' | 'canvas-2d') => { setTechStack(value); markStale(); },
      onGenerate: generateCode,
      onToggleLock: toggleLock,
    },
    render: {
      status: renderStatus,
      code: codeOutput ? { code: codeOutput.code, techStack: codeOutput.techStack, seed: 1024 + codeOutput.revision * 97 } : null,
      fps: 60,
      resolution: '1920 × 1080',
      onRender: renderFrame,
      onRendered: handleRendered,
    },
    act: {
      status: (actShots.length > 0 && actShots.every((shot) => shot.locked) ? 'success' : 'ready') as NodeStatus,
      name: actName,
      brief: actBrief,
      shots: actShots,
      onNameChange: (value: string) => { setActName(value); },
      onBriefChange: (value: string) => { setActBrief(value); markStale(); },
    },
    memory: { counts: memoryCounts, recent: memoryRecent },
  }), [actBrief, actName, actShots, codeOutput, codeStatus, direction, directionActive, generateCode, handleRendered, locked, memoryCounts, memoryRecent, prompt, providers.active, renderFrame, renderStatus, steerStatus, techStack, toggleLock]);

  const modelRef = useRef(model);
  modelRef.current = model;
  const { screenToFlowPosition } = useReactFlow();

  // 侧栏拖入：在落点处创建对应节点（数据取自当前模型，保持回调最新）。
  const onDrop = useCallback(
    (event: DragEvent) => {
      event.preventDefault();
      const creativeKind = event.dataTransfer.getData('application/creative-node');
      if (creativeMode && creativeKind) {
        const position = screenToFlowPosition({ x: event.clientX, y: event.clientY });
        const template = creativeInitialNodes.find((node) => node.type === creativeKind);
        if (!template) return;
        const id = `${creativeKind}-${Math.random().toString(36).slice(2, 7)}`;
        setCreativeNodes((prev) => [...prev, { ...template, id, position, data: { ...template.data } }]);
        return;
      }
      const pdoomKind = event.dataTransfer.getData('application/pdoom-node');
      if (pdoomMode && pdoomKind) {
        const position = screenToFlowPosition({ x: event.clientX, y: event.clientY });
        const template = pdoomInitialNodes.find((node) => node.type === pdoomKind);
        if (!template) return;
        const id = `${pdoomKind}-${Math.random().toString(36).slice(2, 7)}`;
        setPdoomNodes((prev) => [...prev, { ...template, id, position, data: { ...template.data, cache: 'cold' } }]);
        return;
      }
      const kind = event.dataTransfer.getData('application/videograph-node') as NodeKind | '';
      if (!kind) return;
      const position = screenToFlowPosition({ x: event.clientX, y: event.clientY });
      const id = `${kind}-${Math.random().toString(36).slice(2, 7)}`;
      setNodes((prev) => [...prev, { id, type: kind, position, data: nodeData(kind, modelRef.current), selected: false } as StudioNode]);
    },
    [creativeMode, pdoomMode, screenToFlowPosition, setCreativeNodes, setNodes, setPdoomNodes],
  );

  // 首次挂载播种节点；之后数据更新只按 id 刷新 data，位置保留给 React Flow 管理。
  useEffect(() => {
    if (seeded.current) return;
    seeded.current = true;
    setNodes(createNodes(modelRef.current));
  }, [setNodes]);

  useEffect(() => {
    setNodes((prev) => {
      if (prev.length === 0) return prev;
      const fresh = createNodes(modelRef.current);
      return prev.map((node) => {
        const next = fresh.find((f) => f.id === node.id);
        if (next) return { ...node, data: next.data };
        const kind = node.data.kind;
        return kind ? { ...node, data: nodeData(kind, modelRef.current) } : node;
      });
    });
  }, [model, setNodes]);

  const exportWorkflow = () => {
    const workflow = {
      version: '0.4',
      provider: providers.active ? { name: providers.active.name, model: providers.active.model, kind: providers.active.kind } : null,
      nodes: nodes.map(({ id, type, position, data }) => ({ id, type, position, data })),
      edges,
      memory: Object.fromEntries(memoryCounts.map(({ layer, count }) => [layer, count])),
    };
    const url = URL.createObjectURL(new Blob([JSON.stringify(workflow, null, 2)], { type: 'application/json' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = 'videograph-workflow.json';
    link.click();
    URL.revokeObjectURL(url);
  };

  const onConnect = useCallback(
    (connection: Connection) => setEdges((current) => addEdge({ ...connection, animated: true }, current)),
    [setEdges],
  );

  const runPdoomPipeline = useCallback(() => {
    const plan = [
      { id: 'pdoom-stems', type: 'stems' as const, label: 'Stem 分离', producer: 'Demucs / audio-separator', schema: 'stems/v1', summary: 'vocals · drums · bass · other' },
      { id: 'pdoom-lyrics', type: 'lyrics-aligned' as const, label: '逐词歌词对齐', producer: 'CTC + Whisper + refinement', schema: 'lyrics/v1', summary: 'word + syllable timestamps' },
      { id: 'pdoom-beats', type: 'audio-analysis' as const, label: '节拍与音频分析', producer: 'librosa + NumPy', schema: 'audio-analysis/v1', summary: '132 BPM · beats · downbeats · envelopes' },
      { id: 'pdoom-timeline', type: 'timeline' as const, label: '时间线', producer: 'beat-grid director', schema: 'timeline/v1', summary: 'lyric-anchored plate windows' },
      { id: 'pdoom-samples', type: 'sample-plan' as const, label: '采样计划', producer: 'adaptive temporal AA', schema: 'samples/v1', summary: '4 / 12 / 36 / 108 / 324 subframes' },
    ];
    plan.forEach((item, index) => {
      const key = `${item.id}:pdoom-runtime-v1:demo`;
      const hit = blackboard.artifacts.some((artifact) => artifact.cacheKey === key && artifact.state !== 'stale');
      blackboard.recordCache({ nodeId: item.id, nodeType: item.type, key, result: hit ? 'hit' : 'miss', tokensSaved: hit ? 850 : 0 });
      blackboard.publish({ type: item.type, label: item.label, producer: item.producer, schema: item.schema, contentHash: `demo-${index}-${item.type}`, cacheKey: key, state: hit ? 'hit' : 'miss', size: 'demo artifact', lineage: ['pdoom-audio'], summary: item.summary });
    });
  }, [blackboard]);

  const updatePdoomNodes = useCallback(() => {
    setPdoomNodes((current) => current.map((node) => {
      const artifact = blackboard.artifacts.find((item) => item.type === node.data.artifactType);
      if (!artifact) return node;
      return { ...node, data: { ...node.data, cache: artifact.state, summary: `${node.data.summary} · ${artifact.state === 'hit' ? '黑板命中' : '产物已写入黑板'}` } };
    }));
  }, [blackboard.artifacts, setPdoomNodes]);

  useEffect(() => {
    if (pdoomMode) updatePdoomNodes();
  }, [blackboard.artifacts, pdoomMode, updatePdoomNodes]);

  const creativeCanvas = (
    <ReactFlow
      nodes={[...creativeNodes, ...researchNodes] as any}
      edges={[...creativeEdges, { id: 'asset-to-research', source: 'asset-brief', target: 'lyric-research-1', animated: true, className: 'edge-yellow' }, { id: 'research-to-shot', source: 'lyric-research-1', target: 'shot-director-1', animated: true, className: 'edge-yellow' }, { id: 'assets-to-shot', source: 'asset-source', target: 'shot-director-1', animated: true, className: 'edge-orange' }]}
      nodeTypes={{ ...creativeNodeTypes, ...researchNodeTypes }}
      onNodesChange={(changes) => { onCreativeNodesChange(changes as Parameters<typeof onCreativeNodesChange>[0]); onResearchNodesChange(changes as Parameters<typeof onResearchNodesChange>[0]); }}
      onEdgesChange={onCreativeEdgesChange}
      onConnect={(connection) => setCreativeEdges((current) => addEdge({ ...connection, animated: true }, current))}
      onNodeClick={(_, node) => setSelectedId(node.id)}
      onPaneClick={() => setSelectedId('')}
      deleteKeyCode={['Delete', 'Backspace']}
      fitView
      fitViewOptions={{ padding: 0.16 }}
      minZoom={0.15}
      maxZoom={1.2}
      proOptions={{ hideAttribution: true }}
    >
      <Background variant={BackgroundVariant.Dots} gap={22} size={1} color="#2e2e2e" />
      <Controls showInteractive={false} />
      <MiniMap nodeColor={() => '#72d9bf'} maskColor="rgba(15, 15, 15, 0.78)" />
    </ReactFlow>
  );

  const pdoomCanvas = (
    <ReactFlow
      nodes={pdoomNodes}
      edges={pdoomEdges}
      nodeTypes={pdoomNodeTypes}
      onNodesChange={onPdoomNodesChange}
      onEdgesChange={onPdoomEdgesChange}
      onConnect={(connection) => setPdoomEdges((current) => addEdge({ ...connection, animated: true }, current))}
      onNodeClick={(_, node) => setSelectedId(node.id)}
      onPaneClick={() => setSelectedId('')}
      deleteKeyCode={['Delete', 'Backspace']}
      fitView
      fitViewOptions={{ padding: 0.18 }}
      minZoom={0.15}
      maxZoom={1.2}
      proOptions={{ hideAttribution: true }}
    >
      <Background variant={BackgroundVariant.Dots} gap={22} size={1} color="#2e2e2e" />
      <Controls showInteractive={false} />
      <MiniMap nodeColor={() => '#6ea8fe'} maskColor="rgba(15, 15, 15, 0.78)" />
    </ReactFlow>
  );

  const legacyCanvas = (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      nodeTypes={nodeTypes}
      onNodesChange={onNodesChange}
      onEdgesChange={onEdgesChange}
      onConnect={onConnect}
      onNodeClick={(_, node) => setSelectedId(node.id)}
      onPaneClick={() => setSelectedId('')}
      deleteKeyCode={['Delete', 'Backspace']}
      fitView
      fitViewOptions={{ padding: 0.18 }}
      minZoom={0.25}
      maxZoom={1.2}
      proOptions={{ hideAttribution: true }}
    >
      <Background variant={BackgroundVariant.Dots} gap={22} size={1} color="#2e2e2e" />
      <Controls showInteractive={false} />
      <MiniMap nodeColor={(node) => node.type === 'prompt' ? '#ffd500' : node.type === 'code' ? '#b39ddb' : node.type === 'render' ? '#64b5f6' : node.type === 'memory' ? '#3aa08a' : '#ffa931'} maskColor="rgba(15, 15, 15, 0.78)" />
    </ReactFlow>
  );

  const activeCanvas = shotMode ? <ShotWorkshop providers={providers} memory={memory} blackboard={blackboard} /> : creativeMode ? creativeCanvas : pdoomMode ? pdoomCanvas : legacyCanvas;

  const logItems = [
    { tone: 'muted', text: `服务：${providers.active ? `${providers.active.name}（${providers.active.model}）` : '本地模拟'}` },
    { tone: 'muted', text: `幕：${actName}${actActive ? ' · 简报已注入' : ' · 未连线'}` },
    { tone: 'muted', text: `修改方向：${directionActive ? '已就绪' : '未设置'}` },
    { tone: codeStatus === 'success' ? 'success' : codeStatus === 'error' ? 'bad' : 'muted', text: `${codeOutput ? `镜头代码 rev_${pad(codeOutput.revision)} · ${locked ? '已锁定' : '未锁定'}` : '等待场景提示词'}` },
    { tone: renderStatus === 'success' ? 'success' : 'muted', text: renderOutput ? `预览完成 · ${renderOutput.frames} 帧 / ${renderOutput.seconds.toFixed(1)}s` : '未提交渲染' },
    ...(lastError ? [{ tone: 'bad' as const, text: lastError.slice(0, 90) }] : []),
  ];

  return (
    <main className="app-shell">
      <header className="topbar">
        <div className="brand-lockup"><div className="brand-mark"><Layers3 size={17} /></div><div><strong>VideoGraph</strong><span>{shotMode ? '单镜头工坊' : creativeMode ? '创意导演工作区' : pdoomMode ? 'P(DOOM) 教学模板' : '镜头节点工作区'}</span></div></div>
        <a className="toolbar-button" href="?view=project" style={{ textDecoration: 'none' }}>工程工作台</a>
        <button className={`llm-chip ${shotMode ? 'active' : ''}`} onClick={() => { setShotMode(true); setCreativeMode(false); setPdoomMode(false); }}><WandSparkles size={13} /> 单镜头工坊</button>
        <button className={`llm-chip ${creativeMode ? 'active' : ''}`} onClick={() => { setCreativeMode(true); setPdoomMode(false); setShotMode(false); }}><BriefcaseBusiness size={13} /> 创意工作区</button>
        <button className={`llm-chip ${pdoomMode ? 'active' : ''}`} onClick={() => { setCreativeMode(false); setPdoomMode(true); setShotMode(false); }}><Layers3 size={13} /> P(DOOM) 教学</button>
        <button className={`llm-chip ${!creativeMode && !pdoomMode ? 'active' : ''}`} onClick={() => { setCreativeMode(false); setPdoomMode(false); }}><Camera size={13} /> 镜头 Demo</button>
        <button className={`llm-chip ${providers.active ? '' : 'none'}`} onClick={() => setSettingsOpen(true)}>
          <Plug size={13} /> {providers.active ? `${providers.active.name} · ${providers.active.model}` : '配置 LLM 服务'}
        </button>
        <div className="top-actions">
          <button className="toolbar-button" onClick={reset}><RotateCcw size={14} /> 重置</button>
          <button className="toolbar-button" onClick={exportWorkflow}><Download size={14} /> 导出 JSON</button>
          <button className="run-button" onClick={generateCode} disabled={locked || pdoomMode || shotMode}><Zap size={14} /> 运行工作流</button>
        </div>
      </header>

      <section className="workspace">
        <aside className="sidebar left-sidebar">
          <div className="sidebar-title"><span>{shotMode ? '工坊说明' : creativeMode ? '创意节点库' : pdoomMode ? 'P(DOOM) 节点库' : '节点库'}</span><span className="group-label">{shotMode ? '1 个镜头' : creativeMode ? '6 种模块' : pdoomMode ? '11 种算子' : '6 种节点'}</span></div>
          <div className="search-box"><span>⌕</span><input placeholder="搜索节点…" /></div>
          {shotMode ? <>
            <div className="library-hint">「AI 规划 → 人改提示词 → AI 写代码 → 分段渲染」的完整闭环。未配 LLM 时自动走 MCP 队列：请求写入 .queue/，由 ZCode agent 经 shot_queue_* 工具生成提交，无需 API key；也可用内置参考规划（复刻 pdoom 真实剪辑）或本地模板即时生成。</div>
            <div className="library-group"><span className="group-label">真实数据</span><div className="library-item" style={{ cursor: 'default' }}><span className="library-icon icon-yellow"><Activity size={14} /></span><span>歌词 × 节拍窗口</span></div><div className="library-item" style={{ cursor: 'default' }}><span className="library-icon icon-mint"><Palette size={14} /></span><span>风格圣经（mini）</span></div></div>
            <div className="library-group"><span className="group-label">产物</span><div className="library-item" style={{ cursor: 'default' }}><span className="library-icon icon-blue"><Film size={14} /></span><span>场景代码 / 静帧 / 片段</span></div></div>
          </> : creativeMode ? <>
            <div className="library-hint">先输入歌曲/品牌目标，LLM 会提出创意、素材需求和镜头工作流。素材可由创作者提供，也可交给扩散模型生成。</div>
            <div className="library-group"><span className="group-label">规划</span>{[['creative-brief','创意导演'],['asset-brief','素材需求单'],['asset-source','素材来源决策']].map(([kind, label]) => <button className="library-item" draggable key={kind} onDragStart={(event) => { event.dataTransfer.setData('application/creative-node', kind); event.dataTransfer.effectAllowed = 'copy'; }}><span className="library-icon icon-mint"><BriefcaseBusiness size={14} /></span><span>{label}</span><Plus size={13} /></button>)}</div>
            <div className="library-group"><span className="group-label">镜头工作流</span>{[['shot-planner','镜头导演'],['shot-review','镜头审阅与微调'],['delivery-plan','交付合成']].map(([kind, label]) => <button className="library-item" draggable key={kind} onDragStart={(event) => { event.dataTransfer.setData('application/creative-node', kind); event.dataTransfer.effectAllowed = 'copy'; }}><span className="library-icon icon-blue"><Camera size={14} /></span><span>{label}</span><Plus size={13} /></button>)}</div>
          </> : pdoomMode ? <>
            <div className="library-hint">按音频分析 → 视觉 Plate → 时间线 → 合成的依赖顺序搭建，产物会进入黑板。</div>
            <div className="library-group"><span className="group-label">音频与分析</span>{[['audio-source','音频源'],['stem-analysis','Stem 分离'],['lyrics-align','逐词歌词对齐'],['beat-analysis','节拍与音频分析']].map(([kind, label]) => <button className="library-item" draggable key={kind} onDragStart={(event) => { event.dataTransfer.setData('application/pdoom-node', kind); event.dataTransfer.effectAllowed = 'copy'; }}><span className="library-icon icon-mint"><Activity size={14} /></span><span>{label}</span><Plus size={13} /></button>)}</div>
            <div className="library-group"><span className="group-label">视觉与镜头</span>{[['style-bible','风格圣经'],['shader-pass','Shader Pass'],['plate-scene','Plate 镜头']].map(([kind, label]) => <button className="library-item" draggable key={kind} onDragStart={(event) => { event.dataTransfer.setData('application/pdoom-node', kind); event.dataTransfer.effectAllowed = 'copy'; }}><span className="library-icon icon-violet"><Braces size={14} /></span><span>{label}</span><Plus size={13} /></button>)}</div>
            <div className="library-group"><span className="group-label">编排与输出</span>{[['timeline-director','时间线导演'],['sample-plan','自适应采样计划'],['composite','片段合成'],['blackboard','黑板 / Blackboard']].map(([kind, label]) => <button className="library-item" draggable key={kind} onDragStart={(event) => { event.dataTransfer.setData('application/pdoom-node', kind); event.dataTransfer.effectAllowed = 'copy'; }}><span className="library-icon icon-orange"><Film size={14} /></span><span>{label}</span><Plus size={13} /></button>)}</div>
          </> : <>
            <div className="library-hint">把节点拖到画布中即可添加；选中后按 Delete 删除。</div>
            <div className="library-group"><span className="group-label">输入</span><button className="library-item" draggable onDragStart={(event) => { event.dataTransfer.setData('application/videograph-node', 'prompt'); event.dataTransfer.effectAllowed = 'copy'; }}><span className="library-icon icon-mint"><Sparkles size={14} /></span><span>场景提示词</span><Plus size={13} /></button><button className="library-item" draggable onDragStart={(event) => { event.dataTransfer.setData('application/videograph-node', 'steer'); event.dataTransfer.effectAllowed = 'copy'; }}><span className="library-icon icon-violet"><GitBranch size={14} /></span><span>修改方向补丁</span><Plus size={13} /></button></div>
            <div className="library-group"><span className="group-label">AI 算子</span><button className="library-item" draggable onDragStart={(event) => { event.dataTransfer.setData('application/videograph-node', 'code'); event.dataTransfer.effectAllowed = 'copy'; }}><span className="library-icon icon-blue"><Zap size={14} /></span><span>镜头编译器</span><Plus size={13} /></button></div>
          </>}
          <div className="sidebar-help"><Sparkles size={14} /><div><strong>{shotMode ? '单镜头闭环' : creativeMode ? '创意导演工作流' : pdoomMode ? '第一性原理' : '镜头 Demo'}</strong><span>{shotMode ? '改提示词 → 生成代码 → 渲染静帧 → 播放/导出；黑板记录每次产物与缓存。' : creativeMode ? 'LLM 先规划，再向创作者索要素材；创作者可逐镜头审阅、微调和替换素材来源。' : pdoomMode ? '每个节点只负责一个可验证的中间产物。黑板负责血缘、缓存和复用。' : '镜头、提示词与渲染节点组成可编辑工作流。'}</span></div></div>
        </aside>

        <section className="canvas-wrap">
          <div className="canvas-toolbar">
            <div className="canvas-title"><span className="tiny-kicker">{shotMode ? '单镜头工坊 / 01' : creativeMode ? '创意工作区 / 01' : pdoomMode ? 'P(DOOM) 教学 / 01' : '工作流 / 01'}</span><strong>{shotMode ? '数据 → 镜头卡片 → 场景代码 → 渲染' : creativeMode ? '歌词理解 → 素材 → 逐镜头生成 → 交付' : pdoomMode ? '音频 → Plate → 时间线 → 合成 → 视频' : '镜头 → 幕 → 工作区'}</strong></div>
          <div className="canvas-meta"><span><GitBranch size={13} /> {shotMode ? nodes.length : creativeMode ? creativeNodes.length + researchNodes.length : pdoomMode ? pdoomNodes.length : nodes.length} 个节点</span><span><Zap size={13} /> {shotMode ? 2 : creativeMode ? creativeEdges.length + 3 : pdoomMode ? pdoomEdges.length : edges.length} 条连线</span></div>
          </div>
          <div
            className="flow-canvas"
            onDragOver={(event) => { event.preventDefault(); event.dataTransfer.dropEffect = 'copy'; }}
            onDrop={onDrop}
          >
            {activeCanvas}
          </div>
          <div className="canvas-foot"><span className="demo-badge">{shotMode ? '单镜头工坊 · 真实词级数据 + 确定性渲染' : creativeMode ? '创意导演模式 · 等待素材确认' : pdoomMode ? 'P(DOOM) 教学模式 · 黑板已启用' : '镜头 Demo · 已接入 LLM'}</span>{pdoomMode && <button className="run-button pdoom-run-toolbar" onClick={runPdoomPipeline}><Zap size={12} /> 运行分析链（演示）</button>}</div>
        </section>

        <aside className="sidebar right-sidebar">
          <div className="sidebar-title"><span>检查器</span><Settings2 size={15} /></div>
          <div className="inspector-node">
            <div className="inspector-node-icon"><Layers3 size={16} /></div>
            <div>
              <span className="tiny-kicker">选中节点</span>
              <strong>{nodeNames[selectedId] ?? '未选中节点'}</strong>
            </div>
          </div>
          <div className="inspector-section">
            <span className="group-label">执行日志</span>
            <div className="log-list">
              {logItems.map((item) => <div className={`log-line ${item.tone}`} key={item.text}><span className="log-dot" />{item.text}</div>)}
            </div>
          </div>
          <MemoryPanel entries={memory.entries} onClearLayer={memory.clearLayer} />
          {(pdoomMode || shotMode) && <BlackboardPanel artifacts={blackboard.artifacts} events={blackboard.recentEvents} stats={blackboard.stats} policy={blackboard.policy} onPolicy={blackboard.setCachePolicy} onInvalidate={() => blackboard.invalidate()} />}
          <div className="inspector-section inspector-note"><CircleDashed size={14} /><p>层级：「修改方向补丁」与「场景提示词」共同驱动镜头编译器；镜头汇入幕导演；幕汇入工作区记忆。渲染仍为本地占位。</p></div>
        </aside>
      </section>

      <footer className="statusbar">
        <div><span className="statusbar-live" /> {providers.active ? 'LLM 已连接' : '本地引擎就绪'}</div>
        <div className="statusbar-center">{shotMode ? '单镜头工坊 · 卡片上的操作即渲染管线' : codeOutput ? `版本 ${pad(codeOutput.revision)} · ${locked ? '已锁定' : '未锁定'}` : '等待场景提示词'} {!shotMode && <span>•</span>} {!shotMode && (renderOutput ? '预览可用' : '无渲染任务')}</div>
        <div>v0.4.0 · 演示版</div>
      </footer>

      {settingsOpen && <SettingsModal providers={providers} onClose={() => setSettingsOpen(false)} />}
    </main>
  );
}

export default function App() {
  const projectMode = new URLSearchParams(location.search).get('view') === 'project';
  return <ReactFlowProvider>{projectMode ? <Suspense fallback={<div>正在载入工程工作台…</div>}><ProjectStudio /></Suspense> : <Studio />}</ReactFlowProvider>;
}

const rootEl = document.getElementById('root');
if (!rootEl) throw new Error('#root element missing in index.html');
createRoot(rootEl).render(<App />);
