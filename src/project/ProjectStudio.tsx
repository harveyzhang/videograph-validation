// ProjectStudio.tsx — 真工程的节点界面；工程/版本/作业状态均来自本地服务。
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Background, Controls, Handle, MiniMap, Panel, Position, ReactFlow, useNodesState, type Edge, type Node, type NodeProps, type ReactFlowInstance } from '@xyflow/react';
import { AudioLines, Clapperboard, FileCode2, FolderOpen, Upload, Play, Download, Lock, Unlock, Layers3, X, RefreshCw } from 'lucide-react';
import { importBgm, projectApi, projectFile, serviceUrl, type FeedbackAnchor, type VideoProject, type ProjectShot, type ProjectTransition, type ProjectJob, type ProjectSummary } from './api';
import { LyricInspector } from './LyricInspector';
import { TransitionInspector, transitionLabels } from './TransitionInspector';
import { FeedbackComposer } from './FeedbackComposer';
import { ReviewCompare } from './ReviewCompare';
import './project.css';

type ShotNode = Node<{ shot: ProjectShot; projectId: string; index: number } & Record<string, unknown>, 'project-shot'>;
type TransitionNode = Node<{ transition: ProjectTransition; fromTitle: string; toTitle: string } & Record<string, unknown>, 'project-transition'>;
type ContextNode = Node<{ title: string; detail: string; kind: string } & Record<string, unknown>, 'project-context'>;
type FeedbackNode = Node<{ shot: ProjectShot; projectId: string; busy: boolean; hasPreviewTime: boolean; getPreviewTime: () => number | null; onAdd: (input: { text: string; anchor?: FeedbackAnchor; preserve?: string[] }, revision: number) => Promise<boolean>; onProject: (project: VideoProject) => void } & Record<string, unknown>, 'project-feedback'>;
const sourceLabel = (source: string) => source === 'mcp-authored' ? 'MCP 编写源码' : source === 'human-authored' ? '人工编辑源码' : '导入原工程源码';
function FeedbackNodeView({ data }: NodeProps<FeedbackNode>) {
  return <div className="studio-node project-feedback-node">
    <div className="node-header"><FileCode2 size={14} /><strong>修改意见 → {data.shot.title}</strong></div>
    <div className="node-body">
      <FeedbackComposer shot={data.shot} projectId={data.projectId} busy={data.busy} hasPreviewTime={data.hasPreviewTime} getPreviewTime={data.getPreviewTime} onAdd={data.onAdd} onProject={data.onProject} />
    </div><Handle type="source" position={Position.Left} />
  </div>;
}
const statusLabel: Record<string, string> = { imported: '参考导入 · 待验证', ready: '已验证', 'needs-generation': '待 AI 改写', 'needs-validation': '待验证' };
const jobLabel: Record<string, string> = { queued: '排队', running: '运行中', done: '完成', error: '失败', interrupted: '已中断', cancelled: '已取消' };

function ShotNodeView({ data, selected }: NodeProps<ShotNode>) {
  const shot = data.shot;
  return <div className={`studio-node project-shot-node ${selected ? 'is-selected' : ''}`} title={`${shot.title} · ${shot.start.toFixed(3)}–${shot.end.toFixed(3)}s · 输入 v${shot.inputRevision}`}>
    <div className="node-header"><Clapperboard size={14} /><div className="node-heading"><span className="node-eyebrow">镜头 {String(data.index + 1).padStart(2, '0')} · {shot.id}</span><strong>{shot.title}</strong></div>{shot.locked && <Lock size={13} />}</div>
    <div className="node-body">
      {shot.validation ? <img src={projectFile(data.projectId, `artifacts/${shot.validation.thumb}`)} alt={`${shot.title} 已验证静帧`} /> : <div className="project-thumb-empty"><Clapperboard size={25} /><span>真实场景 · 等待渲染</span></div>}
      <div className="project-shot-status">{shot.status === 'ready' ? '✓ ' : '○ '}{statusLabel[shot.status] ?? shot.status}</div>
      <div className="project-shot-time">{shot.start.toFixed(2)}–{shot.end.toFixed(2)}s · v{shot.inputRevision}</div>
    </div>
    <div className="node-footer"><span>{sourceLabel(shot.source)}</span><span>SCENE</span></div>
    <Handle type="target" position={Position.Left} id="input" /><Handle type="target" position={Position.Right} id="feedback" style={{ top: '25%' }} /><Handle type="source" position={Position.Right} id="output" style={{ top: '75%' }} />
  </div>;
}
function ContextNodeView({ data }: NodeProps<ContextNode>) {
  return <div className="studio-node project-context-node"><div className="node-header">{data.kind === 'audio' ? <AudioLines size={16} /> : <Layers3 size={16} />}<strong>{data.title}</strong></div><div className="node-body">{data.detail}</div>
    {data.kind !== 'audio' && <Handle type="target" position={Position.Left} />}{data.kind !== 'output' && <Handle type="source" position={Position.Right} />}</div>;
}
function TransitionNodeView({ data, selected }: NodeProps<TransitionNode>) {
  const tr = data.transition;
  return <div className={`studio-node project-transition-node ${selected ? 'is-selected' : ''}`}>
    <div className="node-header"><Layers3 size={14} /><strong>转场 / {transitionLabels[tr.mode]}</strong>{tr.locked && <Lock size={12} />}</div>
    <div className="node-body"><small>{data.fromTitle} → {data.toTitle}</small><p>{tr.intent}</p><span>{tr.mode === 'cut' ? '节拍硬切' : `${tr.duration.toFixed(2)}s`} · v{tr.inputRevision}{tr.feedback?.length ? ` · ${tr.feedback.length} 条意见` : ''}</span></div>
    <Handle type="target" position={Position.Left} id="from" style={{ top: '30%' }} /><Handle type="target" position={Position.Left} id="to" style={{ top: '70%' }} /><Handle type="source" position={Position.Right} />
  </div>;
}
const nodeTypes = { 'project-shot': ShotNodeView, 'project-context': ContextNodeView, 'project-feedback': FeedbackNodeView, 'project-transition': TransitionNodeView };
const message = (error: unknown) => error instanceof Error ? error.message : String(error);

export default function ProjectStudio() {
  const [projects, setProjects] = useState<ProjectSummary[]>([]);
  const [project, setProject] = useState<VideoProject | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedTransitionId, setSelectedTransitionId] = useState<string | null>(null);
  const [jobs, setJobs] = useState<ProjectJob[]>([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [preview, setPreview] = useState<string | null>(null);
  const [previewKind, setPreviewKind] = useState('当前版本');
  const [compare, setCompare] = useState(false);
  // FB-02：预览播放器每 250ms postMessage 当前时间；只接受预览 origin + iframe source 匹配的消息。
  const previewFrameRef = useRef<HTMLIFrameElement | null>(null);
  const previewTimeRef = useRef<number | null>(null);
  const [hasPreviewTime, setHasPreviewTime] = useState(false);
  const previewOrigin = useMemo(() => { try { return preview ? new URL(preview).origin : null; } catch { return null; } }, [preview]);
  useEffect(() => { setHasPreviewTime(false); previewTimeRef.current = null; }, [preview]);
  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      if (!previewOrigin || event.origin !== previewOrigin || event.source !== previewFrameRef.current?.contentWindow) return;
      const data = event.data as { type?: string; t?: number } | null;
      if (data?.type === 'videograph:time' && typeof data.t === 'number' && Number.isFinite(data.t)) { previewTimeRef.current = data.t; setHasPreviewTime(true); }
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [previewOrigin]);
  const [form, setForm] = useState({ id: '', revision: 0, prompt: '', params: '{}' });
  const [source, setSource] = useState<{ projectId: string; shotId: string; revision: number; code: string; feedbackIds: string[]; feedback: NonNullable<ProjectShot['feedback']> } | null>(null);
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([]);
  const flow = useRef<ReactFlowInstance | null>(null);
  const fileInput = useRef<HTMLInputElement | null>(null);
  const loadEpoch = useRef(0);
  const selectedTransition = project?.transitions?.find((transition) => transition.id === selectedTransitionId) ?? null;
  const selected = selectedTransition ? null : project?.shots.find((shot) => shot.id === selectedId) ?? null;
  const selectionRef = useRef('');
  const transitionInputs = selectedTransition ? project?.shots.filter((shot) => shot.id === selectedTransition.fromShotId || shot.id === selectedTransition.toShotId).map((shot) => shot.inputToken).join(':') : '';
  const selectionKey = `${project?.id ?? ''}:${selected?.id ?? selectedTransition?.id ?? ''}:${selected?.inputToken ?? selectedTransition?.inputToken ?? ''}:${transitionInputs}`;
  selectionRef.current = selectionKey;
  useEffect(() => { setPreview(null); setCompare(false); }, [selectionKey]);
  const activeJobs = jobs.filter((job) => job.status === 'queued' || job.status === 'running');
  const completedVideo = jobs.find((job) => job.kind === 'export' && job.status === 'done' && job.result?.file);
  const staleForm = selected && form.id === selected.id && form.revision !== selected.inputRevision;
  const unaccepted = project && [...project.shots, ...(project.transitions ?? [])].some((target) => target.feedback?.some((note) => note.status !== 'accepted'));
  const needsGeneration = project && [...project.shots, ...(project.transitions ?? [])].some((target) => target.status === 'needs-generation');
  const awaitingReview = selected?.feedback?.filter((note) => note.status === 'responded') ?? [];

  const refreshList = useCallback(async () => {
    const data = await projectApi<{ projects: ProjectSummary[] }>('/projects'); setProjects(data.projects); return data.projects;
  }, []);
  const load = useCallback(async (id: string) => {
    const epoch = ++loadEpoch.current;
    const data = await projectApi<VideoProject>(`/projects/${id}`);
    if (epoch !== loadEpoch.current) return;
    setProject(data); setSelectedId(data.shots[0]?.id ?? null); setSelectedTransitionId(null); setPreview(null); setSource(null); setJobs([]);
    history.replaceState(null, '', `?view=project&project=${encodeURIComponent(id)}`);
  }, []);
  useEffect(() => {
    void refreshList().then((list) => {
      const id = new URLSearchParams(location.search).get('project');
      if (id && list.some((entry) => entry.id === id)) return load(id);
      if (list[0]) return load(list[0].id);
    }).catch((err) => setError(message(err)));
  }, [load, refreshList]);

  useEffect(() => {
    if (!project) return;
    let stopped = false, polling = false;
    const id = project.id;
    const tick = async () => {
      if (polling) return; polling = true;
      try {
        const [current, jobData] = await Promise.all([projectApi<VideoProject>(`/projects/${id}`), projectApi<{ jobs: ProjectJob[] }>(`/projects/${id}/jobs`)]);
        if (!stopped) { setProject((previous) => previous?.id === id && previous.revision <= current.revision ? current : previous); setJobs(jobData.jobs); }
      } catch (err) { if (!stopped) setError(message(err)); }
      finally { polling = false; }
    };
    void tick(); const timer = window.setInterval(() => void tick(), 2500);
    return () => { stopped = true; window.clearInterval(timer); };
  }, [project?.id]);

  const resetForm = useCallback((shot: ProjectShot) => setForm({ id: shot.id, revision: shot.inputRevision, prompt: shot.prompt, params: JSON.stringify(shot.params, null, 2) }), []);
  useEffect(() => { if (selected) resetForm(selected); }, [project?.id, selected?.id, resetForm]);

  useEffect(() => {
    if (!project) { setNodes([]); return; }
    const contexts: ContextNode[] = [
      { id: 'bgm', type: 'project-context', position: { x: 0, y: 120 }, data: { title: 'BGM / 输入', detail: project.audio.name, kind: 'audio' } },
      { id: 'analysis', type: 'project-context', position: { x: 280, y: 120 }, data: { title: '词级 / 节拍 / 段落', detail: '音频指纹命中已对齐数据；非重新识别', kind: 'analysis' } },
      { id: 'output', type: 'project-context', position: { x: 2900, y: 760 }, data: { title: '全片 / MP4', detail: '冻结工程 → 分段缓存 → 全曲 BGM 封装', kind: 'output' } },
    ];
    const shots: ShotNode[] = project.shots.map((shot, index) => ({ id: `shot-${shot.id}`, type: 'project-shot', selected: shot.id === selectedId,
      position: { x: 610 + (index % 4) * 560, y: Math.floor(index / 4) * 520 }, data: { shot, index, projectId: project.id } }));
    const feedback: FeedbackNode[] = project.shots.flatMap((shot, index) => shot.id === selectedId || shot.feedback?.length ? [{
      id: `feedback-${shot.id}`, type: 'project-feedback' as const, position: { x: 885 + (index % 4) * 560, y: Math.floor(index / 4) * 520 },
      data: { shot, projectId: project.id, busy, hasPreviewTime, getPreviewTime: () => previewTimeRef.current,
        onAdd: async (input: { text: string; anchor?: FeedbackAnchor; preserve?: string[] }, revision: number) => {
          let ok = false;
          await act(async () => {
            const next = await projectApi<VideoProject>(`/projects/${project.id}/shots/${shot.id}/feedback`, { expectedInputRevision: revision, ...input });
            setProject(next); if (selectedId === shot.id) resetForm(next.shots.find((entry) => entry.id === shot.id)!); setPreview(null); ok = true;
          });
          return ok;
        },
        onProject: setProject },
    }] : []);
    const transitions: TransitionNode[] = (project.transitions ?? []).map((transition, index) => ({
      id: `transition-${transition.id}`, type: 'project-transition', selected: transition.id === selectedTransitionId,
      position: { x: 610 + (index % 4) * 560, y: Math.floor(index / 4) * 520 + 320 },
      data: { transition, fromTitle: project.shots.find((shot) => shot.id === transition.fromShotId)?.title ?? transition.fromShotId,
        toTitle: project.shots.find((shot) => shot.id === transition.toShotId)?.title ?? transition.toShotId },
    }));
    setNodes((previous) => {
      const existing = new Map(previous.map((node) => [node.id, node]));
      return [...contexts, ...shots, ...feedback, ...transitions].map((node) => ({ ...existing.get(node.id), ...node, position: existing.get(node.id)?.position ?? node.position }));
    });
  }, [project, selectedId, selectedTransitionId, setNodes, busy, resetForm, hasPreviewTime]);
  const edges: Edge[] = useMemo(() => !project ? [] : [
    { id: 'bgm-analysis', source: 'bgm', target: 'analysis' },
    ...project.shots.flatMap((shot) => [
      { id: `in-${shot.id}`, source: 'analysis', target: `shot-${shot.id}`, targetHandle: 'input' },
      { id: `out-${shot.id}`, source: `shot-${shot.id}`, sourceHandle: 'output', target: 'output' },
      ...(shot.id === selectedId || shot.feedback?.length ? [{ id: `feedback-edge-${shot.id}`, source: `feedback-${shot.id}`, target: `shot-${shot.id}`, targetHandle: 'feedback', label: '修改意见' }] : []),
    ]),
    ...(project.transitions ?? []).flatMap((transition) => [
      { id: `tr-from-${transition.id}`, source: `shot-${transition.fromShotId}`, sourceHandle: 'output', target: `transition-${transition.id}`, targetHandle: 'from' },
      { id: `tr-to-${transition.id}`, source: `shot-${transition.toShotId}`, sourceHandle: 'output', target: `transition-${transition.id}`, targetHandle: 'to' },
      { id: `tr-out-${transition.id}`, source: `transition-${transition.id}`, target: 'output' },
    ]),
  ], [project, selectedId]);

  const act = async (action: () => Promise<void>) => {
    setBusy(true); setError('');
    try { await action(); return true; } catch (err) { setError(message(err)); return false; }
    finally { setBusy(false); }
  };
  const selectShot = (id: string, focus = false) => {
    if (busy) return;
    setSelectedId(id); setSelectedTransitionId(null); setPreview(null);
    if (focus) void flow.current?.fitView({ nodes: [{ id: `shot-${id}` }], maxZoom: 1, padding: 0.4, duration: 220 });
  };
  const selectTransition = (id: string, focus = false) => {
    if (busy) return;
    setSelectedId(null); setSelectedTransitionId(id); setPreview(null);
    if (focus) void flow.current?.fitView({ nodes: [{ id: `transition-${id}` }], maxZoom: 1, padding: .5, duration: 220 });
  };
  const update = (patch: Record<string, unknown>) => act(async () => {
    if (!project || !selected) return;
    const next = await projectApi<VideoProject>(`/projects/${project.id}/shots/${selected.id}`, { expectedInputRevision: form.revision, patch });
    setProject(next); resetForm(next.shots.find((shot) => shot.id === selected.id)!); setPreview(null);
  });

  return <div className="app-shell project-shell">
    <header className="topbar"><div className="brand-lockup"><Layers3 size={19} /><strong>VideoGraph</strong><span>真实工程工作台</span></div>
      <span className="project-title">{project?.name ?? '从一首 BGM 开始'}</span>
      <div className="top-actions">
        <button className="run-button" title={unaccepted ? '先校验候选并接受人工修改意见，再导出正式版本' : '导出冻结版本'} disabled={!project || busy || unaccepted || needsGeneration || activeJobs.some((job) => job.kind === 'export')} onClick={() => void act(async () => {
          const job = await projectApi<ProjectJob>(`/projects/${project!.id}/render`, { fps: project!.output.fps, samples: project!.output.samples }); setJobs((previous) => [job, ...previous]);
        })}><Download size={14} />导出完整 PV</button></div>
    </header>
    <div className="project-workspace">
      <aside className="sidebar project-library"><div className="sidebar-title">工程</div>
        <input ref={fileInput} type="file" accept="audio/*" hidden onChange={(event) => {
          const file = event.target.files?.[0]; if (!file) return;
          void act(async () => { const created = await importBgm(file); await refreshList(); await load(created.id); }); event.target.value = '';
        }} />
        <button className="action-button" disabled={busy} onClick={() => fileInput.current?.click()}><Upload size={14} />只导入 BGM</button>
        <p className="project-note">当前复现配方：P(doom) 原始 BGM。按文件内容匹配分析与引擎，不拿旧歌词套用其他歌曲。</p>
        <div className="project-list">{projects.map((entry) => <button key={entry.id} disabled={busy} className={`library-item ${entry.id === project?.id ? 'active' : ''}`} onClick={() => void act(() => load(entry.id))}><FolderOpen size={14} /><span>{entry.name}</span></button>)}</div>
        {project && <><div className="sidebar-title">镜头导航 / {project.shots.length}</div><div className="project-shot-list">{project.shots.map((shot, index) => <button key={shot.id} className={selectedId === shot.id ? 'active' : ''} onClick={() => selectShot(shot.id, true)} title={shot.prompt}><span>{String(index + 1).padStart(2, '0')}</span><strong>{shot.title}</strong>{shot.locked ? <Lock size={12} /> : <small>{shot.status === 'ready' ? '✓' : '○'}</small>}</button>)}</div></>}
        {project && <details className="project-transition-nav"><summary>转场导航 / {(project.transitions ?? []).length}</summary><div className="project-shot-list">{(project.transitions ?? []).map((transition, index) => <button key={transition.id} disabled={busy} className={selectedTransitionId === transition.id ? 'active' : ''} onClick={() => selectTransition(transition.id, true)}><span>{index + 1} → {index + 2}</span><strong>{transitionLabels[transition.mode]}</strong><small>{transition.locked ? '锁定' : transition.status === 'ready' ? '✓' : '○'}</small></button>)}</div></details>}
      </aside>
      <main className="project-canvas-area"><div className="canvas-toolbar"><strong>工程依赖图</strong><span>实线：输入依赖 · 卡片编号：剪辑顺序</span></div>
        {error && <div className="project-error" role="alert">{error}<button aria-label="关闭错误" onClick={() => setError('')}><X size={14} /></button></div>}
        {!project ? <div className="project-empty"><AudioLines size={40} /><h2>把 BGM 变成可以操作的工程</h2><p>源码、字体、素材、时间线和渲染版本一起保存。关闭页面后，后台任务仍然继续。</p><button className="action-button" onClick={() => void act(async () => { await refreshList(); })}><RefreshCw size={14} />重新连接工程服务</button><code>npm run service</code></div>
          : <ReactFlow key={project.id} nodes={nodes} edges={edges} nodeTypes={nodeTypes} onNodesChange={onNodesChange} onInit={(instance) => { flow.current = instance; }}
            onNodeClick={(_, node) => { if (node.id.startsWith('shot-')) selectShot(node.id.slice(5)); else if (node.type === 'project-transition') selectTransition(node.id.slice('transition-'.length)); }} fitView minZoom={0.18} maxZoom={1.4} fitViewOptions={{ padding: 0.12 }} deleteKeyCode={null} nodesConnectable={false} proOptions={{ hideAttribution: true }}>
            <Background gap={24} size={1} /><Controls showInteractive={false} /><MiniMap />
            {preview && <Panel position="bottom-center" className="project-preview"><div><strong>{selected?.title ?? (selectedTransition ? `${selectedTransition.fromShotId} → ${selectedTransition.toShotId}` : '')} · {previewKind} · 真实引擎</strong><button aria-label="关闭引擎预览" onClick={() => setPreview(null)}><X size={15} /></button></div><iframe ref={previewFrameRef} title="真实镜头播放器" src={preview} allow="autoplay" /></Panel>}
          </ReactFlow>}
      </main>
      <aside className="sidebar project-inspector">{selectedTransition && project ? <TransitionInspector key={`${project.id}:${selectedTransition.id}`} project={project} transition={selectedTransition} busy={busy} onProject={setProject} onAction={act} onJob={(job) => setJobs((previous) => [job, ...previous.filter((entry) => entry.id !== job.id)])} onPreview={(url, label) => {
        if (selectionRef.current !== selectionKey) return false;
        setPreview(url); setPreviewKind(label); return true;
      }} /> : selected && project ? <>
        <div className="sidebar-title">{selected.title}<span>输入 v{selected.inputRevision}</span></div>
        <p className="project-note">{selected.start.toFixed(3)}–{selected.end.toFixed(3)}s · {statusLabel[selected.status] ?? selected.status}</p>
        <div className="project-inspector-actions"><button className="mini-button" disabled={busy || selected.status === 'needs-generation'} onClick={() => void act(async () => {
          const data = await projectApi<{ url: string; range?: { start: number; end: number } }>(`/projects/${project.id}/preview`, { shotId: selected.id });
          if (selectionRef.current !== selectionKey) return;
          const start = data.range?.start ?? selected.start, end = data.range?.end ?? selected.end;
          setPreview(`${data.url}/?only=${encodeURIComponent(selected.id)}&t=${start}&rangeStart=${start}&rangeEnd=${end}`); setPreviewKind('当前候选');
        })}><Play size={13} />预览此镜头</button>
          <button className="mini-button" disabled={busy || selected.status === 'needs-generation'} onClick={() => void act(async () => { const job = await projectApi<ProjectJob>(`/projects/${project.id}/validate`, { shotId: selected.id }); setJobs((previous) => [job, ...previous]); })}>5 帧校验</button>
          <button className="mini-button" disabled={busy} onClick={() => void update({ locked: !selected.locked })}>{selected.locked ? <Unlock size={13} /> : <Lock size={13} />}{selected.locked ? '解锁' : '锁定'}</button>
        </div>
        {selected.reviewBaseline && <button className="mini-button" disabled={busy} onClick={() => void act(async () => {
          const data = await projectApi<{ url: string; range?: { start: number; end: number } }>(`/projects/${project.id}/preview`, { shotId: selected.id, version: 'before-feedback' });
          if (selectionRef.current !== selectionKey) return;
          const start = data.range?.start ?? selected.start, end = data.range?.end ?? selected.end;
          setPreview(`${data.url}/?only=${encodeURIComponent(selected.id)}&t=${start}&rangeStart=${start}&rangeEnd=${end}`); setPreviewKind('修改前版本');
        })}>预览修改前版本</button>}
        {awaitingReview.length > 0 && <div className="project-review-box"><strong>AI 已响应 {awaitingReview.length} 条意见，等待你确认</strong>
          <p>技术验证不代表符合你的创作要求。在并排对比中检查同一时间点的修改前与当前候选，再选择采用。</p>
          <button className="action-button" disabled={busy || selected.status !== 'ready'} onClick={() => setCompare(true)}>并排对比，采用或拒绝</button>
          <button className="mini-button" disabled={busy || selected.locked} onClick={() => void act(async () => {
            const next = await projectApi<VideoProject>(`/projects/${project.id}/shots/${selected.id}/reject-feedback`, { expectedInputRevision: selected.inputRevision });
            setProject(next); resetForm(next.shots.find((shot) => shot.id === selected.id)!);
          })}>不采用候选，恢复修改前版本</button>
        </div>}
        {staleForm && <div className="shot-lint">镜头已在外部更新，当前草稿基于旧版本。<button className="mini-button" onClick={() => resetForm(selected)}>载入最新版本</button></div>}
        <label className="field"><span>镜头提示词</span><textarea rows={6} value={form.prompt} disabled={selected.locked} onChange={(event) => setForm({ ...form, prompt: event.target.value })} /></label>
        <button className="action-button" disabled={busy || selected.locked || Boolean(staleForm)} onClick={() => void update({ prompt: form.prompt })}>保存意图，等待 MCP 改写</button>
        <p className="project-note">保存提示词不会假装画面已改变。让 agent 读取此镜头并提交源码，再校验、预览。</p>
        <label className="field"><span>场景参数 / JSON</span><textarea rows={4} value={form.params} disabled={selected.locked} onChange={(event) => setForm({ ...form, params: event.target.value })} /></label>
        <button className="mini-button" disabled={busy || selected.locked || Boolean(staleForm)} onClick={() => { try { void update({ params: JSON.parse(form.params) }); } catch { setError('参数不是有效 JSON'); } }}>应用参数</button>
        <button className="action-button" disabled={busy} onClick={() => void act(async () => {
          const data = await projectApi<{ shot: ProjectShot; code: string }>(`/projects/${project.id}/shots/${selected.id}/source`);
          setSource({ projectId: project.id, shotId: selected.id, revision: data.shot.inputRevision, code: data.code, feedback: (data.shot.feedback ?? []).filter((note) => note.status !== 'accepted'), feedbackIds: [] });
        })}><FileCode2 size={14} />查看 / 修改真实源码</button>
        <LyricInspector key={`${project.id}:${selected.id}`} projectId={project.id} shot={selected} busy={busy} onProject={setProject} onAction={act} />
        <p className="project-note">来源：{sourceLabel(selected.source)}。{selected.validation ? ` 已通过 ${selected.validation.samples} 帧抽检；不代表逐帧/审美验收。` : ''}</p>
      </> : <div className="project-note">选中镜头以编辑提示词、参数和源码。</div>}
        <div className="project-jobs"><div className="sidebar-title">后台任务</div>{jobs.slice(0, 5).map((job) => <article key={job.id}><strong>{job.kind === 'export' ? '完整 PV' : job.kind === 'validate-transition' ? `转场 ${job.transitionId}` : `镜头 ${job.shotId}`} · {jobLabel[job.status] ?? job.status}</strong><p>{job.detail} {Math.round(job.progress * 100)}%</p>{job.error && <pre>{job.error}</pre>}{['running', 'queued'].includes(job.status) && <button className="mini-button" onClick={() => void act(async () => { await projectApi(`/projects/${project!.id}/jobs/${job.id}/cancel`, {}); })}>取消任务</button>}
          {job.result?.file && <a href={projectFile(project!.id, job.result.file)} target="_blank" rel="noreferrer">打开成片 · 工程 rev_{job.inputRevision}</a>}</article>)}</div>
        {completedVideo && <p className="project-note">最新成片：{completedVideo.result?.frames} 帧 / {completedVideo.result?.seconds?.toFixed(2)}s。后续编辑不改变已经导出的版本。</p>}
      </aside>
    </div>
    <footer className="statusbar"><span>本地工程 · SQLite + 引擎快照</span><span>{project ? `工程 rev_${project.revision} · ${project.song.duration.toFixed(2)}s · ${project.output.fps}fps` : `服务：${serviceUrl}`}</span><span>{activeJobs.length ? '后台任务运行中，页面可关闭' : '就绪'}</span></footer>
    {source && <div className="modal-overlay"><div className="project-source-modal"><header><strong>{source.shotId} · 源码 / 输入 v{source.revision}</strong><button aria-label="关闭源码" onClick={() => setSource(null)}><X size={18} /></button></header>{error && <p className="shot-error" role="alert">{error}</p>}{source.feedback.length > 0 && <div className="project-source-feedback"><strong>这次改动明确响应了哪些意见？</strong>{source.feedback.map((note) => <label key={note.id}><input type="checkbox" checked={source.feedbackIds.includes(note.id)} onChange={(event) => setSource({ ...source, feedbackIds: event.target.checked ? [...source.feedbackIds, note.id] : source.feedbackIds.filter((id) => id !== note.id) })} />{note.text}</label>)}</div>}<textarea spellCheck={false} value={source.code} onChange={(event) => setSource({ ...source, code: event.target.value })} /><footer><span>保存为新版本，不覆盖原始文件。需要通过校验后才能作为有效产物。</span><button className="run-button" disabled={busy} onClick={() => void act(async () => {
      const next = await projectApi<VideoProject>(`/projects/${source.projectId}/shots/${source.shotId}/source`, { expectedInputRevision: source.revision, code: source.code, summary: '人工源码编辑', addressedFeedbackIds: source.feedbackIds, author: 'human' });
      setProject(next); setSource(null); if (selected) resetForm(next.shots.find((shot) => shot.id === selected.id)!);
    })}>保存新源码</button></footer></div></div>}
    {compare && project && selected && <ReviewCompare key={`${project.id}:${selected.id}`} project={project} shot={selected} busy={busy} onClose={() => setCompare(false)} onProject={setProject} onAction={act} />}
  </div>;
}
