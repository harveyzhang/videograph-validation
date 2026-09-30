// queueClient.ts — 会话内 MCP HTTP 通道。只管理本客户端请求；不清理别人的队列。
export interface QueuePrompt { system: string; user: string }
export interface QueueInput {
  kind: 'plan' | 'codegen';
  cardId?: string;
  cardTitle?: string;
  prompt: QueuePrompt;
}
export interface QueueReply { content: string; model?: string }
interface QueueResult { id: string; status: 'pending' | 'done' | 'error'; content?: string; model?: string; error?: string }
interface Pending {
  id: string;
  input: QueueInput;
  written: boolean;
  resolve: (reply: QueueReply) => void;
  reject: (error: Error) => void;
  detach: () => void;
}

async function jsonFetch(path: string, body?: unknown): Promise<Response> {
  const response = await fetch(path, {
    ...(body === undefined ? {} : { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`MCP 队列连接失败：HTTP ${response.status}`);
  return response;
}

export class ShotQueueClient {
  private pending = new Map<string, Pending>();
  private cleanup = new Set<string>();
  private timer: ReturnType<typeof setTimeout> | undefined;
  private polling = false;
  private listeners = new Set<() => void>();
  private state = { pending: 0, error: '' };

  getSnapshot = () => this.state;
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  };
  private emit(error = this.state.error) {
    this.state = { pending: this.pending.size, error };
    for (const listener of this.listeners) listener();
  }

  request(input: QueueInput, signal: AbortSignal): Promise<QueueReply> {
    if (signal.aborted) return Promise.reject(new DOMException('请求已取消', 'AbortError'));
    return new Promise<QueueReply>((resolve, reject) => {
      const id = `${input.kind === 'plan' ? 'plan' : 'shot'}-${crypto.randomUUID()}`;
      const cancel = () => {
        if (!this.pending.delete(id)) return;
        entry.detach();
        reject(new DOMException('请求已取消', 'AbortError'));
        this.cleanup.add(id);
        this.emit();
        this.schedule();
      };
      const entry: Pending = { id, input, written: false, resolve, reject, detach: () => signal.removeEventListener('abort', cancel) };
      this.pending.set(id, entry);
      signal.addEventListener('abort', cancel, { once: true });
      this.emit();
      void this.send(entry);
    });
  }

  private async send(entry: Pending) {
    try {
      // 不用用户的取消信号中断 POST：等待写入确认，再 ack，避免先删后写留下孤儿请求。
      await jsonFetch('/queue/request', { id: entry.id, ...entry.input });
      entry.written = true;
      if (!this.pending.has(entry.id)) this.cleanup.add(entry.id);
      this.emit('');
    } catch (error) {
      this.pending.delete(entry.id);
      entry.detach();
      entry.reject(error instanceof Error ? error : new Error(String(error)));
      this.cleanup.add(entry.id);
      this.emit(String(error));
    }
    this.schedule();
  }

  private schedule() {
    if (this.timer !== undefined || this.polling || (!this.pending.size && !this.cleanup.size)) return;
    this.timer = setTimeout(() => { this.timer = undefined; void this.poll(); }, 2500);
  }

  private async poll() {
    if (this.polling) return;
    this.polling = true;
    try {
      const ids = [...this.pending.values()].filter((entry) => entry.written).map((entry) => entry.id);
      if (ids.length) {
        const response = await jsonFetch(`/queue/poll?ids=${encodeURIComponent(ids.join(','))}`);
        const data = await response.json() as { results: QueueResult[] };
        for (const result of data.results) {
          if (result.status === 'pending') continue;
          const entry = this.pending.get(result.id);
          if (!entry || !ids.includes(result.id)) continue;
          this.pending.delete(result.id);
          entry.detach();
          this.cleanup.add(result.id);
          if (result.status === 'error') entry.reject(new Error(result.error || 'MCP agent 拒绝了请求'));
          else entry.resolve({ content: result.content ?? '', model: result.model });
        }
      }
      if (this.cleanup.size) {
        const ids = [...this.cleanup];
        await jsonFetch('/queue/ack', { ids });
        for (const id of ids) this.cleanup.delete(id);
      }
      this.emit('');
    } catch (error) {
      // 轮询/ack 故障不丢请求；下次恢复连接后继续，且同一时间只有一轮 poll。
      this.emit(`${String(error)}；连接恢复后继续等待。`);
    } finally {
      this.polling = false;
      this.schedule();
    }
  }
}

export const shotQueue = new ShotQueueClient();

export async function readQueueState(): Promise<{ savedAt: number; cards: Array<{ id: string; prompt: string }> } | null> {
  try { return await (await jsonFetch('/queue/state')).json(); }
  catch { return null; }
}

export async function writeQueueState(cards: Array<Record<string, unknown>>): Promise<void> {
  try { await jsonFetch('/queue/state', { cards }); }
  catch { /* 兼容快照不是工程事实源，失败不阻塞当前会话。 */ }
}
