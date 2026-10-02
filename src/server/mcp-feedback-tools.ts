// mcp-feedback-tools.ts — FB-03：意见收件箱 / 澄清提问 / 画面静帧的 MCP 工具与图片内容封装。
// 仍只作为本地工程服务的 HTTP 客户端，不直接写数据库或工程文件；AI 不能接受意见。
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const productRoot = fileURLToPath(new URL('../..', import.meta.url));
const projectsRoot = () => resolve(process.env.VIDEOGRAPH_PROJECTS ?? join(productRoot, 'projects'));

export interface FeedbackToolDefinition {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}
export type McpContent = { type: 'text'; text: string } | { type: 'image'; data: string; mimeType: 'image/png' };

const feedbackResponsesProperty = {
  feedbackResponses: {
    type: 'array',
    description: '逐条响应说明：[{ feedbackId, outcome: addressed|partial, how }]。partial 必须写 how；只列本次真正处理了的意见。AI 不能接受意见，采用由人在界面完成。',
    items: {
      type: 'object',
      properties: { feedbackId: { type: 'string' }, outcome: { type: 'string', enum: ['addressed', 'partial'] }, how: { type: 'string' } },
      required: ['feedbackId'],
    },
  },
};

/** 给 project_shot_submit / project_transition_configure 的 schema 补 feedbackResponses（保留 addressedFeedbackIds 兼容）。 */
export function withFeedbackResponsesSchema<T extends { name: string; inputSchema: { properties?: Record<string, unknown> } }>(tools: T[]): (T & { inputSchema: Record<string, unknown> })[] {
  return tools.map((tool) => tool.name === 'project_shot_submit' || tool.name === 'project_transition_configure'
    ? { ...tool, inputSchema: { ...tool.inputSchema, properties: { ...(tool.inputSchema.properties ?? {}), ...feedbackResponsesProperty } } }
    : tool);
}

export const feedbackToolDefinitions: FeedbackToolDefinition[] = [
  {
    name: 'project_feedback_inbox',
    description: '列出待处理的人工修改意见（默认 pending；不传 projectId 时汇总所有本地工程），带锚点、保留项、目标上下文与下一步提示。这是 agent 的入口。AI 不能接受意见：采用/拒绝由人在界面完成。',
    inputSchema: {
      type: 'object',
      properties: {
        projectId: { type: 'string' },
        status: { type: 'string', enum: ['open', 'pending', 'needs-clarification', 'responded', 'accepted'], description: "默认 'pending'；'open' 为全部未接受" },
      },
    },
  },
  {
    name: 'project_feedback_ask',
    description: '意见意图含糊时向人提问澄清：意见转为 needs-clarification 并等待人回复，回复前不要改写。AI 不能接受意见，也不能替人回复。',
    inputSchema: {
      type: 'object',
      properties: {
        projectId: { type: 'string' }, targetKind: { type: 'string', enum: ['shot', 'transition'] }, targetId: { type: 'string' },
        feedbackId: { type: 'string' }, question: { type: 'string' },
      },
      required: ['projectId', 'targetKind', 'targetId', 'feedbackId', 'question'],
    },
  },
  {
    name: 'project_stills',
    description: '后台用真实引擎渲染目标镜头/转场在指定时间点的静帧（当前版本或修改前版本 before-feedback），供“看到哪里要改”与修改前后对比。默认时间点 = 意见锚点 t + 窗口 0/0.5/1。返回 job，用 project_job_get 轮询；完成后以 MCP image 内容返回 PNG 并附文件路径。AI 不能接受意见。',
    inputSchema: {
      type: 'object',
      properties: {
        projectId: { type: 'string' }, shotId: { type: 'string' }, transitionId: { type: 'string' },
        times: { type: 'array', items: { type: 'number' }, description: '最多 6 个、必须落在目标时间窗内的秒数' },
        version: { type: 'string', enum: ['current', 'before-feedback'] },
        width: { type: 'integer', minimum: 320, maximum: 1920, description: '默认 960' },
      },
      required: ['projectId'],
    },
  },
];
export const feedbackToolNames = new Set(feedbackToolDefinitions.map((tool) => tool.name));

async function serviceRequest(path: string, body?: unknown): Promise<Record<string, unknown>> {
  const base = process.env.VIDEOGRAPH_SERVICE_URL ?? 'http://127.0.0.1:5191';
  const parsed = new URL(base);
  if (parsed.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(parsed.hostname)) throw new Error('工程服务必须是本机 HTTP 地址');
  const token = readFileSync(process.env.VIDEOGRAPH_SERVICE_TOKEN_FILE ?? join(productRoot, '.cache/service-token'), 'utf8');
  const response = await fetch(base.replace(/\/$/, '') + path, {
    method: body === undefined ? 'GET' : 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(120000),
  });
  const result = await response.json() as Record<string, unknown>;
  if (!response.ok) throw new Error(String(result.error ?? `HTTP ${response.status}`));
  return result;
}

/** 新增意见工具的调用路由；返回与 callProjectTool 同构的 JSON 值。 */
export async function callFeedbackTool(name: string, args: Record<string, unknown>): Promise<Record<string, unknown>> {
  const projectId = typeof args.projectId === 'string' ? encodeURIComponent(args.projectId) : '';
  if (name === 'project_feedback_inbox') {
    const query = new URLSearchParams({ status: typeof args.status === 'string' ? args.status : 'pending' });
    if (args.projectId !== undefined) query.set('projectId', String(args.projectId));
    return serviceRequest(`/feedback?${query}`);
  }
  if (name === 'project_feedback_ask') {
    const scope = args.targetKind === 'transition' ? 'transitions' : 'shots';
    return serviceRequest(`/projects/${projectId}/${scope}/${encodeURIComponent(String(args.targetId))}/feedback/${encodeURIComponent(String(args.feedbackId))}/ask`, { question: args.question });
  }
  if (name === 'project_stills') {
    return serviceRequest(`/projects/${projectId}/stills`, {
      shotId: args.shotId, transitionId: args.transitionId, times: args.times,
      version: args.version === 'before-feedback' ? 'before-feedback' : 'current', width: args.width,
    });
  }
  throw new Error(`unknown feedback tool: ${name}`);
}

const artifactPattern = /^artifacts\/[a-f0-9]{64}\.png$/;
/** stills 产物嵌入为 MCP image 内容；路径校验防穿越，读不到文件时保留文本里的路径不硬塞图片。 */
function stillImageContents(value: unknown): McpContent[] {
  const record = value as { projectId?: unknown; result?: { stills?: { images?: unknown }; images?: unknown }; stills?: { images?: unknown } } | null;
  if (!record || typeof record !== 'object') return [];
  // stills 的 result.stills.images；AE 工具（filmstrip/contact-sheet/rhythm）的 result.images。
  const images = (record.result?.stills?.images ?? record.stills?.images ?? record.result?.images) as Array<{ file?: unknown }> | undefined;
  const projectId = typeof record.projectId === 'string' ? record.projectId : '';
  if (!Array.isArray(images) || !projectId) return [];
  const contents: McpContent[] = [];
  for (const image of images.slice(0, 6)) {
    const file = typeof image?.file === 'string' && artifactPattern.test(image.file) ? image.file : null;
    if (!file) continue;
    try {
      const data = readFileSync(join(projectsRoot(), projectId, file));
      contents.push({ type: 'image', data: data.toString('base64'), mimeType: 'image/png' });
    } catch { /* 文件缺失时仍返回文本结果中的路径 */ }
  }
  return contents;
}

/**
 * 统一把 JSON 工具结果封装为 MCP content（含 stills/AE 产物的 image 内容）。
 * 结果里的长文本（节奏表、节奏报告、技法节选）单独作为一段原样文本，避免被 JSON 转义成一行。
 */
export function mcpToolResult(value: Record<string, unknown>): { content: McpContent[] } {
  const images = stillImageContents(value);
  const result = value.result as Record<string, unknown> | undefined;
  const longText = typeof value.text === 'string' ? value.text : typeof result?.text === 'string' ? result.text : null;
  let structured: Record<string, unknown> = value;
  if (typeof value.text === 'string') { const { text: _text, ...rest } = value; structured = rest; }
  else if (result && typeof result.text === 'string') { const { text: _text, ...rest } = result; structured = { ...value, result: rest }; }
  return { content: [{ type: 'text', text: JSON.stringify(structured, null, 2) }, ...(longText ? [{ type: 'text' as const, text: longText }] : []), ...images] };
}
