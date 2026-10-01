// audit-all.mjs — 全量浏览器回归：对工程工作台跑 project-view-audit。
// 旧演示视图（单镜头工坊 / P(DOOM) 教学 / 创意工作区 / 旧工作流）已随 CLEANUP-01 移除，
// 对应审计脚本一并删除；完整 MCP+GPU 链路另见 transition-integration-audit.mjs。
// 前提：service(5191) 与 dev(5188) 已运行；可用 VIDEOGRAPH_AUDIT_PROJECT 指定工程 id。
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const serviceUrl = process.env.VIDEOGRAPH_SERVICE_URL ?? 'http://127.0.0.1:5191';
const studioOrigin = process.env.VIDEOGRAPH_STUDIO_ORIGIN ?? 'http://127.0.0.1:5188';

const session = await fetch(`${serviceUrl}/session`, { headers: { origin: studioOrigin } });
if (!session.ok) throw new Error(`无法获取服务令牌（${session.status}）：请先 npm run service`);
const { token } = await session.json();
const listing = await fetch(`${serviceUrl}/projects`, { headers: { authorization: `Bearer ${token}` } });
if (!listing.ok) throw new Error(`工程列表读取失败（${listing.status}）`);
const { projects } = await listing.json();
const projectId = process.env.VIDEOGRAPH_AUDIT_PROJECT ?? projects[0]?.id;
if (!projectId) throw new Error('服务中没有任何工程；先用界面或 MCP 建工程后再跑审计');

console.log(`project-view-audit → ${projectId}`);
const result = spawnSync(process.execPath, ['scripts/project-view-audit.mjs', projectId], { cwd: root, stdio: 'inherit', timeout: 300000 });
if (result.status !== 0) { console.error(`FAILED: project-view-audit exit ${result.status}`); process.exitCode = 1; }
