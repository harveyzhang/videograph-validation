import { defineConfig, type Connect, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import type { ServerResponse } from 'node:http';
import { execFile } from 'node:child_process';
import { resolve } from 'node:path';
import { promisify } from 'node:util';
import { pdoomTasks, type PdoomTaskId } from './src/pdoom/tasks';
import {
  ackIds,
  listRequests,
  readCardsSnapshot,
  readResponse,
  validQueueId,
  writeCardsSnapshot,
  writeRequest,
  type QueueRequest,
} from './src/shot/queue';

async function toolAvailable(tool: string): Promise<boolean> {
  const candidates = tool === 'ffmpeg'
    ? ['ffmpeg', 'C:/Users/Martis/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-9.0.2-full_build/bin/ffmpeg.exe']
    : [tool];
  for (const candidate of candidates) {
    try { await execFileAsync(candidate, ['-version'], { timeout: 3000 }); return true; } catch { /* next candidate */ }
  }
  return false;
}

const HOP_BY_HOP = new Set([
  'host', 'connection', 'keep-alive', 'transfer-encoding', 'upgrade',
  'origin', 'referer', 'content-length', 'accept-encoding', 'cookie', 'x-llm-base',
]);

/**
 * 本地 LLM 代理：浏览器请求 /llm-proxy/*，由 dev server 转发到 x-llm-base 指定的目标端点。
 * 用于绕开浏览器 CORS（很多 OpenAI 兼容中转站的预检不含 Authorization 白名单），
 * 同时让失败显示真实 HTTP 状态码而不是笼统的 Failed to fetch。
 */
async function forwardLlm(req: Connect.IncomingMessage, res: ServerResponse): Promise<void> {
  const base = req.headers['x-llm-base'];
  if (typeof base !== 'string' || !/^https?:\/\//i.test(base)) {
    res.statusCode = 400;
    res.end('llm-proxy: missing or invalid x-llm-base header');
    return;
  }
  const headers: Record<string, string> = {};
  for (const [key, value] of Object.entries(req.headers)) {
    if (HOP_BY_HOP.has(key) || typeof value !== 'string') continue;
    headers[key] = value;
  }
  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(chunk as Buffer);
  const target = `${base.replace(/\/+$/, '')}${req.url ?? '/'}`;
  try {
    const upstream = await fetch(target, {
      method: req.method ?? 'POST',
      headers,
      body: chunks.length > 0 ? Buffer.concat(chunks) : undefined,
    });
    res.statusCode = upstream.status;
    const contentType = upstream.headers.get('content-type');
    if (contentType) res.setHeader('content-type', contentType);
    res.end(Buffer.from(await upstream.arrayBuffer()));
  } catch (error) {
    res.statusCode = 502;
    res.end(`llm-proxy upstream unreachable: ${String(error)}`);
  }
}

const llmProxyPlugin = (): Plugin => ({
  name: 'videograph-llm-proxy',
  configureServer(server) {
    server.middlewares.use('/llm-proxy', (req, res) => {
      void forwardLlm(req as Connect.IncomingMessage, res).catch((error: unknown) => {
        res.statusCode = 502;
        res.end(`llm-proxy error: ${String(error)}`);
      });
    });
  },
});

const pdoomTaskPlugin = (): Plugin => ({
  name: 'videograph-pdoom-tasks',
  configureServer(server) {
    server.middlewares.use('/pdoom-capabilities', async (_req, res) => {
      const tools = ['uv', 'bun', 'ffmpeg'];
      const availability: Record<string, boolean> = {};
      for (const tool of tools) {
        availability[tool] = await toolAvailable(tool);
      }
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify({ root: resolve('..', 'pdoom-video'), tasks: Object.values(pdoomTasks), availability }));
    });
    server.middlewares.use('/pdoom-task', async (req, res) => {
      if (req.method !== 'POST') { res.statusCode = 405; res.end('POST required'); return; }
      const chunks: Buffer[] = [];
      for await (const chunk of req) chunks.push(chunk as Buffer);
      let body: { taskId?: string } = {};
      try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')) as { taskId?: string }; } catch { /* handled below */ }
      const task = body.taskId ? pdoomTasks[body.taskId as PdoomTaskId] : undefined;
      if (!task) { res.statusCode = 400; res.end(JSON.stringify({ error: 'taskId must be a declared P(DOOM) task' })); return; }
      try {
        const result = await execFileAsync(task.command, task.args, { cwd: resolve('..', task.cwd), timeout: 15 * 60 * 1000, maxBuffer: 1024 * 1024 });
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ ok: true, taskId: task.id, stdout: result.stdout.slice(-8000), stderr: result.stderr.slice(-8000), outputs: task.outputs }));
      } catch (error) {
        const failure = error as { code?: number; stdout?: string; stderr?: string; message?: string };
        res.statusCode = 500;
        res.end(JSON.stringify({ ok: false, taskId: task.id, code: failure.code ?? -1, stdout: failure.stdout?.slice(-8000) ?? '', stderr: failure.stderr?.slice(-8000) ?? failure.message ?? '', outputs: task.outputs }));
      }
    });
  },
});

/**
 * MCP 请求队列网关：浏览器 ⇄ .queue/ 目录 ⇄ MCP 工具（ZCode agent）。
 * - POST /queue/request  { id, kind, cardId?, cardTitle?, prompt:{system,user} }  前端入队
 * - GET  /queue/poll?ids=a,b,c   查询每个请求是否已有 agent 答案
 * - POST /queue/ack      { ids:[...] }   前端消费完毕，清理文件
 * - GET  /queue/list     当前 pending 请求（调试）
 * - GET/POST /queue/state  卡片带快照读写（MCP 端改提示词后前端热合并）
 */
const shotQueuePlugin = (): Plugin => ({
  name: 'videograph-shot-queue',
  configureServer(server) {
    const queueDir = resolve('.queue');
    const json = (res: ServerResponse, value: unknown, code = 200) => {
      res.statusCode = code;
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify(value));
    };
    const body = async (req: Connect.IncomingMessage): Promise<any> => {
      const chunks: Buffer[] = [];
      for await (const chunk of req) chunks.push(chunk as Buffer);
      try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { return {}; }
    };
    server.middlewares.use('/queue', async (req, res) => {
      const url = (req.url ?? '').split('?')[0];
      try {
        if (url === '/request' && req.method === 'POST') {
          const data = await body(req);
          if (!validQueueId(String(data.id ?? '')) || !data.prompt?.system || !data.prompt?.user) {
            return json(res, { error: 'id / prompt.system / prompt.user required' }, 400);
          }
          const request: QueueRequest = {
            id: String(data.id),
            kind: data.kind === 'codegen' ? 'codegen' : 'plan',
            cardId: typeof data.cardId === 'string' ? data.cardId.slice(0, 64) : undefined,
            cardTitle: typeof data.cardTitle === 'string' ? data.cardTitle.slice(0, 80) : undefined,
            prompt: { system: String(data.prompt.system), user: String(data.prompt.user) },
            createdAt: Date.now(),
          };
          writeRequest(queueDir, request);
          return json(res, { ok: true, id: request.id });
        }
        if (url === '/poll' && req.method === 'GET') {
          const ids = new URL(req.url ?? '', 'http://localhost').searchParams.get('ids')?.split(',').filter(Boolean) ?? [];
          const results = ids.filter(validQueueId).map((id) => {
            const response = readResponse(queueDir, id);
            return response
              ? { id, status: response.status, content: response.content, error: response.error, model: response.model }
              : { id, status: 'pending' as const };
          });
          return json(res, { results });
        }
        if (url === '/ack' && req.method === 'POST') {
          const data = await body(req);
          const ids = Array.isArray(data.ids) ? data.ids.map(String).filter(validQueueId) : [];
          return json(res, ackIds(queueDir, ids));
        }
        if (url === '/list' && req.method === 'GET') {
          const requests = listRequests(queueDir).map(({ id, kind, cardId, cardTitle, createdAt }) => ({ id, kind, cardId, cardTitle, createdAt, ageSec: Math.round((Date.now() - createdAt) / 1000) }));
          return json(res, { queueDir, requests });
        }
        if (url === '/state' && req.method === 'GET') {
          return json(res, readCardsSnapshot(queueDir) ?? { savedAt: 0, cards: [] });
        }
        if (url === '/state' && req.method === 'POST') {
          const data = await body(req);
          if (!Array.isArray(data.cards)) return json(res, { error: 'cards array required' }, 400);
          writeCardsSnapshot(queueDir, { savedAt: Date.now(), cards: data.cards });
          return json(res, { ok: true, count: data.cards.length });
        }
        return json(res, { error: `unknown queue route: ${req.method} ${url}` }, 404);
      } catch (error) {
        return json(res, { error: String(error) }, 500);
      }
    });
  },
});

export default defineConfig({
  plugins: [react(), llmProxyPlugin(), pdoomTaskPlugin(), shotQueuePlugin()],
  server: { port: 5188, host: '127.0.0.1' },
});
