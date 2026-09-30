import type { ProviderConfig, ChatMessage, ChatResult } from './types';
import { contentHash } from '../blackboard/store';

const CACHE_KEY = 'videograph.llm-exact-cache.v1';
const CACHE_VERSION = 'chat-cache/v2';
const TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_ENTRIES = 80;

interface Entry {
  key: string;
  providerId: string;
  providerKind: string;
  endpoint: string;
  model: string;
  createdAt: number;
  result: ChatResult;
}

function load(): Entry[] {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (!raw) return [];
    const now = Date.now();
    return (JSON.parse(raw) as Entry[]).filter((entry) => now - entry.createdAt < TTL_MS).slice(-MAX_ENTRIES);
  } catch { return []; }
}

function persist(entries: Entry[]) {
  try { localStorage.setItem(CACHE_KEY, JSON.stringify(entries.slice(-MAX_ENTRIES))); }
  catch { /* cache is best-effort; generation still runs */ }
}

export interface CacheLookup {
  hit: boolean;
  key: string;
  result?: ChatResult;
}

/**
 * LLM exact cache only serves responses for byte-identical canonical requests.
 * API keys are never included; provider ID scopes credentials without exposing secrets.
 */
export function makeLlmCacheKey(config: ProviderConfig, messages: ChatMessage[], opts: { maxTokens?: number; temperature?: number }) {
  return contentHash({
    schema: CACHE_VERSION,
    providerId: config.id,
    kind: config.kind,
    baseUrl: config.baseUrl.replace(/\/+$/, ''),
    model: config.model,
    messages,
    options: { maxTokens: opts.maxTokens ?? null, temperature: opts.temperature ?? null },
  });
}

export function lookupLlmCache(config: ProviderConfig, key: string): CacheLookup {
  const entries = load();
  const providerId = config.id;
  const found = entries.find((entry) => entry.key === key && entry.providerId === providerId);
  return found ? { hit: true, key, result: found.result } : { hit: false, key };
}

export function storeLlmCache(config: ProviderConfig, key: string, result: ChatResult) {
  const entries = load().filter((entry) => entry.key !== key || entry.providerId !== config.id);
  entries.push({
    key,
    providerId: config.id,
    providerKind: config.kind,
    endpoint: config.baseUrl.replace(/\/+$/, ''),
    model: config.model,
    createdAt: Date.now(),
    result,
  });
  persist(entries);
}

export function clearLlmCache(providerId?: string) {
  const next = providerId ? load().filter((entry) => entry.providerId !== providerId) : [];
  persist(next);
}

export function llmCacheStats() {
  const entries = load();
  return { entries: entries.length, approximateTokens: entries.reduce((sum, entry) => sum + (entry.result.usage?.output ?? 0), 0), ttlDays: 7 };
}
