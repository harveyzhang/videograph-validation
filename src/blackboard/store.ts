import { useCallback, useMemo, useState } from 'react';

export type ArtifactType =
  | 'audio-source'
  | 'stems'
  | 'vocal-features'
  | 'lyrics-aligned'
  | 'audio-analysis'
  | 'style-bible'
  | 'scene-code'
  | 'shader-pass'
  | 'plate'
  | 'timeline'
  | 'transition'
  | 'sample-plan'
  | 'composite'
  | 'video';

export type CachePolicy = 'exact' | 'semantic' | 'off';
export type CacheState = 'cold' | 'hit' | 'miss' | 'stale' | 'locked';

export interface BlackboardArtifact {
  id: string;
  type: ArtifactType;
  label: string;
  producer: string;
  schema: string;
  contentHash: string;
  cacheKey: string;
  state: CacheState;
  size: string;
  lineage: string[];
  summary: string;
  updatedAt: number;
}

export interface CacheEvent {
  id: string;
  nodeId: string;
  nodeType: string;
  key: string;
  result: 'hit' | 'miss' | 'stale' | 'bypass';
  tokensSaved?: number;
  timestamp: number;
}

export interface BlackboardStats {
  artifacts: number;
  cacheHits: number;
  cacheMisses: number;
  tokensSaved: number;
  locked: number;
}

const STORAGE_KEY = 'videograph.blackboard.v2';
const CACHE_KEY = 'videograph.cache-events.v1';

function stable(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
  return `{${Object.keys(value as Record<string, unknown>).sort().map((key) => `${JSON.stringify(key)}:${stable((value as Record<string, unknown>)[key])}`).join(',')}}`;
}

/** Browser-safe deterministic hash. It is a cache identity, not a cryptographic secret. */
export function contentHash(value: unknown): string {
  const text = stable(value);
  let hash = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return `fnv1a-${(hash >>> 0).toString(16).padStart(8, '0')}`;
}

export function cacheKey(nodeType: string, inputs: unknown, params: unknown, rendererVersion = 'pdoom-runtime-v1') {
  return `${nodeType}:${rendererVersion}:${contentHash({ inputs, params })}`;
}

function loadArtifacts(): BlackboardArtifact[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) as BlackboardArtifact[] : [];
  } catch { return []; }
}

function loadEvents(): CacheEvent[] {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    return raw ? JSON.parse(raw) as CacheEvent[] : [];
  } catch { return []; }
}

function persist(artifacts: BlackboardArtifact[], events: CacheEvent[]) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(artifacts.slice(-160)));
    localStorage.setItem(CACHE_KEY, JSON.stringify(events.slice(-240)));
  } catch { /* local storage is an optional cache, not the source of truth */ }
}

export function useBlackboard() {
  const [artifacts, setArtifacts] = useState<BlackboardArtifact[]>(loadArtifacts);
  const [events, setEvents] = useState<CacheEvent[]>(loadEvents);
  const [policy, setPolicy] = useState<CachePolicy>(() => {
    try { return (localStorage.getItem('videograph.cache-policy') as CachePolicy) || 'exact'; } catch { return 'exact'; }
  });

  const write = useCallback((nextArtifacts: BlackboardArtifact[], nextEvents = events) => {
    setArtifacts(nextArtifacts);
    setEvents(nextEvents);
    persist(nextArtifacts, nextEvents);
  }, [events]);

  const publish = useCallback((input: Omit<BlackboardArtifact, 'id' | 'updatedAt'>) => {
    const entry: BlackboardArtifact = { ...input, id: `${input.type}-${input.contentHash.slice(-8)}`, updatedAt: Date.now() };
    setArtifacts((prev) => {
      const next = [...prev.filter((item) => item.id !== entry.id && item.type !== entry.type), entry];
      persist(next, events);
      return next;
    });
    return entry;
  }, [events]);

  const recordCache = useCallback((input: Omit<CacheEvent, 'id' | 'timestamp'>) => {
    const event = { ...input, id: crypto.randomUUID(), timestamp: Date.now() };
    setEvents((prev) => {
      const next = [...prev, event];
      persist(artifacts, next);
      return next;
    });
  }, [artifacts]);

  const setCachePolicy = useCallback((next: CachePolicy) => {
    setPolicy(next);
    try { localStorage.setItem('videograph.cache-policy', next); } catch { /* optional */ }
  }, []);

  const invalidate = useCallback((type?: ArtifactType) => {
    setArtifacts((prev) => {
      const next = prev.map((item) => type && item.type !== type ? item : { ...item, state: 'stale' as CacheState });
      persist(next, events);
      return next;
    });
  }, [events]);

  const stats = useMemo<BlackboardStats>(() => ({
    artifacts: artifacts.length,
    cacheHits: events.filter((event) => event.result === 'hit').length,
    cacheMisses: events.filter((event) => event.result === 'miss').length,
    tokensSaved: events.reduce((sum, event) => sum + (event.tokensSaved ?? 0), 0),
    locked: artifacts.filter((item) => item.state === 'locked').length,
  }), [artifacts, events]);

  const recentEvents = useMemo(() => events.slice(-8).reverse(), [events]);
  const recentArtifacts = useMemo(() => artifacts.slice(-8).reverse(), [artifacts]);

  return useMemo(() => ({
    artifacts,
    events,
    policy,
    stats,
    recentEvents,
    recentArtifacts,
    publish,
    recordCache,
    setCachePolicy,
    invalidate,
    write,
  }), [artifacts, events, policy, stats, recentEvents, recentArtifacts, publish, recordCache, setCachePolicy, invalidate, write]);
}

export const artifactLabels: Record<ArtifactType, string> = {
  'audio-source': '音频源',
  stems: 'Stem 分离',
  'vocal-features': '人声特征',
  'lyrics-aligned': '歌词对齐',
  'audio-analysis': '音乐分析',
  'style-bible': '风格圣经',
  'scene-code': '镜头代码',
  'shader-pass': 'Shader Pass',
  plate: '视觉 Plate',
  timeline: '时间线',
  transition: '转场',
  'sample-plan': '采样计划',
  composite: '合成片段',
  video: '最终视频',
};
