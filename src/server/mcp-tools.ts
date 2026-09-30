// mcp-tools.ts — MCP 只作为本地工程服务的入口，不直接写数据库/工程文件。
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const properties = { projectId: { type: 'string' }, shotId: { type: 'string' }, transitionId: { type: 'string' }, expectedInputRevision: { type: 'integer', minimum: 0 } };
const schema = (extra: Record<string, unknown>, required: string[]) => ({ type: 'object', properties: { ...properties, ...extra }, required });
export const projectToolDefinitions = [
  { name: 'project_list', description: '列出本地可恢复的视频工程。', inputSchema: schema({}, []) },
  { name: 'project_create_from_bgm', description: '只提供本地 BGM 路径创建独立可复现工程。目前仅指纹匹配 pdoom-video 原始 BGM：复用已对齐分析与引擎源码，明确标记参考导入，不冒充新分析或原创生成。', inputSchema: schema({ audioPath: { type: 'string' }, name: { type: 'string' } }, ['audioPath']) },
  { name: 'project_get', description: '读取工程、镜头版本与状态、BGM 分析来源；可选返回歌词/节拍分析。', inputSchema: schema({ includeAnalysis: { type: 'boolean' } }, ['projectId']) },
  { name: 'project_shot_lyrics', description: '读取目标镜头窗口内真实词级歌词与已有元素方案。先从歌词分析含义和具象/动作/隐喻元素，再用 project_shot_update 的 lyricPlan 保存引用、解释、视觉处理；引用会被校验。', inputSchema: schema({}, ['projectId', 'shotId']) },
  { name: 'project_shot_source', description: '读取某镜头当前真实 TypeScript 源码及完整原引擎契约（Scene 类、Three.js/GLSL/字体/后期）。修改时保留输入版本并通过 project_shot_submit 提交完整文件。', inputSchema: schema({}, ['projectId', 'shotId']) },
  { name: 'project_shot_update', description: '以版本检查修改镜头提示词、参数或锁定状态。提示词修改后必须重新提交代码；锁定镜头必须先解锁。', inputSchema: schema({ patch: { type: 'object', properties: { title: { type: 'string' }, prompt: { type: 'string' }, params: { type: 'object' }, lyricPlan: { type: 'object', properties: { summary: { type: 'string' }, elements: { type: 'array', items: { type: 'object', properties: { name: { type: 'string' }, quote: { type: 'string' }, meaning: { type: 'string' }, treatment: { type: 'string' }, kind: { type: 'string', enum: ['entity', 'action', 'metaphor'] }, cueWord: { type: 'string' } }, required: ['name', 'quote', 'meaning', 'treatment'] } } }, required: ['summary', 'elements'] }, locked: { type: 'boolean' } }, additionalProperties: false } }, ['projectId', 'shotId', 'expectedInputRevision', 'patch']) },
  { name: 'project_shot_submit', description: '提交完整镜头 TypeScript 源码（不带 markdown 代码围栏）；保存不可变新文件并标记待验证。不会覆盖其他镜头或原参考仓库。', inputSchema: schema({ code: { type: 'string' }, summary: { type: 'string' }, addressedFeedbackIds: { type: 'array', items: { type: 'string' }, description: '本次源码明确响应的 pending 反馈 ID；仅标为已响应，必须由用户在界面确认采用。' } }, ['projectId', 'shotId', 'expectedInputRevision', 'code']) },
  { name: 'project_feedback_add', description: '把人的针对性修改意见添加为目标镜头的独立反馈节点。保留原始 prompt 和修改前版本；只有本镜头待改写，其他镜头不受影响。', inputSchema: schema({ text: { type: 'string' } }, ['projectId', 'shotId', 'expectedInputRevision', 'text']) },
  { name: 'project_transition_get', description: '读取相邻镜头之间的转场节点、指导意见、效果配置、前后镜头元素方案和准确时间窗。', inputSchema: schema({}, ['projectId', 'transitionId']) },
  { name: 'project_transition_update', description: '编辑转场指导或锁定。新的指导标为待配置，不假装效果已改变。', inputSchema: schema({ patch: { type: 'object', properties: { intent: { type: 'string' }, locked: { type: 'boolean' } }, additionalProperties: false } }, ['projectId', 'transitionId', 'expectedInputRevision', 'patch']) },
  { name: 'project_transition_configure', description: '提交转场效果参数：cut/dissolve/wipe/dip、秒数、easing(linear/smooth)、direction(left/right)。过渡在切点后发生，保持全曲时长与歌词时序；新配置需预览验证。', inputSchema: schema({ config: { type: 'object', properties: { mode: { type: 'string', enum: ['cut', 'dissolve', 'wipe', 'dip'] }, duration: { type: 'number', minimum: 0, maximum: 1.5 }, easing: { type: 'string', enum: ['linear', 'smooth'] }, direction: { type: 'string', enum: ['left', 'right'] } }, additionalProperties: false }, addressedFeedbackIds: { type: 'array', items: { type: 'string' } } }, ['projectId', 'transitionId', 'expectedInputRevision', 'config']) },
  { name: 'project_transition_feedback_add', description: '添加只针对该转场的人工修改意见，保留之前配置和前后镜头版本；需要明确响应并由人在界面采用。', inputSchema: schema({ text: { type: 'string' } }, ['projectId', 'transitionId', 'expectedInputRevision', 'text']) },
  { name: 'project_transition_validate', description: '后台抽检转场前、切点、混合中和结束后的五帧；结果绑定转场及两侧镜头版本，不代替审美确认。', inputSchema: schema({}, ['projectId', 'transitionId']) },
  { name: 'project_preview', description: '打开指定工程冻结版本的本机真实引擎预览，返回 URL。可指定 shotId 与 before-feedback 查看修改前版本；供人和 agent 视觉检查，不代表自动认可。', inputSchema: schema({ version: { type: 'string', enum: ['current', 'before-feedback'] } }, ['projectId']) },
  { name: 'project_validate', description: '后台验证指定真实镜头：加载引擎、编译并抽检 5 个时间点，保存静帧与诊断；返回 jobId，通过 project_job_get 查询，不代表逐帧/审美通过。', inputSchema: schema({}, ['projectId', 'shotId']) },
  { name: 'project_render', description: '后台导出完整 PV MP4：冻结版本，按镜头逐帧渲染、复用内容缓存、封装完整 BGM。返回任务，不阻塞 MCP 会话。', inputSchema: schema({ fps: { type: 'integer', enum: [24, 30, 60] }, samples: { type: 'integer', enum: [1, 4, 12] } }, ['projectId']) },
  { name: 'project_job_get', description: '查询后台验证/导出任务进度、错误、缓存命中与产物地址；省略 jobId 列出工程最近任务。', inputSchema: schema({ jobId: { type: 'string' } }, ['projectId']) },
  { name: 'project_job_cancel', description: '取消指定排队或正在执行的后台渲染任务。已经完成的产物保留。', inputSchema: schema({ jobId: { type: 'string' } }, ['projectId', 'jobId']) },
];

export async function callProjectTool(name: string, args: Record<string, unknown>) {
  const base = process.env.VIDEOGRAPH_SERVICE_URL ?? 'http://127.0.0.1:5191';
  const parsed = new URL(base);
  if (parsed.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(parsed.hostname)) throw new Error('工程服务必须是本机 HTTP 地址');
  const id = typeof args.projectId === 'string' ? encodeURIComponent(args.projectId) : '';
  const shotId = typeof args.shotId === 'string' ? encodeURIComponent(args.shotId) : '';
  const transitionId = typeof args.transitionId === 'string' ? encodeURIComponent(args.transitionId) : '';
  let path = `/projects/${id}`;
  let body: unknown;
  if (name === 'project_list') path = '/projects';
  else if (name === 'project_create_from_bgm') { path = '/projects'; body = { audioPath: args.audioPath, name: args.name }; }
  else if (name === 'project_shot_lyrics') path += `/shots/${shotId}/lyrics`;
  else if (name === 'project_shot_source') path += `/shots/${shotId}/source`;
  else if (name === 'project_shot_update') { path += `/shots/${shotId}`; body = { expectedInputRevision: args.expectedInputRevision, patch: args.patch }; }
  else if (name === 'project_shot_submit') { path += `/shots/${shotId}/source`; body = { expectedInputRevision: args.expectedInputRevision, code: args.code, summary: args.summary, addressedFeedbackIds: args.addressedFeedbackIds, author: 'mcp' }; }
  else if (name === 'project_feedback_add') { path += `/shots/${shotId}/feedback`; body = { expectedInputRevision: args.expectedInputRevision, text: args.text }; }
  else if (name === 'project_transition_get') path += `/transitions/${transitionId}`;
  else if (name === 'project_transition_update') { path += `/transitions/${transitionId}`; body = { expectedInputRevision: args.expectedInputRevision, patch: args.patch }; }
  else if (name === 'project_transition_configure') { path += `/transitions/${transitionId}/config`; body = { expectedInputRevision: args.expectedInputRevision, config: args.config, addressedFeedbackIds: args.addressedFeedbackIds, author: 'mcp' }; }
  else if (name === 'project_transition_feedback_add') { path += `/transitions/${transitionId}/feedback`; body = { expectedInputRevision: args.expectedInputRevision, text: args.text }; }
  else if (name === 'project_transition_validate') { path += `/transitions/${transitionId}/validate`; body = {}; }
  else if (name === 'project_preview') { path += '/preview'; body = { shotId: args.shotId, transitionId: args.transitionId, version: args.version }; }
  else if (name === 'project_validate') { path += '/validate'; body = { shotId: args.shotId }; }
  else if (name === 'project_render') { path += '/render'; body = { fps: args.fps, samples: args.samples }; }
  else if (name === 'project_job_get') path += `/jobs${args.jobId ? '/' + encodeURIComponent(String(args.jobId)) : ''}`;
  else if (name === 'project_job_cancel') { path += `/jobs/${encodeURIComponent(String(args.jobId))}/cancel`; body = {}; }
  const token = readFileSync(fileURLToPath(new URL('../../.cache/service-token', import.meta.url)), 'utf8');
  const response = await fetch(base.replace(/\/$/, '') + path, { method: body === undefined ? 'GET' : 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` }, ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(120000) });
  const result = await response.json() as Record<string, unknown>;
  if (!response.ok) throw new Error(String(result.error ?? `HTTP ${response.status}`));
  if (result.song && !args.includeAnalysis) {
    const song = result.song as Record<string, unknown>;
    result.song = { song: song.song, bpm: song.bpm, duration: song.duration, sections: song.sections, note: 'includeAnalysis=true 可读取完整分析' };
  }
  return result;
}
