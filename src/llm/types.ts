import type { TechStack } from '../types';

export type ProviderKind = 'openai' | 'anthropic';

export interface ProviderConfig {
  id: string;
  name: string;
  kind: ProviderKind;
  baseUrl: string;
  apiKey: string;
  model: string;
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface ChatResult {
  text: string;
  usage?: { input?: number; output?: number };
}

export interface ChatOptions {
  maxTokens?: number;
  temperature?: number;
  signal?: AbortSignal;
}

export interface LLMAdapter {
  kind: ProviderKind;
  chat(messages: ChatMessage[], opts?: ChatOptions): Promise<ChatResult>;
}

export interface SceneGenResult {
  code: string;
  summary: string;
  techStack: TechStack;
  raw: string;
  usage?: { input?: number; output?: number };
}

export const defaultBaseUrl: Record<ProviderKind, string> = {
  openai: 'https://api.openai.com/v1',
  anthropic: 'https://api.anthropic.com',
};

export const kindLabels: Record<ProviderKind, string> = {
  openai: 'OpenAI 格式 (chat/completions)',
  anthropic: 'Anthropic 格式 (messages)',
};
