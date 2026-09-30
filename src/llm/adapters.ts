import type { PromptSpec, TechStack } from '../types';
import type { MemoryEntry } from '../memory/store';
import type { ShotLyricContext } from '../lyrics/research';
import { buildShotLyricPrompt } from '../lyrics/research';
import type {
  ChatMessage,
  ChatOptions,
  ChatResult,
  LLMAdapter,
  ProviderConfig,
  SceneGenResult,
} from './types';
import { lookupLlmCache, makeLlmCacheKey, storeLlmCache } from './cache';

/** 统一经本地 /llm-proxy 转发（vite dev server），绕开浏览器 CORS；path 为相对目标 base 的路径。 */
async function postJson(path: string, headers: Record<string, string>, body: unknown, base: string, signal?: AbortSignal) {
  const res = await fetch(`/llm-proxy${path}`, {
    method: 'POST',
    headers: { ...headers, 'content-type': 'application/json', 'x-llm-base': base },
    body: JSON.stringify(body),
    signal,
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`HTTP ${res.status} ${res.statusText}${detail ? ` — ${detail.slice(0, 240)}` : ''}`);
  }
  return res.json() as Promise<Record<string, unknown>>;
}

/** OpenAI 兼容格式：覆盖 OpenAI / GLM / DeepSeek / OpenRouter / 各类中转站的 /chat/completions 端点。 */
function openaiAdapter(config: ProviderConfig): LLMAdapter {
  return {
    kind: 'openai',
    async chat(messages, opts): Promise<ChatResult> {
      const body: Record<string, unknown> = { model: config.model, messages };
      if (opts?.temperature !== undefined) body.temperature = opts.temperature;
      const data = await postJson('/chat/completions', {
        accept: 'application/json',
        authorization: `Bearer ${config.apiKey}`,
      }, body, config.baseUrl, opts?.signal);
      const choices = data.choices as Array<{ message?: { content?: string } }> | undefined;
      const usage = data.usage as { prompt_tokens?: number; completion_tokens?: number } | undefined;
      return {
        text: choices?.[0]?.message?.content ?? '',
        usage: usage ? { input: usage.prompt_tokens, output: usage.completion_tokens } : undefined,
      };
    },
  };
}

/** Anthropic 格式：/v1/messages，system 独立字段，max_tokens 必填。 */
function anthropicAdapter(config: ProviderConfig): LLMAdapter {
  return {
    kind: 'anthropic',
    async chat(messages, opts): Promise<ChatResult> {
      const system = messages.filter((m) => m.role === 'system').map((m) => m.content).join('\n\n');
      const rest = messages.filter((m) => m.role !== 'system');
      const data = await postJson('/v1/messages', {
        accept: 'application/json',
        'x-api-key': config.apiKey,
        'anthropic-version': '2023-06-01',
      }, {
        model: config.model,
        max_tokens: opts?.maxTokens ?? 4096,
        temperature: opts?.temperature ?? 0.4,
        ...(system ? { system } : {}),
        messages: rest.map((m) => ({ role: m.role, content: m.content })),
      }, config.baseUrl, opts?.signal);
      const content = data.content as Array<{ type?: string; text?: string }> | undefined;
      const usage = data.usage as { input_tokens?: number; output_tokens?: number } | undefined;
      return {
        text: (content ?? []).filter((b) => b.type === 'text').map((b) => b.text ?? '').join(''),
        usage: usage ? { input: usage.input_tokens, output: usage.output_tokens } : undefined,
      };
    },
  };
}

export function createAdapter(config: ProviderConfig): LLMAdapter {
  return config.kind === 'anthropic' ? anthropicAdapter(config) : openaiAdapter(config);
}

export async function cachedChat(config: ProviderConfig, messages: ChatMessage[], opts: ChatOptions = {}): Promise<{ result: ChatResult; hit: boolean; key: string }> {
  opts.signal?.throwIfAborted();
  const key = makeLlmCacheKey(config, messages, opts);
  const cached = lookupLlmCache(config, key);
  if (cached.hit && cached.result) return { result: cached.result, hit: true, key };
  const result = await createAdapter(config).chat(messages, opts);
  opts.signal?.throwIfAborted();
  storeLlmCache(config, key, result);
  return { result, hit: false, key };
}

const stackInstructions: Record<TechStack, string> = {
  'three-webgl': [
    'Target stack: Three.js / WebGL2 (TypeScript).',
    'Use `import * as THREE from "three"`.',
    'Export `export default class Scene` with `constructor(opts: { width: number; height: number; seed: number })` and `render(f: { t: number; frame: number; beat: number; rms: number })`.',
    'Expose the root Object3D as `get object()` — the runtime adds it to a THREE.Scene and provides a default camera (you may also expose `camera` to control it). Animate inside render(f) only.',
  ].join(' '),
  'remotion-react': [
    'Target stack: Remotion / React (TSX).',
    'Use `useCurrentFrame()`, `useVideoConfig()`, `<AbsoluteFill>`.',
    'Default-export a React component that is a pure function of the current frame.',
  ].join(' '),
  'canvas-2d': [
    'Target stack: Canvas 2D (TypeScript), no dependencies.',
    'Export `export function draw(ctx: CanvasRenderingContext2D, f: { frame: number; t: number; w: number; h: number; beat: number; rms: number; rand: (i: number) => number })`.',
  ].join(' '),
};

/** 分层记忆注入：procedural 是硬规则，style 是软法则，episodic 取最近几次生成/修复作为 few-shot；ctx 注入幕级上下文与修改方向。 */
export interface SceneContext {
  actBrief?: string;
  direction?: string;
  currentCode?: string;
  lyricContext?: ShotLyricContext;
}

export function buildSceneMessages(prompt: PromptSpec, techStack: TechStack, memory: MemoryEntry[], ctx: SceneContext = {}): ChatMessage[] {
  const procedural = memory.filter((m) => m.layer === 'procedural');
  const style = memory.filter((m) => m.layer === 'style');
  const episodic = memory
    .filter((m) => m.layer === 'episodic' && m.scope === 'scene' && (m.kind === 'generation' || m.kind === 'revision'))
    .slice(-3);
  const revising = Boolean(ctx.direction);

  const system = [
    'You are the scene code generator inside VideoGraph, a node-based LLM video programming studio.',
    revising
      ? 'This request REVISIONS an existing shot: modify the current code along the given direction and return the FULL updated file.'
      : 'You write one self-contained deterministic shot scene file per request.',
    procedural.length ? `\nENGINE RULES (must follow):\n${procedural.map((m) => `- ${m.text}`).join('\n')}` : '',
    style.length ? `\nSTYLE LAWS (should follow):\n${style.map((m) => `- ${m.title}: ${m.text}`).join('\n')}` : '',
    '\nOUTPUT FORMAT: reply with exactly one fenced TypeScript code block, then a single line "SUMMARY: <one sentence>". Nothing else.',
  ].filter(Boolean).join('\n');

  const user = [
    `SCENE DESCRIPTION:\n${prompt.scene}`,
    `VISUAL LANGUAGE:\n${prompt.style}`,
    `CAMERA / MOTION:\n${prompt.motion}`,
    `CONSTRAINTS:\n${prompt.constraints}`,
    ctx.actBrief ? `\nACT CONTEXT (this shot belongs to a larger act — stay coherent with it):\n${ctx.actBrief}` : '',
    ctx.lyricContext ? `\n${buildShotLyricPrompt(ctx.lyricContext)}` : '',
    revising ? `\nMODIFICATION DIRECTION:\n${ctx.direction}` : '',
    revising && ctx.currentCode ? `\nCURRENT CODE TO REVISE:\n\`\`\`ts\n${ctx.currentCode}\n\`\`\`` : '',
    `\n${stackInstructions[techStack]}`,
    episodic.length ? `\nRECENT ATTEMPTS (for continuity, do not copy blindly):\n${episodic.map((m) => `- ${m.title}: ${m.text}`).join('\n')}` : '',
  ].filter(Boolean).join('\n');

  return [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ];
}

export function parseSceneResponse(raw: string): { code: string; summary: string } {
  const fence = raw.match(/```(?:ts|tsx|typescript|javascript)?\s*\n([\s\S]*?)```/);
  const code = (fence?.[1] ?? raw).trim();
  const summary = raw.match(/SUMMARY:\s*(.+)/)?.[1]?.trim() ?? 'Generated scene (no summary returned).';
  return { code, summary };
}

export async function generateSceneCode(
  config: ProviderConfig,
  prompt: PromptSpec,
  techStack: TechStack,
  memory: MemoryEntry[],
  ctx: SceneContext = {},
): Promise<SceneGenResult> {
  const adapter = createAdapter(config);
  const { text, usage } = await adapter.chat(buildSceneMessages(prompt, techStack, memory, ctx), { temperature: 0.4 });
  const { code, summary } = parseSceneResponse(text);
  if (!code) throw new Error('Provider returned an empty response.');
  return { code, summary, techStack, raw: text, usage };
}

/** 无 Provider 时的本地确定性回退，保持 Demo 闭环可用。 */
export function simulateSceneCode(prompt: PromptSpec, techStack: TechStack): SceneGenResult {
  const headline = prompt.scene.split('.')[0]?.trim() || 'Untitled scene';
  const templates: Record<TechStack, string> = {
    'three-webgl': `import * as THREE from "three";

// ${headline}
// style: ${prompt.style}
function mulberry32(seed: number) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export default class Scene {
  private group = new THREE.Group();
  private rand = mulberry32(1337);

  get object() {
    return this.group;
  }

  constructor(opts: { width: number; height: number; seed: number }) {
    for (let i = 0; i < 240; i++) {
      const p = new THREE.Vector3(this.rand(), this.rand(), this.rand())
        .sub(new THREE.Vector3(0.5, 0.5, 0.5))
        .multiplyScalar(24);
      const mesh = new THREE.Mesh(
        new THREE.BoxGeometry(0.08, 0.08, 0.08),
        new THREE.MeshBasicMaterial({ color: i % 8 === 0 ? 0x9aaeff : 0x72d9bf }),
      );
      mesh.position.copy(p);
      this.group.add(mesh);
    }
  }

  render(f: { t: number; frame: number; beat: number; rms: number }) {
    this.group.rotation.y = f.t * 0.22 + f.beat * 0.05;
    this.group.rotation.x = Math.sin(f.t * 0.4) * 0.12;
  }
}`,
    'remotion-react': `import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";

// ${headline}
// style: ${prompt.style}
export default function Scene() {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const reveal = Math.min(1, t / 1.2);
  return (
    <AbsoluteFill style={{ background: "#0b0d11", justifyContent: "center", alignItems: "center" }}>
      <div style={{ color: "#72d9bf", fontFamily: "monospace", fontSize: 64, opacity: reveal, letterSpacing: reveal * 6 }}>
        ${headline.toUpperCase()}
      </div>
    </AbsoluteFill>
  );
}`,
    'canvas-2d': `// ${headline}
// style: ${prompt.style}
export function draw(
  ctx: CanvasRenderingContext2D,
  f: { frame: number; t: number; w: number; h: number; beat: number; rms: number; rand: (i: number) => number },
) {
  ctx.fillStyle = "#0b0d11";
  ctx.fillRect(0, 0, f.w, f.h);
  const bars = 96;
  for (let i = 0; i < bars; i++) {
    const h = 8 + f.rand(i) * 180 * (0.4 + f.rms);
    ctx.fillStyle = i % 8 === 0 ? "#9aaeff" : "#72d9bf";
    ctx.fillRect((i / bars) * f.w, f.h - h, f.w / bars - 2, h);
  }
}`,
  };
  const code = templates[techStack];
  return { code, summary: `${headline} — deterministic ${techStack} scene (local simulation).`, techStack, raw: code };
}
