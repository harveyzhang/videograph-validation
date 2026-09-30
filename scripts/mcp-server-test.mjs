import { spawn } from 'node:child_process';
import { writeFileSync, readdirSync } from 'node:fs';

// MCP server 手测：initialize → tools/list → 放一个假请求 → shot_queue_list/get/submit → shot_cards_update_prompt
const QUEUE = 'F:/aicg/video-graph-demo/.queue';
writeFileSync(`${QUEUE}/req-mcptest-1.json`, JSON.stringify({
  id: 'mcptest-1', kind: 'codegen', cardId: 'loss', cardTitle: 'LOSS · 骤降',
  prompt: { system: 'SYSTEM-CONTRACT-测试', user: 'USER-PROMPT-测试' }, createdAt: Date.now(),
}));

const proc = spawn('node', ['--experimental-strip-types', '--no-warnings', 'src/pdoom/mcp-server.ts'], { cwd: 'F:/aicg/video-graph-demo' });
let buf = '';
const pending = new Map();
let nextId = 1;
proc.stdout.on('data', (chunk) => {
  buf += String(chunk);
  let idx;
  while ((idx = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line) continue;
    const msg = JSON.parse(line);
    const resolve = pending.get(msg.id);
    if (resolve) { pending.delete(msg.id); resolve(msg); }
  }
});

const call = (method, params) => new Promise((resolve) => {
  const id = nextId++;
  pending.set(id, resolve);
  proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
});

const out = {};
await call('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'audit', version: '0' } });
const tools = await call('tools/list', {});
out.toolCount = tools.result.tools.length;
out.shotTools = tools.result.tools.filter((t) => t.name.startsWith('shot_')).map((t) => t.name);

const list = await call('tools/call', { name: 'shot_queue_list', arguments: {} });
const listBody = JSON.parse(list.result.content[0].text);
out.queueList = { pending: listBody.pending, ids: listBody.requests.map((r) => r.id) };

const got = await call('tools/call', { name: 'shot_queue_get', arguments: { id: 'mcptest-1' } });
const gotBody = JSON.parse(got.result.content[0].text);
out.queueGet = { kind: gotBody.kind, cardId: gotBody.cardId, contentFormat: gotBody.contentFormat.slice(0, 30), system: gotBody.system.slice(0, 20) };

const submitted = await call('tools/call', { name: 'shot_queue_submit', arguments: { id: 'mcptest-1', content: '```ts\nexport function draw(){}\n```\nSUMMARY: test', model: 'audit-mcp-client' } });
out.submit = JSON.parse(submitted.result.content[0].text);
out.resFileWritten = readdirSync(QUEUE).includes('res-mcptest-1.json');

const cardsRead = await call('tools/call', { name: 'shot_cards_read', arguments: {} });
const cardsBody = JSON.parse(cardsRead.result.content[0].text);
out.cardsRead = { cardCount: cardsBody.cardCount ?? 0, ok: Boolean(cardsBody.cards || cardsBody.error) };

const upd = await call('tools/call', { name: 'shot_cards_update_prompt', arguments: { cardId: (cardsBody.cards?.[0]?.id) ?? 'none', prompt: 'MCP 测试改写提示词' } });
out.updatePrompt = upd.result.isError ? { error: JSON.parse(upd.result.content[0].text).error } : { ok: true };

const badId = await call('tools/call', { name: 'shot_queue_get', arguments: { id: '../evil' } });
out.invalidIdRejected = badId.result.isError === true;

proc.kill();
console.log(JSON.stringify(out, null, 2));
