// ProjectStudio.tsx — 审阅室：人看片、定位意见、对比采用；LLM 经 MCP 操作工程。工程/版本/作业状态均来自本地服务。
// 主视图是画面 + 全片时间线；节点图降为只读的“结构视图”。
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Background, Controls, Handle, MiniMap, Panel, Position, ReactFlow, useNodesState, type Edge, type Node, type NodeProps, type ReactFlowInstance } from '@xyflow/react';
import { AudioLines, Clapperboard, FileCode2, FolderOpen, Upload, Play, Download, Lock, Unlock, Layers3, X, RefreshCw, Sparkles } from 'lucide-react';
import { importBgm, projectApi, projectFile, serviceUrl, ProjectApiError, type DirectorSnapshot, type FeedbackAnchor, type VideoProject, type ProjectShot, type ProjectTransition, type ProjectJob, type ProjectSummary } from './api';
import { LyricInspector } from './LyricInspector';
import { TransitionInspector, transitionLabels } from './TransitionInspector';
import { FeedbackComposer } from './FeedbackComposer';
import { ReviewCompare } from './ReviewCompare';
import { SongStagePanel } from './SongStagePanel';
import { DirectorPanel, type DirectorLoadState } from './DirectorPanel';
import { Timeline } from './Timeline';
import { EffectsBox } from './EffectsBox';
import './project.css';
import './review.css';

type ShotNode = Node<{ shot: ProjectShot; projectId: string; index: number } & Record<string, unknown>, 'project-shot'>;
type TransitionNode = Node<{ transition: ProjectTransition; fromTitle: string; toTitle: string } & Record<string, unknown>, 'project-transition'>;
type ContextNode = Node<{ title: string; detail: string; kind: string } & Record<string, unknown>, 'project-context'>;
const sourceLabel = (source: string) => source === 'mcp-authored' ? 'MCP 编写源码' : source === 'human-authored' ? '人工编辑源码' : '导入原工程源码';
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
const nodeTypes = { 'project-shot': ShotNodeView, 'project-context': ContextNodeView, 'project-transition': TransitionNodeView };
const phaseLabel: Record<string, string> = { analysis: '分析中', direction: '待定导演方案', planning: '规划中', producing: '制作中', validating: '验证中', repairing: '返修中', reviewing: '审片中', 'awaiting-human': '等待你确认', 'export-ready': '可以导出', exported: '已导出' };
const message = (error: unknown) => error instanceof Error ? error.message : String(error);
const analysisSourceLabel = (project: VideoProject) => {
  const source = project.analysis.source;
  return source === 'fingerprint-cache' ? '音频指纹命中参考分析 · 未重新识别'
    : source === 'analyzer' ? `音频分析器${project.analysis.cached ? ' · 缓存命中' : ' · 重新分析'}`
    : source === 'pending' ? '等待后台音频分析' : `分析来源：${source || '未知'}`;
};
const jobKindLabel = (job: ProjectJob) => job.kind === 'analysis' ? '歌曲分析'
  : job.kind === 'export' ? '完整 PV' : job.kind === 'validate-transition' ? `转场 ${job.transitionId ?? ''}`
  : job.kind === 'contact-sheet' ? '全片联系表' : job.kind === 'rhythm' ? '节奏报告'
  : job.kind === 'filmstrip' ? '运动帧序列' : job.kind === 'stills' ? '静帧'
  : `镜头 ${job.shotId ?? ''}`;

export default function ProjectStudio() {
  const [projects, setProjects] = useState<ProjectSummary[]>([]);
  const [project, setProject] = useState<VideoProject | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedTransitionId, setSelectedTransitionId] = useState<string | null>(null);
  const [jobs, setJobs] = useState<ProjectJob[]>([]);
  const [directorState, setDirectorState] = useState<DirectorLoadState>({ projectId: '', status: 'absent' });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [preview, setPreview] = useState<string | null>(null);
  const [previewKind, setPreviewKind] = useState('当前版本');
  const [compare, setCompare] = useState(false);
  const [view, setView] = useState<'review' | 'graph' | 'effects'>('review');
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
  const activeProjectId = useRef<string | null>(null);
  const selectedTransition = project?.transitions?.find((transition) => transition.id === selectedTransitionId) ?? null;
  const selected = selectedTransition ? null : project?.shots.find((shot) => shot.id === selectedId) ?? null;
  const selectionRef = useRef('');
  const transitionInputs = selectedTransition ? project?.shots.filter((shot) => shot.id === selectedTransition.fromShotId || shot.id === selectedTransition.toShotId).map((shot) => shot.inputToken).join(':') : '';
  const selectionKey = `${project?.id ?? ''}:${selected?.id ?? selectedTransition?.id ?? ''}:${selected?.inputToken ?? selectedTransition?.inputToken ?? ''}:${transitionInputs}`;
  selectionRef.current = selectionKey;
  useEffect(() => { setPreview(null); setCompare(false); }, [selectionKey]);
  const activeJobs = jobs.filter((job) => job.status === 'queued' || job.status === 'running');
  const completedVideo = jobs.find((job) => job.kind === 'export' && job.status === 'done' && job.result?.file);
  const director = directorState.projectId === project?.id ? directorState.snapshot : undefined;
  const directorKnown = directorState.projectId === project?.id && directorState.status !== 'absent';
  const directorRevisionMatches = Boolean(project && director && director.revision === project.revision);
  const exportAllowedByDirector = !directorKnown || (directorState.status === 'ready' && directorRevisionMatches && director?.exportReady === true);
  const staleForm = selected && form.id === selected.id && form.revision !== selected.inputRevision;
  const unaccepted = project && [...project.shots, ...(project.transitions ?? [])].some((target) => target.feedback?.some((note) => note.status !== 'accepted'));
  const needsGeneration = project && [...project.shots, ...(project.transitions ?? [])].some((target) => target.status === 'needs-generation');
  const awaitingReview = selected?.feedback?.filter((note) => note.status === 'responded') ?? [];
  const beforePlanning = Boolean(project?.status && project.status !== 'planned');
  const exportDisabled = !project || busy || beforePlanning || !project.song || !project.shots.length
    || activeJobs.some((job) => job.kind === 'export')
    || (directorKnown ? !exportAllowedByDirector : Boolean(unaccepted || needsGeneration));
  const exportReason = beforePlanning ? '分析确认和镜头规划完成前不能导出'
    : !project?.song || !project.shots.length ? '等待歌曲数据和镜头规划'
    : directorKnown && !exportAllowedByDirector ? '等待导演服务端 exportReady=true 且版本同步'
    : !directorKnown && unaccepted ? '先校验候选并接受人工修改意见，再导出正式版本'
    : '导出冻结版本';

  const refreshList = useCallback(async () => {
    const data = await projectApi<{ projects: ProjectSummary[] }>('/projects'); setProjects(data.projects); return data.projects;
  }, []);
  const load = useCallback(async (id: string) => {
    const epoch = ++loadEpoch.current;
    const data = await projectApi<VideoProject>(`/projects/${id}`);
    if (epoch !== loadEpoch.current) return;
    activeProjectId.current = id;
    setProject(data); setSelectedId(data.shots[0]?.id ?? null); setSelectedTransitionId(null); setPreview(null); setSource(null); setJobs([]);
    setDirectorState({ projectId: id, status: 'loading' });
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
    let stopped = false, polling = false, round = 0;
    const id = project.id;
    const tick = async () => {
      if (polling) return; polling = true;
      try {
        const [currentResult, jobResult, directorResult] = await Promise.allSettled([
          projectApi<VideoProject>(`/projects/${id}`),
          projectApi<{ jobs: ProjectJob[] }>(`/projects/${id}/jobs`),
          round++ % 3 === 0 ? projectApi<DirectorSnapshot>(`/projects/${id}/director`) : Promise.reject(new Error('skip-director')),
        ]);
        // 切工程的 load 在 React effect 清理之前即可完成；ref 也挡住这一小段竞态。
        if (stopped || activeProjectId.current !== id) return;
        if (currentResult.status === 'fulfilled') {
          const current = currentResult.value;
          setProject((previous) => previous?.id === id && previous.revision <= current.revision ? current : previous);
        }
        if (jobResult.status === 'fulfilled') setJobs(jobResult.value.jobs);
        if (directorResult.status === 'fulfilled') {
          const snapshot = directorResult.value;
          if (snapshot.projectId !== id) {
            setDirectorState({ projectId: id, status: 'error', error: '服务端返回了其他工程的导演状态' });
          } else if (!snapshot.director) {
            setDirectorState({ projectId: id, status: 'absent' });
          } else {
            setDirectorState({ projectId: id, status: 'ready', snapshot });
          }
        } else if (directorResult.reason instanceof Error && directorResult.reason.message === 'skip-director') {
          // 本轮不取导演状态，保留上一次结果
        } else if (directorResult.reason instanceof ProjectApiError && directorResult.reason.status === 404) {
          setDirectorState({ projectId: id, status: 'absent' });
        } else {
          setDirectorState({ projectId: id, status: 'error', error: message(directorResult.reason) });
        }
        const firstError = [currentResult, jobResult].find((result) => result.status === 'rejected');
        if (firstError?.status === 'rejected') setError(message(firstError.reason));
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
      { id: 'analysis', type: 'project-context', position: { x: 280, y: 120 }, data: { title: '词级 / 节拍 / 段落', detail: `${analysisSourceLabel(project)}。${project.analysis.note ?? ''}`, kind: 'analysis' } },
      { id: 'output', type: 'project-context', position: { x: 2900, y: 760 }, data: { title: '全片 / MP4', detail: '冻结工程 → 分段缓存 → 全曲 BGM 封装', kind: 'output' } },
    ];
    const shots: ShotNode[] = project.shots.map((shot, index) => ({ id: `shot-${shot.id}`, type: 'project-shot', selected: shot.id === selectedId,
      position: { x: 610 + (index % 4) * 560, y: Math.floor(index / 4) * 520 }, data: { shot, index, projectId: project.id } }));
    const transitions: TransitionNode[] = (project.transitions ?? []).map((transition, index) => ({
      id: `transition-${transition.id}`, type: 'project-transition', selected: transition.id === selectedTransitionId,
      position: { x: 610 + (index % 4) * 560, y: Math.floor(index / 4) * 520 + 320 },
      data: { transition, fromTitle: project.shots.find((shot) => shot.id === transition.fromShotId)?.title ?? transition.fromShotId,
        toTitle: project.shots.find((shot) => shot.id === transition.toShotId)?.title ?? transition.toShotId },
    }));
    setNodes((previous) => {
      const existing = new Map(previous.map((node) => [node.id, node]));
      return [...contexts, ...shots, ...transitions].map((node) => ({ ...existing.get(node.id), ...node, position: existing.get(node.id)?.position ?? node.position }));
    });
  }, [project, selectedId, selectedTransitionId, setNodes]);
  const edges: Edge[] = useMemo(() => !project ? [] : [
    { id: 'bgm-analysis', source: 'bgm', target: 'analysis' },
    ...project.shots.flatMap((shot) => [
      { id: `in-${shot.id}`, source: 'analysis', target: `shot-${shot.id}`, targetHandle: 'input' },
      { id: `out-${shot.id}`, source: `shot-${shot.id}`, sourceHandle: 'output', target: 'output' },
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
    if (focus && view === 'graph') void flow.current?.fitView({ nodes: [{ id: `shot-${id}` }], maxZoom: 1, padding: 0.4, duration: 220 });
  };
  const selectTransition = (id: string, focus = false) => {
    if (busy) return;
    setSelectedId(null); setSelectedTransitionId(id); setPreview(null);
    if (focus && view === 'graph') void flow.current?.fitView({ nodes: [{ id: `transition-${id}` }], maxZoom: 1, padding: .5, duration: 220 });
  };
  const update = (patch: Record<string, unknown>) => act(async () => {
    if (!project || !selected) return;
    const next = await projectApi<VideoProject>(`/projects/${project.id}/shots/${selected.id}`, { expectedInputRevision: form.revision, patch });
    setProject(next); resetForm(next.shots.find((shot) => shot.id === selected.id)!); setPreview(null);
  });

  const shotIndex = selected ? project!.shots.findIndex((shot) => shot.id === selected.id) : -1;
  const thumbOf = (shot?: ProjectShot | null) => shot?.validation?.thumb && project ? projectFile(project.id, `artifacts/${shot.validation.thumb}`) : null;
  const viewerShot = selected ?? (selectedTransition ? project?.shots.find((shot) => shot.id === selectedTransition.toShotId) ?? null : null);
  const viewerTitle = selected ? selected.title : selectedTransition ? `${project?.shots.find((shot) => shot.id === selectedTransition.fromShotId)?.title ?? selectedTransition.fromShotId} → ${project?.shots.find((shot) => shot.id === selectedTransition.toShotId)?.title ?? selectedTransition.toShotId}` : '选择一个镜头';
  const phase = director?.phase;
  const openFeedback = selected?.feedback?.filter((note) => note.status !== 'accepted') ?? [];
  const addFeedback = async (input: { text: string; anchor?: FeedbackAnchor; preserve?: string[] }, revision: number) => {
    if (!project || !selected) return false;
    let ok = false;
    await act(async () => {
      const next = await projectApi<VideoProject>(`/projects/${project.id}/shots/${selected.id}/feedback`, { expectedInputRevision: revision, ...input });
      setProject(next); resetForm(next.shots.find((entry) => entry.id === selected.id)!); setPreview(null); ok = true;
    });
    return ok;
  };
  const openPreview = (version: 'current' | 'before-feedback') => void act(async () => {
    if (!project || !selected) return;
    const data = await projectApi<{ url: string; range?: { start: number; end: number } }>(`/projects/${project.id}/preview`, { shotId: selected.id, ...(version === 'before-feedback' ? { version } : {}) });
    if (selectionRef.current !== selectionKey) return;
    const start = data.range?.start ?? selected.start, end = data.range?.end ?? selected.end;
    setPreview(`${data.url}/?only=${encodeURIComponent(selected.id)}&t=${start}&rangeStart=${start}&rangeEnd=${end}`); setPreviewKind(version === 'before-feedback' ? '修改前版本' : '当前候选');
  });

  return <div className="app-shell project-shell review-shell">
    <header className="topbar review-topbar">
      <div className="brand-lockup"><span className="brand-mark"><Layers3 size={16} /></span><strong>VideoGraph</strong><span>审阅室</span></div>
      <div className="topbar-project">
        <span className="project-title">{project?.name ?? '从一首 BGM 开始'}</span>
        {phase && <span className={`phase-pill phase-${phase}`}>{phaseLabel[phase] ?? phase}</span>}
        {project && <span className="topbar-meta">{project.shots.length} 镜 · {project.song?.duration ? `${project.song.duration.toFixed(1)}s` : '分析中'} · rev {project.revision}</span>}
      </div>
      <div className="top-actions">
        {completedVideo?.result?.file && <a className="ghost-button" href={projectFile(project!.id, completedVideo.result.file)} target="_blank" rel="noreferrer"><Play size={14} />最新成片</a>}
        <button className="run-button" title={exportReason} disabled={exportDisabled} onClick={() => void act(async () => {
          const job = await projectApi<ProjectJob>(`/projects/${project!.id}/render`, { fps: project!.output.fps, samples: project!.output.samples }); setJobs((previous) => [job, ...previous]);
        })}><Download size={14} />导出完整 PV</button>
      </div>
    </header>
    <div className="project-workspace review-workspace">
      <aside className="sidebar project-library">
        <input ref={fileInput} type="file" accept="audio/*" hidden onChange={(event) => {
          const file = event.target.files?.[0]; if (!file) return;
          void act(async () => { const created = await importBgm(file); await refreshList(); await load(created.id); }); event.target.value = '';
        }} />
        <div className="library-head">
          <label className="project-picker"><span className="visually-hidden">切换工程</span>
            <FolderOpen size={14} />
            <select aria-label="切换工程" disabled={busy} value={project?.id ?? ''} onChange={(event) => void act(() => load(event.target.value))}>
              {!project && <option value="">选择工程</option>}
              {projects.map((entry) => <option key={entry.id} value={entry.id}>{entry.name}</option>)}
            </select>
          </label>
          <button className="icon-button" disabled={busy} title="导入一首 BGM 新建工程：自动分析节拍、段落与歌词" aria-label="只导入 BGM" onClick={() => fileInput.current?.click()}><Upload size={15} /></button>
        </div>
        {project && <p className="library-source" title={project.analysis.note}>{analysisSourceLabel(project)}</p>}
        {project && <><div className="sidebar-title">镜头 <span>{project.shots.length}</span></div>
          <div className="project-shot-list">{project.shots.map((shot, index) => {
            const open = (shot.feedback ?? []).filter((note) => note.status !== 'accepted');
            const waiting = open.some((note) => note.status === 'responded' || note.status === 'needs-clarification');
            return <button key={shot.id} className={selectedId === shot.id ? 'active' : ''} onClick={() => selectShot(shot.id, true)} title={shot.prompt}>
              <span className="shot-thumb">{thumbOf(shot) ? <img src={thumbOf(shot)!} alt="" loading="lazy" /> : <Clapperboard size={14} />}</span>
              <span className="shot-index">{String(index + 1).padStart(2, '0')}</span>
              <span className="shot-text"><strong>{shot.title}</strong><small>{shot.start.toFixed(1)}–{shot.end.toFixed(1)}s</small></span>
              {open.length > 0 && <em className={`shot-badge ${waiting ? 'is-waiting' : ''}`} title={waiting ? '有意见等你处理' : '有意见待 AI 处理'}>{open.length}</em>}
              {shot.locked ? <Lock size={12} /> : <i className={`status-dot status-${shot.status}`} aria-label={statusLabel[shot.status] ?? shot.status} />}
            </button>;
          })}</div></>}
        {project && <details className="project-transition-nav"><summary>转场 <span>{(project.transitions ?? []).length}</span></summary><div className="project-shot-list compact">{(project.transitions ?? []).map((transition, index) => <button key={transition.id} disabled={busy} className={selectedTransitionId === transition.id ? 'active' : ''} onClick={() => selectTransition(transition.id, true)}><span className="shot-index">{index + 1}→{index + 2}</span><span className="shot-text"><strong>{transitionLabels[transition.mode]}</strong></span><small>{transition.locked ? '锁定' : transition.status === 'ready' ? '✓' : '○'}</small></button>)}</div></details>}
      </aside>
      <main className="project-canvas-area review-main">
        <div className="canvas-toolbar review-toolbar">
          <div className="segmented" role="group" aria-label="视图">
            <button className={view === 'review' ? 'is-active' : ''} aria-pressed={view === 'review'} onClick={() => setView('review')}><Play size={13} />审阅</button>
            <button className={view === 'graph' ? 'is-active' : ''} aria-pressed={view === 'graph'} onClick={() => setView('graph')}><Layers3 size={13} />结构视图</button>
            <button className={view === 'effects' ? 'is-active' : ''} aria-pressed={view === 'effects'} onClick={() => setView('effects')}><Sparkles size={13} />特效箱</button>
          </div>
          <span>{view === 'review' ? '看片 · 定位意见 · 对比采用' : view === 'effects' ? `挑风格、调参数预览；选中镜头后可“建议 AI 使用”${selected ? ` · 当前：${selected.title}` : ''}` : '输入依赖与剪辑顺序（只读）'}</span>
        </div>
        {error && <div className="project-error" role="alert">{error}<button aria-label="关闭错误" onClick={() => setError('')}><X size={14} /></button></div>}
        {!project ? <div className="project-empty"><AudioLines size={40} /><h2>把 BGM 变成可以操作的工程</h2><p>源码、字体、素材、时间线和渲染版本一起保存。关闭页面后，后台任务仍然继续。</p><button className="action-button" onClick={() => void act(async () => { await refreshList(); })}><RefreshCw size={14} />重新连接工程服务</button><code>npm run service</code></div>
          : view === 'effects' ? <EffectsBox projectId={project.id} shotId={selected?.id} shotTitle={selected?.title} shotRevision={selected?.inputRevision} busy={busy} />
          : view === 'graph' ? <ReactFlow key={project.id} nodes={nodes} edges={edges} nodeTypes={nodeTypes} onNodesChange={onNodesChange} onInit={(instance) => { flow.current = instance; }}
            onNodeClick={(_, node) => { if (node.id.startsWith('shot-')) selectShot(node.id.slice(5)); else if (node.type === 'project-transition') selectTransition(node.id.slice('transition-'.length)); }} fitView minZoom={0.18} maxZoom={1.4} fitViewOptions={{ padding: 0.12 }} deleteKeyCode={null} nodesConnectable={false} proOptions={{ hideAttribution: true }}>
            <Background gap={24} size={1} /><Controls showInteractive={false} /><MiniMap />
          </ReactFlow>
          : <div className="review-stage">
            <section className="viewer">
              <div className="viewer-head">
                <div><span className="eyebrow">{selected ? `镜头 ${String(shotIndex + 1).padStart(2, '0')} · ${selected.id}` : selectedTransition ? `转场 · ${transitionLabels[selectedTransition.mode]}` : ''}</span><h2>{viewerTitle}</h2></div>
                <div className="viewer-meta">
                  {selected && <span>{selected.start.toFixed(2)}–{selected.end.toFixed(2)}s</span>}
                  {selected && <span className={`status-pill status-${selected.status}`}>{statusLabel[selected.status] ?? selected.status}</span>}
                  {preview && <span className="status-pill is-live">{previewKind} · 真实引擎</span>}
                </div>
              </div>
              <div className="viewer-frame">
                {preview ? <><iframe ref={previewFrameRef} title="真实镜头播放器" src={preview} allow="autoplay" /><button className="viewer-close" aria-label="关闭引擎预览" onClick={() => setPreview(null)}><X size={15} /></button></>
                  : thumbOf(viewerShot) ? <img key={thumbOf(viewerShot)!} src={thumbOf(viewerShot)!} alt={`${viewerTitle} 已验证静帧`} />
                  : <div className="viewer-empty"><Clapperboard size={28} /><span>{viewerShot ? '尚未渲染：等待 AI 写入并验证' : '在左侧或时间线上选择镜头'}</span></div>}
              </div>
              {selected && <div className="viewer-actions">
                <button className="primary-soft" disabled={busy || selected.status === 'needs-generation'} onClick={() => openPreview('current')}><Play size={14} />预览此镜头</button>
                {selected.reviewBaseline && <button className="mini-button" disabled={busy} onClick={() => openPreview('before-feedback')}>预览修改前版本</button>}
                {awaitingReview.length > 0 && <button className="mini-button is-attention" disabled={busy || selected.status !== 'ready'} onClick={() => setCompare(true)}>对比修改前后</button>}
                <span className="viewer-hint">{selected.prompt}</span>
              </div>}
            </section>
            <Timeline project={project} selectedId={selectedId} selectedTransitionId={selectedTransitionId} onSelectShot={(id) => selectShot(id)} onSelectTransition={(id) => selectTransition(id)} />
          </div>}
      </main>
      <aside className="sidebar project-inspector">
        {project && beforePlanning && <SongStagePanel key={project.id} project={project} busy={busy} onProject={setProject} onAction={act} />}
        {project && directorState.projectId === project.id && <DirectorPanel state={directorState} revision={project.revision} busy={busy} onAccepted={() => void act(async () => {
          const next = await projectApi<VideoProject>(`/projects/${project.id}/director/accept-review`, { expectedProjectRevision: project.revision });
          setProject(next);
        })} />}
        {selectedTransition && project ? <TransitionInspector key={`${project.id}:${selectedTransition.id}`} project={project} transition={selectedTransition} busy={busy} onProject={setProject} onAction={act} onJob={(job) => setJobs((previous) => [job, ...previous.filter((entry) => entry.id !== job.id)])} onPreview={(url, label) => {
          if (selectionRef.current !== selectionKey) return false;
          setView('review'); setPreview(url); setPreviewKind(label); return true;
        }} /> : selected && project ? <>
          <div className="sidebar-title">{selected.title}<span>输入 v{selected.inputRevision}</span></div>
          <p className="inspector-meta">{selected.start.toFixed(2)}–{selected.end.toFixed(2)}s · {sourceLabel(selected.source)}{selected.validation ? ` · 已抽检 ${selected.validation.samples} 帧` : ''}</p>
          {awaitingReview.length > 0 && <div className="project-review-box"><strong>AI 已响应 {awaitingReview.length} 条意见，等待你确认</strong>
            <p>技术验证不代表符合你的创作要求。在并排对比中检查同一时间点的修改前与当前候选，再选择采用。</p>
            <button className="action-button" disabled={busy || selected.status !== 'ready'} onClick={() => setCompare(true)}>并排对比，采用或拒绝</button>
            <button className="mini-button" disabled={busy || selected.locked} onClick={() => void act(async () => {
              const next = await projectApi<VideoProject>(`/projects/${project.id}/shots/${selected.id}/reject-feedback`, { expectedInputRevision: selected.inputRevision });
              setProject(next); resetForm(next.shots.find((shot) => shot.id === selected.id)!);
            })}>不采用候选，恢复修改前版本</button>
          </div>}
          {selected.effects?.length ? <section className="inspector-section fx-applied"><h3>已套用特效 <span>{selected.effects.length} 层</span></h3>
            <ol>{selected.effects.map((effect) => <li key={effect.id}><strong>{effect.name}</strong><code>{effect.id}</code></li>)}</ol></section> : null}
          <section className="inspector-section">
            <h3>修改意见 {openFeedback.length > 0 && <span>{openFeedback.length} 条未完成</span>}</h3>
            <FeedbackComposer shot={selected} projectId={project.id} busy={busy} hasPreviewTime={hasPreviewTime} getPreviewTime={() => previewTimeRef.current} onAdd={addFeedback} onProject={setProject} />
          </section>
          <details className="inspector-section"><summary>歌词依据与画面元素</summary>
            <LyricInspector key={`${project.id}:${selected.id}`} projectId={project.id} shot={selected} busy={busy} onProject={setProject} onAction={act} />
          </details>
          <div className="inspector-tools">
            <button className="mini-button" disabled={busy} onClick={() => void act(async () => {
              const data = await projectApi<{ shot: ProjectShot; code: string }>(`/projects/${project.id}/shots/${selected.id}/source`);
              setSource({ projectId: project.id, shotId: selected.id, revision: data.shot.inputRevision, code: data.code, feedback: (data.shot.feedback ?? []).filter((note) => note.status !== 'accepted'), feedbackIds: [] });
            })}><FileCode2 size={13} />查看 / 修改真实源码</button>
            <button className="mini-button" disabled={busy || selected.status === 'needs-generation'} onClick={() => void act(async () => { const job = await projectApi<ProjectJob>(`/projects/${project.id}/validate`, { shotId: selected.id }); setJobs((previous) => [job, ...previous]); })}>5 帧校验</button>
            <button className="mini-button" disabled={busy} onClick={() => void update({ locked: !selected.locked })}>{selected.locked ? <Unlock size={13} /> : <Lock size={13} />}{selected.locked ? '解锁' : '锁定'}</button>
          </div>
          <details className="inspector-section"><summary>高级：镜头意图与参数</summary>
            {staleForm && <div className="shot-lint">镜头已在外部更新，当前草稿基于旧版本。<button className="mini-button" onClick={() => resetForm(selected)}>载入最新版本</button></div>}
            <label className="field"><span>镜头提示词</span><textarea rows={5} value={form.prompt} disabled={selected.locked} onChange={(event) => setForm({ ...form, prompt: event.target.value })} /></label>
            <button className="action-button" disabled={busy || selected.locked || Boolean(staleForm)} onClick={() => void update({ prompt: form.prompt })}>保存意图，等待 MCP 改写</button>
            <p className="project-note">保存提示词不会假装画面已改变。让 agent 读取此镜头并提交源码，再校验、预览。</p>
            <label className="field"><span>场景参数 / JSON</span><textarea rows={4} value={form.params} disabled={selected.locked} onChange={(event) => setForm({ ...form, params: event.target.value })} /></label>
            <button className="mini-button" disabled={busy || selected.locked || Boolean(staleForm)} onClick={() => { try { void update({ params: JSON.parse(form.params) }); } catch { setError('参数不是有效 JSON'); } }}>应用参数</button>
          </details>
        </> : <div className="project-note">选中镜头查看画面、提修改意见。</div>}
        <section className="project-jobs"><div className="sidebar-title">后台任务 {activeJobs.length > 0 && <span>{activeJobs.length} 进行中</span>}</div>{jobs.slice(0, 5).map((job) => <article key={job.id} className={`job-${job.status}`}><strong>{jobKindLabel(job)} · {jobLabel[job.status] ?? job.status}</strong>{['running', 'queued'].includes(job.status) && <div className="job-progress"><i style={{ width: `${Math.round((job.progress ?? 0) * 100)}%` }} /></div>}<p>{job.detail}</p>{job.error && <pre>{job.error}</pre>}{job.kind !== 'analysis' && ['running', 'queued'].includes(job.status) && <button className="mini-button" onClick={() => void act(async () => { await projectApi(`/projects/${project!.id}/jobs/${job.id}/cancel`, {}); })}>取消任务</button>}
          {job.result?.file && <a href={projectFile(project!.id, job.result.file)} target="_blank" rel="noreferrer">打开成片 · 工程 rev_{job.inputRevision}</a>}</article>)}
          {!jobs.length && <p className="project-note">暂无任务。</p>}
          {completedVideo && <p className="project-note">最新成片：{completedVideo.result?.frames} 帧 / {completedVideo.result?.seconds?.toFixed(2)}s。后续编辑不改变已经导出的版本。</p>}
        </section>
      </aside>
    </div>
    <footer className="statusbar"><span>本地工程 · SQLite + 引擎快照</span><span>{project ? `工程 rev_${project.revision} · ${project.song?.duration?.toFixed(2) ?? '歌曲分析中'}${project.song ? `s · ${project.output.fps}fps` : ''}` : `服务：${serviceUrl}`}</span><span>{activeJobs.length ? '后台任务运行中，页面可关闭' : '就绪'}</span></footer>
    {source && <div className="modal-overlay"><div className="project-source-modal"><header><strong>{source.shotId} · 源码 / 输入 v{source.revision}</strong><button aria-label="关闭源码" onClick={() => setSource(null)}><X size={18} /></button></header>{error && <p className="shot-error" role="alert">{error}</p>}{source.feedback.length > 0 && <div className="project-source-feedback"><strong>这次改动明确响应了哪些意见？</strong>{source.feedback.map((note) => <label key={note.id}><input type="checkbox" checked={source.feedbackIds.includes(note.id)} onChange={(event) => setSource({ ...source, feedbackIds: event.target.checked ? [...source.feedbackIds, note.id] : source.feedbackIds.filter((id) => id !== note.id) })} />{note.text}</label>)}</div>}<textarea spellCheck={false} value={source.code} onChange={(event) => setSource({ ...source, code: event.target.value })} /><footer><span>保存为新版本，不覆盖原始文件。需要通过校验后才能作为有效产物。</span><button className="run-button" disabled={busy} onClick={() => void act(async () => {
      const next = await projectApi<VideoProject>(`/projects/${source.projectId}/shots/${source.shotId}/source`, { expectedInputRevision: source.revision, code: source.code, summary: '人工源码编辑', addressedFeedbackIds: source.feedbackIds, author: 'human' });
      setProject(next); setSource(null); if (selected) resetForm(next.shots.find((shot) => shot.id === selected.id)!);
    })}>保存新源码</button></footer></div></div>}
    {compare && project && selected && <ReviewCompare key={`${project.id}:${selected.id}`} project={project} shot={selected} busy={busy} onClose={() => setCompare(false)} onProject={setProject} onAction={act} />}
  </div>;
}
