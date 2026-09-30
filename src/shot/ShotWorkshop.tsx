// ShotWorkshop.tsx — 节点/卡片/预览视图；生成任务交给独立协调器，队列交给通道客户端。
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from 'react';
import { Background, BackgroundVariant, Controls, MiniMap, Panel, ReactFlow, addEdge, useEdgesState, useNodesState, type Edge, type Node } from '@xyflow/react';
import { Download, Pause, Play, ScanSearch, X } from 'lucide-react';
import type { useProviders } from '../llm/storage';
import type { useMemory } from '../memory/store';
import { contentHash, type useBlackboard } from '../blackboard/store';
import { buildPlanMessages, builtinPlan, llmPlan, parsePlanResponse, type PlannedCard } from './planner';
import { drawShotFrame, exportShotClip, makeShotCtx, renderStill, ShotPlayer } from './runtime';
import { FULL_SONG, windowDuration } from './engine';
import { ShotGenerationController } from './generation';
import { shotExecutor } from './executors';
import { readQueueState, shotQueue, writeQueueState } from './queueClient';
import { isShotBusy, type ShotArtifact, type ShotSource } from './model';
import { describeShotIssue, MAX_SHOT_REPAIRS } from './validation';
import { shotNodeTypes, type PlanDirectorData, type PlanDirectorNode, type ShotCardData, type ShotCardNode, type SongContextNode } from './shotNodes';

type Providers = ReturnType<typeof useProviders>;
type Memory = ReturnType<typeof useMemory>;
type Blackboard = ReturnType<typeof useBlackboard>;
type AnyNode = SongContextNode | PlanDirectorNode | ShotCardNode;
type PlanState = { state: 'empty' | 'planning' | 'done' | 'error'; source: ShotSource | null; warnings: string[]; error?: string; busyLabel: string };

export function ShotWorkshop({ providers, memory, blackboard }: { providers: Providers; memory: Memory; blackboard: Blackboard }) {
  const [controller] = useState(() => new ShotGenerationController(FULL_SONG));
  const cards = useSyncExternalStore(controller.subscribe, controller.getSnapshot);
  const queue = useSyncExternalStore(shotQueue.subscribe, shotQueue.getSnapshot);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [concept, setConcept] = useState('');
  const [planState, setPlanState] = useState<PlanState>({ state: 'empty', source: null, warnings: [], busyLabel: '' });
  const [dockBusy, setDockBusy] = useState<'rendering' | 'recording' | null>(null);
  const [recordProgress, setRecordProgress] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);
  const dockCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const playerRef = useRef<ShotPlayer | null>(null);
  const planRequestRef = useRef<AbortController | null>(null);
  const planEpochRef = useRef(0);
  const stateSavedAtRef = useRef(0);
  const publishedRef = useRef('');
  const recordedRef = useRef(new WeakSet<ShotArtifact>());

  const generating = cards.filter((card) => isShotBusy(card.status)).length;
  const selected = cards.find((entry) => entry.card.id === selectedId) ?? null;
  const selectedArtifact = selected?.status === 'ready' && selected.artifact?.inputRevision === selected.inputRevision ? selected.artifact : undefined;
  const selectedDraw = selectedArtifact?.draw;

  const stopPlayer = useCallback(() => {
    playerRef.current?.dispose();
    playerRef.current = null;
    setPlaying(false);
  }, []);
  const cancelPlan = useCallback(() => {
    planRequestRef.current?.abort();
    planRequestRef.current = null;
  }, []);
  useEffect(() => () => {
    cancelPlan();
    controller.cancelAll();
    playerRef.current?.dispose();
  }, [cancelPlan, controller]);

  const publishCards = useCallback((plan: PlannedCard[], source: ShotSource, model?: string) => {
    cancelPlan();
    stopPlayer();
    planEpochRef.current += 1;
    stateSavedAtRef.current = Date.now();
    publishedRef.current = '';
    controller.replacePlan(plan);
    setSelectedId(null);
    setEdges([]);
    setPlanState({ state: 'done', source, warnings: [], busyLabel: '' });
    const hash = contentHash(plan);
    blackboard.publish({
      type: 'timeline', label: `镜头卡片带 ×${plan.length}`,
      producer: source === 'builtin' ? '内置参考规划（复刻 pdoom 剪辑）' : `${source} timeline · ${model ?? 'agent'}`,
      schema: 'plan/v1', contentHash: hash, cacheKey: `plan:${hash}`, state: 'miss', size: `${plan.length} cards`,
      lineage: ['song-data', 'style-bible'], summary: plan.map((card) => card.id).join(' → '),
    });
    memory.record({ layer: 'episodic', scope: 'planner', kind: 'generation', title: `规划 ${plan.length} 张镜头卡片 · ${source}`, text: concept.trim() || '按歌曲叙事' });
  }, [blackboard, cancelPlan, concept, controller, memory, setEdges, stopPlayer]);

  const runBuiltinPlan = useCallback(() => publishCards(builtinPlan(FULL_SONG), 'builtin'), [publishCards]);
  const runLlmPlan = useCallback(async () => {
    cancelPlan();
    const request = new AbortController();
    planRequestRef.current = request;
    const provider = providers.active;
    const source = provider ? 'llm' : 'mcp';
    setPlanState({ state: 'planning', source, warnings: [], busyLabel: provider ? 'LLM 听歌规划中…' : '等待外部 agent 规划…' });
    try {
      const result = provider
        ? await llmPlan(provider, concept, FULL_SONG, AbortSignal.any([request.signal, AbortSignal.timeout(120000)]))
        : await shotQueue.request({ kind: 'plan', prompt: buildPlanMessages(FULL_SONG, concept) }, request.signal)
          .then((reply) => ({ ...parsePlanResponse(reply.content, FULL_SONG), model: reply.model }));
      if (planRequestRef.current !== request || request.signal.aborted) return;
      publishCards(result.cards, source, result.model);
      if (result.warnings.length) setPlanState((prev) => ({ ...prev, warnings: result.warnings }));
    } catch (error) {
      if (planRequestRef.current !== request || request.signal.aborted) return;
      planRequestRef.current = null;
      setPlanState({ state: 'error', source, warnings: [], error: String(error).slice(0, 600), busyLabel: '' });
    }
  }, [cancelPlan, concept, providers.active, publishCards]);

  const changeConcept = useCallback((value: string) => {
    if (planRequestRef.current) {
      cancelPlan();
      setPlanState((prev) => ({ ...prev, state: 'empty', busyLabel: '', error: undefined }));
    }
    setConcept(value);
  }, [cancelPlan]);

  const generateAll = useCallback((builtin = false) => {
    stopPlayer();
    const pending = controller.getSnapshot().filter((entry) => !isShotBusy(entry.status) && entry.status !== 'ready');
    void controller.generate(pending.map((entry) => entry.card.id), shotExecutor(FULL_SONG, providers.active, builtin));
  }, [controller, providers.active, stopPlayer]);

  // 只发布已验证的当前产物。黑板仍是概览，不承担完整工程持久化。
  useEffect(() => {
    const ready = cards.filter((entry) => entry.status === 'ready' && entry.artifact);
    for (const entry of ready) {
      const artifact = entry.artifact!;
      if (recordedRef.current.has(artifact)) continue;
      recordedRef.current.add(artifact);
      memory.record({
        layer: 'node', scope: `node:${entry.card.id}`, kind: 'revision',
        title: `${entry.card.id} rev_${artifact.rev} · ${artifact.source}`,
        text: `${artifact.summary.slice(0, 120)}；${artifact.validation.samples} 帧抽检，修复 ${artifact.validation.attempt} 次`,
      });
    }
    if (generating || !ready.length) return;
    const hash = contentHash(ready.map((entry) => ({ id: entry.card.id, input: entry.card, code: entry.artifact!.code, rev: entry.rev })));
    if (publishedRef.current === hash) return;
    publishedRef.current = hash;
    blackboard.publish({
      type: 'scene-code', label: `场景代码 ×${ready.length}/${cards.length}`, producer: '镜头任务协调器（已验证产物）',
      schema: 'shot-scene/v2', contentHash: hash, cacheKey: `shot-batch:${hash}`, state: 'miss', size: `${ready.length} scenes`,
      lineage: ['plan', 'song-data', 'style-bible'], summary: `${ready.length}/${cards.length} 张卡片通过抽检`,
    });
  }, [blackboard, cards, generating, memory]);

  // 兼容 MCP cards.json 热编辑。后续工程服务会替代该快照协议。
  useEffect(() => {
    let stopped = false;
    let inFlight = false;
    const timer = window.setInterval(async () => {
      if (inFlight) return;
      inFlight = true;
      const epoch = planEpochRef.current;
      const before = new Map(controller.getSnapshot().map((entry) => [entry.card.id, entry.inputRevision]));
      try {
        const snapshot = await readQueueState();
        if (stopped || epoch !== planEpochRef.current || !snapshot || snapshot.savedAt <= stateSavedAtRef.current + 2000) return;
        for (const remote of snapshot.cards) {
          const local = controller.getSnapshot().find((entry) => entry.card.id === remote.id);
          if (local && local.inputRevision === before.get(remote.id) && typeof remote.prompt === 'string' && local.card.prompt !== remote.prompt) {
            controller.editPrompt(remote.id, remote.prompt);
          }
        }
        stateSavedAtRef.current = snapshot.savedAt;
      } finally { inFlight = false; }
    }, 10000);
    return () => { stopped = true; window.clearInterval(timer); };
  }, [controller]);

  useEffect(() => {
    if (!cards.length) return;
    const timer = window.setTimeout(() => {
      void writeQueueState(cards.map((entry) => ({
        id: entry.card.id, title: entry.card.title, window: entry.card.window, anchor: entry.card.anchor, prompt: entry.card.prompt,
        status: entry.status, source: entry.source ?? undefined, motif: entry.motif, rev: entry.rev, inputRevision: entry.inputRevision,
        validation: entry.validation,
      })));
      stateSavedAtRef.current = Date.now();
    }, 800);
    return () => window.clearTimeout(timer);
  }, [cards]);

  const closeDock = useCallback(() => { stopPlayer(); setSelectedId(null); }, [stopPlayer]);
  const openCard = useCallback((id: string) => {
    if (selectedId !== id) { stopPlayer(); setSelectedId(id); }
  }, [selectedId, stopPlayer]);

  const reportFrameError = useCallback((id: string, artifact: ShotArtifact, message: string) => {
    const entry = controller.getSnapshot().find((card) => card.card.id === id);
    if (entry?.artifact === artifact && entry.status === 'ready') {
      controller.patchRuntime(id, { status: 'error', error: `预览运行失败：${message}` });
    }
  }, [controller]);

  // 选卡、生成和编辑都清理旧播放器；没有当前有效产物时清空画布，避免旧帧冒充新结果。
  useEffect(() => {
    stopPlayer();
    const canvas = dockCanvasRef.current;
    if (!canvas) return;
    canvas.width = canvas.width;
    if (!selected || !selectedArtifact) return;
    try {
      drawShotFrame(makeShotCtx(selected.card.window), selectedArtifact.draw, canvas,
        selected.card.window.start + windowDuration(selected.card.window) * 0.45);
    } catch (error) { reportFrameError(selected.card.id, selectedArtifact, String(error)); }
  }, [selectedId, selectedArtifact, selected?.inputRevision, reportFrameError, stopPlayer]);

  const dockGenerate = useCallback((builtin = false) => {
    if (!selected) return;
    stopPlayer();
    void controller.generate([selected.card.id], shotExecutor(FULL_SONG, providers.active, builtin));
  }, [controller, providers.active, selected, stopPlayer]);

  const dockStills = useCallback(() => {
    if (!selected || !selectedArtifact) return;
    setDockBusy('rendering');
    try {
      const t = selected.card.window.start + windowDuration(selected.card.window) * 0.45;
      const still = renderStill(makeShotCtx(selected.card.window), selectedArtifact.draw, t, 800, 450);
      if (still.error) throw new Error(still.error);
      controller.patchRuntime(selected.card.id, { thumb: still.dataUrl });
      const hash = contentHash({ code: selectedArtifact.code, window: selected.card.window, t, width: 800 });
      blackboard.publish({ type: 'plate', label: `${selected.card.id} 静帧`, producer: 'browser runtime', schema: 'plate/v1',
        contentHash: hash, cacheKey: `still:${hash}`, state: 'miss', size: '1 frame', lineage: [selected.card.id], summary: `t=${t.toFixed(2)}s` });
    } catch (error) { reportFrameError(selected.card.id, selectedArtifact, String(error)); }
    finally { setDockBusy(null); }
  }, [blackboard, controller, reportFrameError, selected, selectedArtifact]);

  const dockTogglePlay = useCallback(() => {
    if (!selected || !selectedArtifact || dockBusy) return;
    if (playing) { stopPlayer(); return; }
    const canvas = dockCanvasRef.current;
    if (!canvas) return;
    playerRef.current?.dispose();
    const player = new ShotPlayer(canvas, makeShotCtx(selected.card.window), selectedArtifact.draw, {
      onEnd: () => setPlaying(false),
      onFrameError: (message) => { stopPlayer(); reportFrameError(selected.card.id, selectedArtifact, message); },
    });
    playerRef.current = player;
    player.play(true);
    setPlaying(true);
  }, [dockBusy, playing, reportFrameError, selected, selectedArtifact, stopPlayer]);

  const dockExport = useCallback(async () => {
    if (!selected || !selectedArtifact || dockBusy) return;
    stopPlayer();
    setDockBusy('recording');
    setRecordProgress(0);
    try {
      const { blob, seconds } = await exportShotClip(makeShotCtx(selected.card.window), selectedArtifact.draw, { withAudio: true, onProgress: setRecordProgress });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `${selected.card.id}-rev${selectedArtifact.rev}.webm`;
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 4000);
      memory.record({ layer: 'episodic', scope: 'render', kind: 'render', title: `导出 ${selected.card.id} · ${seconds.toFixed(1)}s`, text: `WebM ${(blob.size / 1024 / 1024).toFixed(1)} MB` });
    } catch (error) { reportFrameError(selected.card.id, selectedArtifact, String(error)); }
    finally { setDockBusy(null); setRecordProgress(0); }
  }, [dockBusy, memory, reportFrameError, selected, selectedArtifact, stopPlayer]);

  useEffect(() => {
    const directorData: PlanDirectorData = {
      state: planState.state, source: planState.source, cardCount: cards.length, warnings: planState.warnings,
      concept, busyLabel: planState.busyLabel, error: planState.error, hasProvider: Boolean(providers.active),
      queuePending: queue.pending, queueError: queue.error, onConceptChange: changeConcept,
      onLlmPlan: () => void runLlmPlan(), onBuiltinPlan: runBuiltinPlan,
      onGenerateAll: () => generateAll(), onGenerateBuiltin: () => generateAll(true),
      onCancelAll: () => controller.cancelAll(), generating, ready: cards.filter((entry) => entry.status === 'ready').length,
    };
    const cardNodes: ShotCardNode[] = cards.map((entry, index) => {
      const data: ShotCardData = {
        card: entry.card, index, selected: entry.card.id === selectedId,
        status: entry.status, rev: entry.rev, source: entry.source, model: entry.model, summary: entry.summary,
        error: entry.error, lint: entry.lint, thumb: entry.thumb, motif: entry.motif, validation: entry.validation,
      };
      return { id: entry.card.id, type: 'plan-card', position: { x: 500 + (index % 12) * 310, y: 60 + Math.floor(index / 12) * 430 }, data, selected: entry.card.id === selectedId };
    });
    const base: AnyNode[] = [
      { id: 'song-data', type: 'song-context', position: { x: 20, y: 40 }, data: { variant: 'data' } },
      { id: 'style-bible', type: 'song-context', position: { x: 20, y: 360 }, data: { variant: 'style' } },
      { id: 'plan-director', type: 'plan-director', position: { x: 250, y: 120 }, data: directorData },
    ];
    setNodes((prev) => {
      const previous = new Map(prev.map((node) => [node.id, node]));
      // 保留 ReactFlow 的 measured 尺寸；只保留 position 会让频繁状态更新后的节点永久隐藏。
      return [...base, ...cardNodes].map((node) => {
        const existing = previous.get(node.id);
        return { ...existing, ...node, position: existing?.position ?? node.position };
      }) as Node[];
    });
  }, [cards, changeConcept, concept, controller, generateAll, generating, planState, providers.active, queue, runBuiltinPlan, runLlmPlan, selectedId, setNodes]);

  const dock = selected ? (
    <Panel position="bottom-center" className="shot-dock-wrap">
      <div className="shot-dock">
        <div className="shot-dock-head">
          <strong>{selected.card.title}</strong>
          <span className="shot-dock-meta">{selected.card.window.start.toFixed(1)}s → {selected.card.window.end.toFixed(1)}s · {windowDuration(selected.card.window).toFixed(1)}s · {selected.source ?? '未生成'} · 输入 v{selected.inputRevision} / 产物 rev_{selected.rev}</span>
          <button className="dock-close" aria-label="关闭镜头预览" onClick={closeDock}><X size={13} /></button>
        </div>
        <div className="shot-dock-body">
          <canvas ref={dockCanvasRef} width={800} height={450} className="shot-dock-canvas" onClick={dockTogglePlay} />
          <div className="shot-dock-side">
            <label className="group-label shot-prompt-label">镜头提示词（修改会取消旧任务，只重算此卡）</label>
            <textarea className="shot-prompt" rows={4} value={selected.card.prompt} onChange={(event) => controller.editPrompt(selected.card.id, event.target.value)} spellCheck={false} />
            <div className="shot-actions">
              <button className="mini-button pdoom-run" onClick={() => dockGenerate()} disabled={isShotBusy(selected.status) || dockBusy !== null}>生成场景代码</button>
              {isShotBusy(selected.status) && <button className="mini-button" onClick={() => controller.cancel(selected.card.id)}>取消本卡任务</button>}
              {!providers.active && <button className="mini-button" onClick={() => dockGenerate(true)} disabled={isShotBusy(selected.status) || dockBusy !== null}>本卡用本地模板</button>}
              <button className="mini-button" onClick={dockTogglePlay} disabled={!selectedDraw || dockBusy !== null}>{playing ? <><Pause size={12} /> 暂停</> : <><Play size={12} /> 播放这一段</>}</button>
              <button className="mini-button" onClick={dockStills} disabled={!selectedDraw || dockBusy !== null}><ScanSearch size={12} /> 静帧</button>
              <button className="mini-button" onClick={() => void dockExport()} disabled={!selectedDraw || dockBusy !== null}><Download size={12} /> {dockBusy === 'recording' ? `录制 ${Math.round(recordProgress * 100)}%` : '导出 WebM'}</button>
            </div>
            {selected.error && <div className="shot-error" role="alert">{selected.error}</div>}
            {selected.summary && <div className="shot-summary">{selected.summary}</div>}
            {selected.artifact && !selectedArtifact && <div className="shot-lint">保留了上次成功产物 rev_{selected.artifact.rev}；当前输入尚未通过校验，播放和导出暂不可用。</div>}
            {selected.validation && <details className="shot-validation" open={selected.status !== 'ready'}>
              <summary>{selected.status === 'ready' ? `已通过 ${selected.validation.samples} 帧抽检` : selected.status === 'validating' ? '正在校验' : `自动修复 ${selected.validation.attempt}/${MAX_SHOT_REPAIRS}`} · 诊断记录</summary>
              <div className="shot-lint">抽检检查代码能否运行，不代表逐帧或视觉验收。</div>
              {selected.validation.failures.map(({ attempt, issue }) => <div className="shot-error" key={attempt}>{attempt === 0 ? '首次生成' : `修复 ${attempt}`}：{describeShotIssue(issue)}</div>)}
            </details>}
          </div>
        </div>
      </div>
    </Panel>
  ) : null;

  return (
    <ReactFlow nodes={nodes} edges={edges} nodeTypes={shotNodeTypes} onNodesChange={onNodesChange} onEdgesChange={onEdgesChange}
      onConnect={(connection) => setEdges((current) => addEdge({ ...connection, animated: true }, current))}
      onNodeClick={(_, node) => { if (node.type === 'plan-card') openCard(node.id); }} deleteKeyCode={null}
      fitView fitViewOptions={{ padding: 0.1, maxZoom: 0.85 }} minZoom={0.08} maxZoom={1.2} proOptions={{ hideAttribution: true }}>
      <Background variant={BackgroundVariant.Dots} gap={22} size={1} color="#2e2e2e" />
      <Controls showInteractive={false} />
      <MiniMap nodeColor={(node) => node.type === 'plan-card' ? '#b39ddb' : '#72d9bf'} maskColor="rgba(15, 15, 15, 0.78)" />
      {dock}
    </ReactFlow>
  );
}
