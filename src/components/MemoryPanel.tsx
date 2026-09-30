import { useState } from 'react';
import { Brain, Trash2 } from 'lucide-react';
import { layerMeta, type MemoryEntry, type MemoryLayer } from '../memory/store';

export function MemoryPanel({
  entries,
  onClearLayer,
}: {
  entries: MemoryEntry[];
  onClearLayer: (layer: MemoryLayer) => void;
}) {
  const [layer, setLayer] = useState<MemoryLayer | 'all'>('all');
  const layers = Object.keys(layerMeta) as MemoryLayer[];
  const filtered = entries
    .filter((entry) => layer === 'all' || entry.layer === layer)
    .slice()
    .sort((a, b) => b.createdAt - a.createdAt)
    .slice(0, 7);

  return (
    <div className="inspector-section memory-section">
      <span className="group-label">分层记忆</span>
      <div className="layer-chips">
        <button className={`layer-chip ${layer === 'all' ? 'on' : ''}`} onClick={() => setLayer('all')}>
          全部 <span className="chip-count">{entries.length}</span>
        </button>
        {layers.map((key) => {
          const count = entries.filter((entry) => entry.layer === key).length;
          return (
            <button key={key} className={`layer-chip tone-${layerMeta[key].tone} ${layer === key ? 'on' : ''}`} onClick={() => setLayer(key)}>
              {layerMeta[key].label} <span className="chip-count">{count}</span>
            </button>
          );
        })}
      </div>
      <div className="memory-list">
        {filtered.length === 0 && <div className="provider-empty">此层暂无条目。</div>}
        {filtered.map((entry) => (
          <div className="memory-entry" key={entry.id}>
            <div className="memory-entry-top">
              <span className={`layer-badge tone-${layerMeta[entry.layer].tone}`}>{layerMeta[entry.layer].label}</span>
              <span className="memory-kind">{entry.kind}</span>
              <span className="memory-time">{new Date(entry.createdAt).toLocaleTimeString()}</span>
            </div>
            <strong>{entry.title}</strong>
            <p>{entry.text}</p>
          </div>
        ))}
      </div>
      <div className="memory-foot">
        <span><Brain size={12} /> 生成时自动注入 procedural + style + 最近 3 条 episodic</span>
        {layer !== 'all' && (
          <button className="icon-button" onClick={() => onClearLayer(layer)} aria-label="Clear layer"><Trash2 size={13} /></button>
        )}
      </div>
    </div>
  );
}
