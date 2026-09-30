import { useMemo } from 'react';
import { Database, History, LockKeyhole, RotateCcw, ShieldCheck } from 'lucide-react';
import type { BlackboardArtifact, BlackboardStats, CacheEvent, CachePolicy } from '../blackboard/store';
import { artifactLabels } from '../blackboard/store';

export function BlackboardPanel({
  artifacts,
  events,
  stats,
  policy,
  onPolicy,
  onInvalidate,
}: {
  artifacts: BlackboardArtifact[];
  events: CacheEvent[];
  stats: BlackboardStats;
  policy: CachePolicy;
  onPolicy: (policy: CachePolicy) => void;
  onInvalidate: () => void;
}) {
  const recent = useMemo(() => artifacts.slice(-5).reverse(), [artifacts]);
  return (
    <div className="blackboard-panel">
      <div className="blackboard-panel-head"><span><Database size={14} /> 黑板产物总线</span><span className="blackboard-lock"><LockKeyhole size={11} /> API key 不入黑板</span></div>
      <div className="blackboard-stats-row"><b>{stats.artifacts}<small>产物</small></b><b>{stats.cacheHits}<small>命中</small></b><b>{stats.cacheMisses}<small>未命中</small></b><b>{stats.tokensSaved}<small>节省 token</small></b></div>
      <div className="cache-policy"><span>缓存策略</span>{(['exact', 'semantic', 'off'] as CachePolicy[]).map((value) => <button key={value} className={policy === value ? 'active' : ''} onClick={() => onPolicy(value)}>{value === 'exact' ? '精确' : value === 'semantic' ? '语义候选' : '关闭'}</button>)}</div>
      <div className="blackboard-artifacts">{recent.length === 0 && <span className="empty-board">运行节点后，黑板会显示可复用的中间产物。</span>}{recent.map((artifact) => <div className="board-artifact" key={artifact.id}><span className={`artifact-dot artifact-${artifact.state}`} /><span><strong>{artifactLabels[artifact.type]}</strong><small>{artifact.label} · {artifact.schema}</small></span><code>{artifact.contentHash.slice(-8)}</code></div>)}</div>
      <div className="blackboard-actions"><span><History size={12} /> 最近 {events.length} 次缓存事件</span><button onClick={onInvalidate}><RotateCcw size={12} /> 标记过期</button></div>
      <div className="blackboard-note"><ShieldCheck size={12} /> 精确命中必须要求：provider / model / prompt / memory / node inputs / renderer version 全部一致。</div>
    </div>
  );
}
