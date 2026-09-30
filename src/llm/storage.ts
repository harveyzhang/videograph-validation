import { useCallback, useMemo, useState } from 'react';
import { createAdapter } from './adapters';
import { defaultBaseUrl, type ProviderConfig, type ProviderKind } from './types';

const KEY = 'videograph.providers.v1';

export interface ProvidersState {
  providers: ProviderConfig[];
  activeId: string | null;
}

interface Persisted extends ProvidersState {}

function load(): Persisted {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return { providers: [], activeId: null };
    const parsed = JSON.parse(raw) as Persisted;
    if (!Array.isArray(parsed.providers)) return { providers: [], activeId: null };
    return parsed;
  } catch {
    return { providers: [], activeId: null };
  }
}

function persist(state: ProvidersState) {
  localStorage.setItem(KEY, JSON.stringify(state));
}

export function newProvider(kind: ProviderKind): ProviderConfig {
  const n = load().providers.length + 1;
  return {
    id: crypto.randomUUID(),
    name: kind === 'anthropic' ? `Anthropic ${n}` : `OpenAI-compatible ${n}`,
    kind,
    baseUrl: defaultBaseUrl[kind],
    apiKey: '',
    model: kind === 'anthropic' ? 'claude-sonnet-4-5' : 'gpt-4o-mini',
  };
}

/** API key 仅保存在本机浏览器 localStorage，用于本地 Demo；正式版应改走本地代理保管。 */
export function useProviders() {
  const [state, setState] = useState<Persisted>(load);

  const update = useCallback((next: ProvidersState) => {
    setState(next);
    persist(next);
  }, []);

  const upsert = useCallback((config: ProviderConfig) => {
    setState((prev) => {
      const exists = prev.providers.some((p) => p.id === config.id);
      const providers = exists ? prev.providers.map((p) => (p.id === config.id ? config : p)) : [...prev.providers, config];
      const next = { providers, activeId: prev.activeId ?? config.id };
      persist(next);
      return next;
    });
  }, []);

  const remove = useCallback((id: string) => {
    setState((prev) => {
      const providers = prev.providers.filter((p) => p.id !== id);
      const next = { providers, activeId: prev.activeId === id ? (providers[0]?.id ?? null) : prev.activeId };
      persist(next);
      return next;
    });
  }, []);

  const setActive = useCallback((id: string | null) => {
    setState((prev) => {
      const next = { ...prev, activeId: id };
      persist(next);
      return next;
    });
  }, []);

  const active = state.providers.find((p) => p.id === state.activeId) ?? null;

  const testConnection = useCallback(async (config: ProviderConfig) => {
    const adapter = createAdapter(config);
    const { text } = await adapter.chat([{ role: 'user', content: 'Reply with the single word: pong' }], { maxTokens: 16 });
    if (!text.trim()) throw new Error('Provider returned an empty reply.');
    return text.trim().slice(0, 40);
  }, []);

  return useMemo(
    () => ({ ...state, active, upsert, remove, setActive, update, testConnection }),
    [state, active, upsert, remove, setActive, update, testConnection],
  );
}
