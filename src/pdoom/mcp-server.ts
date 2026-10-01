import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { projectToolDefinitions, callProjectTool } from '../server/mcp-tools.ts';

// CLEANUP-01：旧演示视图（单镜头工坊队列 / P(DOOM) 参考任务 / 歌词研究草稿）的
// shot_queue_*、shot_cards_*、pdoom_*、lyric_research_draft 工具已移除；
// 本 server 现在只暴露真实工作台的 project_* 工具（定义见 ../server/mcp-tools.ts）。

const server = new Server(
  { name: 'videograph-pdoom', version: '0.2.0' },
  { capabilities: { tools: {} } },
);

function textResult(value: unknown, isError = false) {
  return { content: [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }], ...(isError ? { isError: true } : {}) };
}

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [...projectToolDefinitions],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const name = request.params.name;
  if (projectToolDefinitions.some((tool) => tool.name === name)) {
    try { return textResult(await callProjectTool(name, request.params.arguments ?? {})); }
    catch (error) { return textResult({ error: String(error), hint: '工程服务需要运行：npm run service' }, true); }
  }
  return textResult({ error: `Unknown tool: ${name}` }, true);
});

await server.connect(new StdioServerTransport());
