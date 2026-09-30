// queue.ts — MCP 请求队列的文件协议（node 端共享：vite 中间件和 MCP server 都用）。
// 目录结构：<queueDir>/req-<id>.json（前端写入的请求） + res-<id>.json（agent 提交的答案）
//          + cards.json（卡片带快照，供 MCP 端读写提示词）。
// 前端经 vite 中间件 HTTP 访问；MCP 工具直接 fs 访问；两侧通过文件系统会合。
import { existsSync, mkdirSync, readdirSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export type QueueKind = 'plan' | 'codegen';

export interface QueueRequest {
  id: string;
  kind: QueueKind;
  cardId?: string;
  cardTitle?: string;
  /** 组装好的完整提示词（与直连 API 时喂给模型的文本完全一致）。 */
  prompt: { system: string; user: string };
  createdAt: number;
}

export interface QueueResponse {
  id: string;
  status: 'done' | 'error';
  /** plan 请求：JSON 数组；codegen 请求：```ts 代码块 + SUMMARY 行。 */
  content?: string;
  error?: string;
  model: string;
  submittedAt: number;
}

export interface CardsSnapshot {
  savedAt: number;
  cards: Array<{
    id: string;
    title: string;
    window: { start: number; end: number };
    anchor: string;
    prompt: string;
    status: string;
    source?: string;
    motif?: string;
    rev: number;
  }>;
}

const ID_RE = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,80}$/;

export function validQueueId(id: string): boolean {
  return ID_RE.test(id);
}

function readJson<T>(path: string): T | null {
  try {
    return JSON.parse(readFileSync(path, 'utf8')) as T;
  } catch {
    return null;
  }
}

export function ensureQueueDir(dir: string): string {
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
}

export function listRequests(dir: string): QueueRequest[] {
  ensureQueueDir(dir);
  const out: QueueRequest[] = [];
  for (const name of readdirSync(dir)) {
    if (!name.startsWith('req-') || !name.endsWith('.json')) continue;
    const req = readJson<QueueRequest>(join(dir, name));
    if (req && validQueueId(req.id ?? '')) out.push(req);
  }
  return out.sort((a, b) => a.createdAt - b.createdAt);
}

export function writeRequest(dir: string, request: QueueRequest): void {
  if (!validQueueId(request.id)) throw new Error(`invalid queue id: ${request.id}`);
  ensureQueueDir(dir);
  writeFileSync(join(dir, `req-${request.id}.json`), JSON.stringify(request, null, 1), 'utf8');
}

export function readRequest(dir: string, id: string): QueueRequest | null {
  if (!validQueueId(id)) return null;
  return readJson<QueueRequest>(join(dir, `req-${id}.json`));
}

export function readResponse(dir: string, id: string): QueueResponse | null {
  if (!validQueueId(id)) return null;
  return readJson<QueueResponse>(join(dir, `res-${id}.json`));
}

export function writeResponse(dir: string, response: QueueResponse): void {
  if (!validQueueId(response.id)) throw new Error(`invalid queue id: ${response.id}`);
  ensureQueueDir(dir);
  writeFileSync(join(dir, `res-${response.id}.json`), JSON.stringify(response, null, 1), 'utf8');
}

/** 前端消费完成后清理请求+答案文件。 */
export function ackIds(dir: string, ids: string[]): { removed: string[] } {
  const removed: string[] = [];
  for (const id of ids) {
    if (!validQueueId(id)) continue;
    for (const prefix of ['req-', 'res-']) {
      const path = join(dir, `${prefix}${id}.json`);
      try { unlinkSync(path); removed.push(id); } catch { /* 已不存在 */ }
    }
  }
  return { removed: [...new Set(removed)] };
}

export function readCardsSnapshot(dir: string): CardsSnapshot | null {
  return readJson<CardsSnapshot>(join(dir, 'cards.json'));
}

export function writeCardsSnapshot(dir: string, snapshot: CardsSnapshot): void {
  ensureQueueDir(dir);
  writeFileSync(join(dir, 'cards.json'), JSON.stringify(snapshot, null, 1), 'utf8');
}
