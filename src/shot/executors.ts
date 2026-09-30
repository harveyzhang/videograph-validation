// executors.ts — 三条生成通道共享同一任务协调器，不决定校验/重试/采用策略。
import type { ProviderConfig } from '../llm/types';
import { parseSceneResponse } from '../llm/adapters';
import type { FullSongData } from './engine';
import type { ShotExecutor } from './generation';
import { builtinSceneForCard } from './builtinScenes';
import { buildShotMessages, buildShotRepairMessages, generateShotScene } from './codegen';
import { shotQueue } from './queueClient';

export function shotExecutor(song: FullSongData, provider: ProviderConfig | null, builtin = false): ShotExecutor {
  if (builtin) return {
    source: 'builtin', parallel: false,
    async generate(card, signal) {
      signal.throwIfAborted();
      const result = builtinSceneForCard(card);
      return { ...result, summary: `内置模板场景（${result.motif}）——不依赖 LLM/MCP` };
    },
  };
  if (provider) {
    const config = { ...provider };
    return {
      source: 'llm', parallel: false,
      generate: (card, signal, repair) => generateShotScene(config, card, song, repair,
        AbortSignal.any([signal, AbortSignal.timeout(120000)])),
    };
  }
  return {
    source: 'mcp', parallel: true,
    async generate(card, signal, repair) {
      const prompt = repair ? buildShotRepairMessages(card, song, repair) : buildShotMessages(card, song);
      const reply = await shotQueue.request({ kind: 'codegen', cardId: card.id, cardTitle: card.title, prompt }, signal);
      const result = parseSceneResponse(reply.content);
      return { ...result, model: reply.model, summary: `[MCP·${reply.model ?? 'agent'}] ${result.summary}` };
    },
  };
}
