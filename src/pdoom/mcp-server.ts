import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';
import { projectToolDefinitions, callProjectTool } from '../server/mcp-tools.ts';
import { pdoomTasks, type PdoomTaskId } from './tasks.ts';
import {
  listRequests,
  readCardsSnapshot,
  readRequest,
  validQueueId,
  writeCardsSnapshot,
  writeResponse,
} from '../shot/queue.ts';

const taskIds = Object.keys(pdoomTasks) as PdoomTaskId[];
const root = resolve(process.env.PDOOM_ROOT ?? process.cwd(), '..', 'pdoom-video');
// 队列目录与 vite 中间件共用：video-graph-demo/.queue（server 经 npm run mcp:pdoom 在项目根启动）
const queueDir = process.env.VIDEOGRAPH_QUEUE ? resolve(process.env.VIDEOGRAPH_QUEUE) : resolve(process.cwd(), '.queue');

const server = new Server(
  { name: 'videograph-pdoom', version: '0.1.0' },
  { capabilities: { tools: {} } },
);

const taskInput = z.object({ taskId: z.enum(taskIds as [PdoomTaskId, ...PdoomTaskId[]]) });
const renderInput = z.object({ mode: z.enum(['stills', 'video', 'plates', 'perf']).default('stills'), from: z.number().optional(), to: z.number().optional(), out: z.string().optional() });

function textResult(value: unknown, isError = false) {
  return { content: [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }], ...(isError ? { isError: true } : {}) };
}

function runTask(taskId: PdoomTaskId, argsOverride: string[] = []): Promise<{ code: number; stdout: string; stderr: string }> {
  const task = pdoomTasks[taskId];
  const cwd = resolve(root, task.cwd.replace(/^pdoom-video[\\/]/, ''));
  return new Promise((resolvePromise) => {
    const child = spawn(task.command, argsOverride.length ? argsOverride : task.args, { cwd, shell: false, windowsHide: true });
    let stdout = ''; let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += String(chunk); });
    child.stderr.on('data', (chunk) => { stderr += String(chunk); });
    child.on('error', (error) => resolvePromise({ code: -1, stdout, stderr: `${stderr}\n${String(error)}` }));
    child.on('close', (code) => resolvePromise({ code: code ?? -1, stdout, stderr }));
  });
}

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    ...projectToolDefinitions,
    { name: 'pdoom_inspect_project', description: '读取 P(DOOM) 工程的固定目录、工具依赖和可用任务，不执行命令。', inputSchema: { type: 'object', properties: {} } },
    { name: 'pdoom_run_analysis', description: '运行已声明的 P(DOOM) 音频分析任务。只能传 taskId，不接受任意 shell。', inputSchema: { type: 'object', properties: { taskId: { type: 'string', enum: ['analyze-stems', 'align-lyrics', 'analyze-audio'] } }, required: ['taskId'] } },
    { name: 'pdoom_render', description: '调用 P(DOOM) 已有的 stills/video/plates/perf 渲染模式。', inputSchema: { type: 'object', properties: { mode: { type: 'string', enum: ['stills', 'video', 'plates', 'perf'] }, from: { type: 'number' }, to: { type: 'number' }, out: { type: 'string' } }, required: ['mode'] } },
    { name: 'pdoom_blackboard_contract', description: '返回黑板 artifact、缓存键和记忆边界契约。', inputSchema: { type: 'object', properties: {} } },
    { name: 'lyric_research_draft', description: '为一段歌词生成结构化语义/黑话/文化引用研究草稿；只返回研究待审内容，不自动视为事实。', inputSchema: { type: 'object', properties: { line: { type: 'string' }, language: { type: 'string' }, context: { type: 'string' } }, required: ['line'] } },
    {
      name: 'shot_queue_list',
      description: '列出 VideoGraph 工坊 MCP 队列中等待处理的请求（前端在未配置 LLM API 时产生）。你是队列的 LLM：读取请求 → 自己生成内容 → shot_queue_submit 提交。',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'shot_queue_get',
      description: '读取一个队列请求的完整提示词（system+user）。plan 请求：按 user 里的 schema 输出 JSON 数组；codegen 请求：输出一个 ```ts 代码块 + 一行 "SUMMARY: <一句话>"。生成后用 shot_queue_submit 提交。',
      inputSchema: { type: 'object', properties: { id: { type: 'string', description: '请求 id（shot_queue_list 返回）' } }, required: ['id'] },
    },
    {
      name: 'shot_queue_submit',
      description: '提交队列请求的答案。content 格式：plan 请求 = JSON 数组文本；codegen 请求 = ```ts 代码块 + SUMMARY 行。提交前请自行检查：代码符合引擎契约（draw(ctx,f,api)、纯函数、禁 Math.random/import）、JSON 能被解析。',
      inputSchema: { type: 'object', properties: { id: { type: 'string' }, content: { type: 'string' }, model: { type: 'string', description: '生成者标识，默认 ZCode-agent' } }, required: ['id', 'content'] },
    },
    {
      name: 'shot_queue_reject',
      description: '拒绝一个队列请求（内容无法生成/违规），前端会收到错误提示。',
      inputSchema: { type: 'object', properties: { id: { type: 'string' }, reason: { type: 'string' } }, required: ['id', 'reason'] },
    },
    {
      name: 'shot_cards_read',
      description: '读取工坊当前镜头卡片带快照（id/标题/时间窗/提示词/状态），用于了解现状或编辑提示词。',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'shot_cards_update_prompt',
      description: '修改一张镜头卡片的提示词并写回快照；工坊前端会轮询发现变化并热更新（卡片转待重算）。cardId 来自 shot_cards_read。',
      inputSchema: { type: 'object', properties: { cardId: { type: 'string' }, prompt: { type: 'string' } }, required: ['cardId', 'prompt'] },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const name = request.params.name;
  if (projectToolDefinitions.some((tool) => tool.name === name)) {
    try { return textResult(await callProjectTool(name, request.params.arguments ?? {})); }
    catch (error) { return textResult({ error: String(error), hint: '工程服务需要运行：npm run service' }, true); }
  }
  if (name === 'pdoom_inspect_project') {
    return textResult({ root, taskIds, tasks: pdoomTasks, rule: 'Only declared task ids are executable; API keys and arbitrary shell are prohibited.' });
  }
  if (name === 'pdoom_blackboard_contract') {
    return textResult({
      cache: { exactKey: ['taskId', 'args', 'input artifact hashes', 'renderer version'], semantic: 'candidate only; never auto-reuses code or render artifacts', secrets: 'never persisted' },
      layers: { procedural: 'engine contract', style: 'style bible', workspace: 'project facts', node: 'revision/diagnostics', episodic: 'run history', session: 'temporary context' },
      artifactLineage: 'producer -> schema -> contentHash -> cacheKey -> downstream node',
    });
  }
  if (name === 'lyric_research_draft') {
    const args = request.params.arguments as { line?: string; language?: string; context?: string };
    if (!args?.line?.trim()) return textResult({ error: 'line is required' }, true);
    return textResult({
      status: 'needs-review',
      line: args.line,
      language: args.language ?? 'auto',
      context: args.context ?? '',
      instructions: [
        'Identify literal meaning first.',
        'List slang, meme, subculture and cultural references separately.',
        'Attach a source URL or mark as needs verification.',
        'Give visual implications, not final shot code.',
        'Do not promote unverified interpretations into approved memory.',
      ],
      outputSchema: { literalMeaning: 'string', findings: [{ phrase: 'string', kind: 'slang|meme|cultural-reference|brand-risk', meaning: 'string', visualImplication: 'string', confidence: 'high|medium|low', sources: ['url'] }], visualDirection: 'string' },
    });
  }
  if (name === 'pdoom_run_analysis') {
    const parsed = taskInput.safeParse(request.params.arguments ?? {});
    if (!parsed.success) return textResult({ error: parsed.error.flatten() }, true);
    const result = await runTask(parsed.data.taskId);
    return textResult({ taskId: parsed.data.taskId, root, ...result }, result.code !== 0);
  }
  if (name === 'pdoom_render') {
    const parsed = renderInput.safeParse(request.params.arguments ?? {});
    if (!parsed.success) return textResult({ error: parsed.error.flatten() }, true);
    const args = ['scripts/render.ts', parsed.data.mode];
    if (parsed.data.from !== undefined) args.push('--from', String(parsed.data.from));
    if (parsed.data.to !== undefined) args.push('--to', String(parsed.data.to));
    if (parsed.data.out) args.push('--out', parsed.data.out);
    const result = await runTask('render-video', args);
    return textResult({ mode: parsed.data.mode, root, ...result }, result.code !== 0);
  }
  if (name === 'shot_queue_list') {
    const requests = listRequests(queueDir).map(({ id, kind, cardId, cardTitle, prompt, createdAt }) => ({
      id,
      kind,
      cardId,
      cardTitle,
      createdAt,
      ageSec: Math.round((Date.now() - createdAt) / 1000),
      promptChars: prompt.system.length + prompt.user.length,
    }));
    return textResult({ queueDir, pending: requests.length, requests, usage: 'shot_queue_get(id) 读完整提示词 → 自己生成 → shot_queue_submit(id, content) 提交' });
  }
  if (name === 'shot_queue_get') {
    const args = request.params.arguments as { id?: string };
    if (!args?.id || !validQueueId(args.id)) return textResult({ error: 'valid id required' }, true);
    const req = readRequest(queueDir, args.id);
    if (!req) return textResult({ error: `request ${args.id} not found (可能已被前端消费清理)` }, true);
    return textResult({
      id: req.id,
      kind: req.kind,
      cardId: req.cardId,
      cardTitle: req.cardTitle,
      contentFormat: req.kind === 'plan'
        ? '输出 JSON 数组（每元素 {id,title,anchorLine,endLine?,prompt}），无代码围栏'
        : '输出一个 ```ts 代码块（export function draw(ctx, f, api)）+ 一行 "SUMMARY: <一句话>"',
      system: req.prompt.system,
      user: req.prompt.user,
    });
  }
  if (name === 'shot_queue_submit') {
    const args = request.params.arguments as { id?: string; content?: string; model?: string };
    if (!args?.id || !validQueueId(args.id)) return textResult({ error: 'valid id required' }, true);
    if (!args.content || !args.content.trim()) return textResult({ error: 'content required' }, true);
    const req = readRequest(queueDir, args.id);
    if (!req) return textResult({ error: `request ${args.id} not found (可能已被前端消费清理)` }, true);
    writeResponse(queueDir, { id: args.id, status: 'done', content: args.content, model: args.model ?? 'ZCode-agent', submittedAt: Date.now() });
    return textResult({ ok: true, id: args.id, kind: req.kind, chars: args.content.length, note: '前端轮询约 2.5s 内取走并渲染' });
  }
  if (name === 'shot_queue_reject') {
    const args = request.params.arguments as { id?: string; reason?: string };
    if (!args?.id || !validQueueId(args.id)) return textResult({ error: 'valid id required' }, true);
    writeResponse(queueDir, { id: args.id, status: 'error', error: args.reason ?? 'rejected by agent', model: 'ZCode-agent', submittedAt: Date.now() });
    return textResult({ ok: true, id: args.id, rejected: true });
  }
  if (name === 'shot_cards_read') {
    const snapshot = readCardsSnapshot(queueDir);
    if (!snapshot) return textResult({ error: 'cards.json 不存在（工坊还没规划过，或前端还没保存）' }, true);
    return textResult({ savedAt: new Date(snapshot.savedAt).toISOString(), cardCount: snapshot.cards.length, cards: snapshot.cards });
  }
  if (name === 'shot_cards_update_prompt') {
    const args = request.params.arguments as { cardId?: string; prompt?: string };
    const snapshot = readCardsSnapshot(queueDir);
    if (!snapshot) return textResult({ error: 'cards.json 不存在（工坊还没规划过）' }, true);
    if (!args?.cardId || typeof args.prompt !== 'string' || !args.prompt.trim()) return textResult({ error: 'cardId and non-empty prompt required' }, true);
    const card = snapshot.cards.find((c) => c.id === args.cardId);
    if (!card) return textResult({ error: `card ${args.cardId} not found; 用 shot_cards_read 查看现有卡片` }, true);
    card.prompt = args.prompt.trim();
    writeCardsSnapshot(queueDir, snapshot);
    return textResult({ ok: true, cardId: card.id, title: card.title, promptChars: card.prompt.length, note: '前端轮询发现后热更新该卡（转待重算）' });
  }
  return textResult({ error: `Unknown tool: ${name}` }, true);
});

await server.connect(new StdioServerTransport());
