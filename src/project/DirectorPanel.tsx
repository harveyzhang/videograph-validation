// 导演计划来自服务端；本面板只读，不提交简报、不执行 actions、不代替人采用。
import { projectFile, type DirectorSnapshot } from './api';

export type DirectorLoadState = {
  projectId: string;
  status: 'loading' | 'ready' | 'absent' | 'error';
  snapshot?: DirectorSnapshot;
  error?: string;
};

function describe(value: unknown): string {
  if (value == null || value === '') return '未指定';
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') return String(value);
  return JSON.stringify(value, null, 2);
}
const styleLabels = {
  medium: '媒介', palette: '色板', typography: '字体体系', composition: '构图', motion: '运动语言', motif: '母题',
} as const;

export function DirectorPanel({ state, revision, busy, onAccepted }: { state: DirectorLoadState; revision: number; busy?: boolean; onAccepted?: () => void }) {
  if (state.status === 'absent') return null;
  const snapshot = state.snapshot;
  const director = snapshot?.director;
  return <section className="director-panel" aria-label="导演计划（只读）">
    <div className="sidebar-title">导演计划 <span>只读 · GLM / MCP 提交</span></div>
    {state.status === 'loading' && <p className="project-note" role="status">正在读取导演计划…</p>}
    {state.status === 'error' && <p className="director-error" role="alert">导演状态读取失败：{state.error}。将自动重试，暂不开放导出。</p>}
    {snapshot && <>
      <p className="director-phase">阶段：{snapshot.phase} · 工程 rev_{snapshot.revision}
        {director && <> · 计划 v{director.version}</>}</p>
      {snapshot.revision !== revision && <p className="director-warning">导演状态与当前工程版本未同步，等待刷新。</p>}
      <p className={snapshot.exportReady ? 'director-ready' : 'director-warning'}>服务端导出判定：{snapshot.exportReady ? '已就绪' : '尚未就绪'}</p>
      {director && <>
        <details open><summary>创作简报</summary><dl className="director-facts">
          <dt>意图</dt><dd>{describe(director.brief?.intent)}</dd>
          <dt>受众</dt><dd>{describe(director.brief?.audience)}</dd>
          <dt>必须保留</dt><dd>{describe(director.brief?.mustKeep)}</dd>
          <dt>必须避免</dt><dd>{describe(director.brief?.mustAvoid)}</dd>
        </dl></details>
        <details><summary>风格规则</summary><dl className="director-facts">{Object.entries(styleLabels).map(([key, label]) => <div key={key}>
          <dt>{label}</dt><dd>{describe(director.style?.[key as keyof typeof styleLabels])}</dd>
        </div>)}</dl></details>
        <details><summary>节奏计划 / {director.rhythm?.sections?.length ?? 0} 段</summary>
          <ol className="director-list">{(director.rhythm?.sections ?? []).map((section, index) => <li key={`${section.sectionIndex}:${index}`}>
            <strong>段落 {section.sectionIndex} · 能量 {section.energy}</strong><p>{section.intent}</p>
          </li>)}</ol>
          <strong className="director-subtitle">重音落点</strong><pre className="director-json">{describe(director.rhythm?.accents ?? [])}</pre>
        </details>
        <details><summary>镜头计划 / {director.shots?.length ?? 0} 镜</summary><ol className="director-list">
          {(director.shots ?? []).map((shot, index) => <li key={`${shot.shotId}:${index}`}><strong>{shot.shotId} · {shot.subject}</strong>
            <dl className="director-facts"><dt>动作</dt><dd>{describe(shot.action)}</dd><dt>入场</dt><dd>{describe(shot.entrance)}</dd><dt>退场</dt><dd>{describe(shot.exit)}</dd></dl>
          </li>)}
        </ol></details>
        <details><summary>完整计划 / 扩展字段</summary><pre className="director-json">{describe(director)}</pre></details>
      </>}
      <div className="director-section"><h3>下一步 / {(snapshot.actions ?? []).length}</h3>
        <p className="project-note">等待 GLM / MCP 执行；这里不自动调用工具。</p>
        <ol className="director-list">{(snapshot.actions ?? []).map((action) => <li key={action.id} data-blocked={Boolean(action.blocked)}>
          <strong>{action.kind}{action.blocked ? ' · 已阻塞' : ''}</strong>
          {(action.targetKind || action.targetId) && <p>目标：{[action.targetKind, action.targetId].filter(Boolean).join(' / ')}</p>}
          <p>{action.reason}</p><code>{action.tool}</code>
          <details><summary>调用参数 · {action.id}</summary><pre className="director-json">{describe(action.args)}</pre></details>
        </li>)}</ol>
        {!snapshot.actions?.length && <p className="project-note">服务端当前没有下一步动作。</p>}
      </div>
      {(snapshot.blockers ?? []).length > 0 && <div className="director-section director-warning"><h3>阻塞项</h3>
        <ul>{snapshot.blockers.map((blocker, index) => <li key={index}>{blocker}</li>)}</ul>
      </div>}
      <div className="director-section"><h3>审片证据 · {snapshot.review?.current ? '当前版本' : '未覆盖当前版本'}</h3>
        <p className="project-note">{snapshot.review?.humanAccepted ? '人工已接受当前导演候选。' : '自评和技术验证不代表人工已采用。'}</p>
        {snapshot.review?.current && !snapshot.review.humanAccepted && onAccepted && <button className="action-button" disabled={busy || snapshot.revision !== revision} onClick={onAccepted}>我已检查并接受当前导演候选</button>}
        {snapshot.review?.summary && <p>{snapshot.review.summary}</p>}
        <ol className="director-list">{(snapshot.review?.evidence ?? []).map((evidence, index) => <li key={`${evidence.jobId}:${index}`}>
          <strong>任务 {evidence.jobId}</strong>
          {evidence.file && <a href={projectFile(snapshot.projectId, evidence.file)} target="_blank" rel="noreferrer">打开审片证据</a>}
          <pre className="director-json">{describe(evidence)}</pre>
        </li>)}</ol>
        {!snapshot.review?.evidence?.length && <p className="project-note">尚无审片证据。</p>}
      </div>
    </>}
  </section>;
}
