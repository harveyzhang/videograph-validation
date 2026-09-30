// 通过真实 MCP stdio 协议调用工程工具；不是直接绕过 MCP 调内部函数。
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const [name, raw = '{}', output] = process.argv.slice(2);
if (!name) throw new Error('usage: node scripts/project-mcp.mjs tool-name JSON-or-@file [new-output-file]');
const args = JSON.parse(raw.startsWith('@') ? readFileSync(raw.slice(1), 'utf8') : raw);
const client = new Client({ name: 'videograph-local-operator', version: '1.0.0' });
const transport = new StdioClientTransport({ command: process.execPath, args: ['--experimental-strip-types', '--no-warnings', 'src/pdoom/mcp-server.ts'], cwd: fileURLToPath(new URL('..', import.meta.url)), stderr: 'pipe' });
try {
  await client.connect(transport);
  const response = await client.callTool({ name, arguments: args });
  const text = response.content.filter((entry) => entry.type === 'text').map((entry) => entry.text).join('\n');
  if (output) writeFileSync(output, text, { flag: 'wx' });
  console.log(text);
  if (response.isError) process.exitCode = 1;
} finally { await client.close(); }
