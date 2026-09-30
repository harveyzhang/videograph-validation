import { useCallback, useMemo, useState } from 'react';

/**
 * 分层记忆（Layered Memory）
 * L0 workspace  工程层：项目元信息、输出规格（工程是什么）
 * L1 node       节点层：每个节点的最新 revision / 参数 / 诊断（工作集）
 * L2 session    会话层：当前迭代内的临时上下文（易失）
 * L3 episodic   情节层：每次生成/修复/渲染的追加式日志（审计 + few-shot 来源）
 * L4 style      风格层：设计法则、风格圣经（长期审美，软约束）
 * L5 procedural 程序层：Scene API 契约、技术栈约定（硬规则）
 */
export type MemoryLayer = 'workspace' | 'node' | 'session' | 'episodic' | 'style' | 'procedural';

export interface MemoryEntry {
  id: string;
  layer: MemoryLayer;
  scope: string;
  kind: string;
  title: string;
  text: string;
  meta?: Record<string, unknown>;
  createdAt: number;
}

const KEY = 'videograph.memory.v1';
const MAX_EPISODIC = 200;
const MAX_TOTAL = 400;

const order: Record<MemoryLayer, number> = {
  procedural: 0,
  style: 1,
  workspace: 2,
  node: 3,
  episodic: 4,
  session: 5,
};

function makeEntry(input: Omit<MemoryEntry, 'id' | 'createdAt'>): MemoryEntry {
  return { ...input, id: crypto.randomUUID(), createdAt: Date.now() };
}

function seed(): MemoryEntry[] {
  const base = { scope: 'engine' };
  return [
    makeEntry({ ...base, layer: 'procedural', kind: 'rule', title: 'Scene API contract', text: 'A scene must be a pure function of the frame: export default class (three-webgl), default React component (remotion-react), or exported draw() (canvas-2d). No top-level side effects.' }),
    makeEntry({ ...base, layer: 'procedural', kind: 'rule', title: 'Determinism law', text: 'Never use Date.now() or Math.random(). Derive all randomness from a seeded PRNG such as mulberry32(seed).' }),
    makeEntry({ ...base, layer: 'procedural', kind: 'rule', title: 'Output format', text: 'Respond with exactly one fenced TypeScript block followed by a single "SUMMARY:" line. No prose outside them.' }),
    makeEntry({ ...base, layer: 'procedural', kind: 'rule', title: 'Budget', text: 'Keep the scene under ~200 lines, import nothing outside the target stack, no network or filesystem access.' }),
    makeEntry({ scope: 'style/global', layer: 'style', kind: 'law', title: 'Palette', text: 'Near-black graphite base (#0b0d11), mint (#72d9bf) as primary accent, periwinkle (#9aaeff) secondary, amber (#ffc078) reserved for render/output signals.' }),
    makeEntry({ scope: 'style/global', layer: 'style', kind: 'law', title: 'Typography', text: 'Monospace for HUD and data readouts; keep logical font size at or above 12px; titles use wide letter-spacing.' }),
    makeEntry({ scope: 'style/global', layer: 'style', kind: 'law', title: 'Motion', text: 'Movement locks to the beat grid when beat/rms signals are provided; idle motion stays slow and orbital, accents snap on beats.' }),
  ];
}

function load(): MemoryEntry[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return seed();
    const parsed = JSON.parse(raw) as MemoryEntry[];
    if (!Array.isArray(parsed) || parsed.length === 0) return seed();
    return parsed;
  } catch {
    return seed();
  }
}

function persist(entries: MemoryEntry[]) {
  const episodic = entries.filter((e) => e.layer === 'episodic').slice(-MAX_EPISODIC);
  const rest = entries.filter((e) => e.layer !== 'episodic');
  const merged = [...rest, ...episodic]
    .sort((a, b) => order[a.layer] - order[b.layer] || a.createdAt - b.createdAt)
    .slice(-MAX_TOTAL);
  try {
    localStorage.setItem(KEY, JSON.stringify(merged));
  } catch {
    /* 存储满时静默丢弃持久化，内存态继续可用 */
  }
}

export function useMemory() {
  const [entries, setEntries] = useState<MemoryEntry[]>(load);

  const record = useCallback((input: Omit<MemoryEntry, 'id' | 'createdAt'>) => {
    setEntries((prev) => {
      const next = [...prev, makeEntry(input)];
      persist(next);
      return next;
    });
  }, []);

  const remove = useCallback((id: string) => {
    setEntries((prev) => {
      const next = prev.filter((e) => e.id !== id);
      persist(next);
      return next;
    });
  }, []);

  const clearLayer = useCallback((layer: MemoryLayer) => {
    setEntries((prev) => {
      const next = prev.filter((e) => e.layer !== layer);
      persist(next);
      return next;
    });
  }, []);

  return useMemo(() => ({ entries, record, remove, clearLayer }), [entries, record, remove, clearLayer]);
}

export const layerMeta: Record<MemoryLayer, { label: string; tone: 'mint' | 'blue' | 'orange' | 'muted' }> = {
  procedural: { label: 'L5 程序规则', tone: 'mint' },
  style: { label: 'L4 风格法则', tone: 'mint' },
  episodic: { label: 'L3 情节记忆', tone: 'orange' },
  node: { label: 'L1 节点状态', tone: 'blue' },
  session: { label: 'L2 会话', tone: 'muted' },
  workspace: { label: 'L0 工程', tone: 'muted' },
};
