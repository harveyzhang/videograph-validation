import { useEffect, useState } from 'react';
import { projectApi, type LyricElement, type ProjectShot, type ShotLyricContext, type VideoProject } from './api';

type Props = { projectId: string; shot: ProjectShot; busy: boolean; onProject: (project: VideoProject) => void; onAction: (action: () => Promise<void>) => Promise<boolean> };
const initial = (shot: ProjectShot) => ({ revision: shot.inputRevision, summary: shot.lyricPlan?.summary ?? '',
  elements: (shot.lyricPlan?.elements ?? []).map((element) => ({ ...element, cueWord: element.cue?.word ?? element.cueWord ?? '' })) });

export function LyricInspector({ projectId, shot, busy, onProject, onAction }: Props) {
  const [context, setContext] = useState<ShotLyricContext | null>(null);
  const [error, setError] = useState('');
  const [draft, setDraft] = useState(() => initial(shot));
  useEffect(() => {
    let stopped = false;
    void projectApi<ShotLyricContext>(`/projects/${projectId}/shots/${shot.id}/lyrics`)
      .then((result) => { if (!stopped) { setContext(result); setError(''); } })
      .catch((failure) => { if (!stopped) setError(String(failure)); });
    return () => { stopped = true; };
  }, [projectId, shot.id, shot.inputRevision]);
  const stale = draft.revision !== shot.inputRevision;
  const edit = (index: number, changes: Partial<LyricElement>) => setDraft((current) => ({ ...current, elements: current.elements.map((element, i) => i === index ? { ...element, ...changes } : element) }));
  return <details className="project-lyric-inspector" open>
    <summary>歌词依据 → 画面元素</summary>
    {error && <p className="shot-error">{error}</p>}
    {context?.instrumental ? <p className="project-note">这是器乐窗口，不应虚构歌词；可以说明承接的视觉主题。</p> : <div className="project-lyric-evidence">{context?.lines.map((line) => <p key={line.lineIndex}><small>{line.start.toFixed(2)}–{line.end.toFixed(2)}s</small><span>{line.text}</span></p>)}</div>}
    {stale && <p className="shot-lint">当前草稿基于旧输入。<button className="mini-button" onClick={() => setDraft(initial(shot))}>载入最新元素方案</button></p>}
    <label className="field"><span>这段歌词在表达什么？</span><textarea rows={3} disabled={shot.locked} value={draft.summary} onChange={(event) => setDraft({ ...draft, summary: event.target.value })} /></label>
    {draft.elements.map((element, index) => <div className="project-element-editor" key={index}>
      <label className="field"><span>元素名称</span><input value={element.name} disabled={shot.locked} onChange={(event) => edit(index, { name: event.target.value })} /></label>
      <label className="field"><span>歌词引用（必须来自上面的歌词）</span><input value={element.quote} disabled={shot.locked} onChange={(event) => edit(index, { quote: event.target.value })} /></label>
      <label className="field"><span>含义 / 为什么选它</span><textarea rows={2} value={element.meaning} disabled={shot.locked} onChange={(event) => edit(index, { meaning: event.target.value })} /></label>
      <label className="field"><span>怎样画，怎样动</span><textarea rows={2} value={element.treatment} disabled={shot.locked} onChange={(event) => edit(index, { treatment: event.target.value })} /></label>
      <label className="field"><span>触发词（可选）</span><input value={element.cueWord ?? ''} disabled={shot.locked} onChange={(event) => edit(index, { cueWord: event.target.value })} /></label>
      <select aria-label="元素类型" value={element.kind} disabled={shot.locked} onChange={(event) => edit(index, { kind: event.target.value as LyricElement['kind'] })}><option value="entity">具象物</option><option value="action">动作</option><option value="metaphor">隐喻</option></select>
      <button className="mini-button" disabled={shot.locked} onClick={() => setDraft({ ...draft, elements: draft.elements.filter((_, i) => i !== index) })}>移除此元素</button>
    </div>)}
    <div className="project-inspector-actions"><button className="mini-button" disabled={shot.locked || context?.instrumental || draft.elements.length >= 24} onClick={() => setDraft({ ...draft, elements: [...draft.elements, { name: '', quote: context?.lines[0]?.text ?? '', meaning: '', treatment: '', kind: 'entity', cueWord: '' }] })}>添加有依据的元素</button>
      <button className="action-button" disabled={busy || shot.locked || stale || !draft.summary.trim()} onClick={() => void onAction(async () => {
        const next = await projectApi<VideoProject>(`/projects/${projectId}/shots/${shot.id}`, { expectedInputRevision: draft.revision, patch: { lyricPlan: { summary: draft.summary, elements: draft.elements } } });
        onProject(next); setDraft(initial(next.shots.find((entry) => entry.id === shot.id)!));
      })}>保存元素方案，等待改写</button></div>
    <p className="project-note">方案是可审阅的创作依据，不会假装场景已经使用了这些元素；保存后需要更新源码并检查画面。</p>
  </details>;
}
