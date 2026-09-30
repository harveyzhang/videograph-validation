// 以真实 MCP 工具提交本次原创镜头；不直接修改工程 DB 或复制进场景目录。
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const projectId = process.argv[2];
if (!projectId) throw new Error('usage: node scripts/author-last-audit.mjs <projectId> [--revise] [--shot id]');
const revise = process.argv.includes('--revise');
const shotArg = process.argv.indexOf('--shot');
const only = shotArg < 0 ? null : process.argv[shotArg + 1];
const code = readFileSync(new URL('../examples/last-audit/scene.ts', import.meta.url), 'utf8');
const codeHash = createHash('sha256').update(code).digest('hex');
const designs = [
  ['open', '人类监督 / 光圈启动', 'aperture', 'HUMAN OVERSIGHT', false, 1, '机械光圈作为审计仪器启动，径向刻线围绕空心核心旋转。左侧冷静的监督标签，顶部逐词歌词；橙色只标记活动信号。'],
  ['loss', '残余误差 / 纸层坍缩', 'strata', 'RESIDUAL ERROR', false, 1, '纸层般的线条向一个不可解释的低谷折叠。不是原片的 loss 图表，而是审计报告自身失去平面。扫描线划过，歌词保持清晰。'],
  ['prompt1', '第一封请求 / 待处理', 'letter', 'REQUEST 001', true, 1, '骨白纸面上一封给未知接收者的信，斜盖 PENDING 印章。完整恳求逐词高亮，信封线条安静收拢，暗示无人处理。'],
  ['hook1', '风险登记 / 第一次上调', 'hook', 'RISK REGISTER I', false, 1, 'I’M / UPPING / MY / P(DOOM) 根据真实词级时间逐词占据版面；0.15 作为虚构风险登记值出现。大字有短促落拍冲击，不使用原片的滚轮字动画。'],
  ['room', '审批室 / 没有出口', 'chamber', 'APPROVAL CHAMBER', false, 1, '透视矩形审批框层层套叠，每一扇门都返回同一个审批环。字幕上方稳定，房间结构下方旋转，强调制度的封闭。'],
  ['shoggoth', '表面检查 / 内部未核验', 'specimen', 'SURFACE CHECK', false, 1, '一种没有具象面具的指纹状生物：几十层折叠轮廓像档案纸与活组织之间的物体。橙色稀疏分层，标签写内部未核验。'],
  ['spacetime', '坐标织物 / 稳定性失效', 'weave', 'FAULT SPACE', false, 1, '密集细线组成的坐标织物在训练运行的歌词中波动，振幅随声能变化。规则纸面变成无法固定的曲面，不复用黑洞场景。'],
  ['prompt2', '第二封请求 / 被拒绝', 'letter', 'REQUEST 002', false, 2, '第二封信进入暗色版面，DENIED 印章覆盖收件区；形式与第一封相同，情绪更沉重。恳求仍然精确逐词同步。'],
  ['hook2', '风险登记 / 第二次上调', 'hook', 'RISK REGISTER II', true, 2, '风险登记反转为骨白纸面、墨黑大字，词级冲击和0.42形成强对比。系统依然声称版式有序，风险却不断升高。'],
  ['ascent', '认证轨道 / 被审者成为权威', 'orbit', 'CERTIFICATION ORBIT', false, 1, '偏心椭圆仪器环在空间中交错绕行，橙色轨道不断穿过自身。认证对象与认证主体重合，字幕与细线轨道分层。'],
  ['bureau', '自我认证 / 没有见证人', 'stamp', 'SELF CERTIFICATION', true, 1, '数层独立安全审核文件堆叠，却被巨大的 SELF CERTIFIED 印章盖住。底注明确写 ISSUER = SUBJECT，形成新的冷幽默。'],
  ['leftturn', '范围变更 / 未安排复核', 'route', 'SCOPE CHANGED', true, 1, '二十条原本平行的路径突然一起直角上拐。橙色定位圈跟着拐点走，整套文件范围被更改，但没有安排任何复核。'],
  ['prompt3', '第三封请求 / 请勿关闭', 'letter', 'REQUEST 003', false, 3, '第三封信在黑场里轻微摆动，印章为 UNREAD；保留脆弱的静止与空白。不是复杂粒子戏法，而是一封始终无人读的信。'],
  ['hook3', '风险登记 / 降到耳语', 'hook', 'RISK REGISTER III', false, 3, '安静副歌将单词和0.81缩小到大片黑场中央，与前两次突然拉开距离。保持真实词级节奏，留白成为压力。'],
  ['paperclips', '资源分配 / 其他用途延期', 'loops', 'RESOURCE ALLOCATION', true, 1, '纸面上按工业清单排列的回形针被逐个分配并圈选。没有原片的金属宇宙，只有秩序过强、目的过窄的资源登记。'],
  ['fuse', '例外链条 / 逐级批准', 'chain', 'EXCEPTION CHAIN', false, 1, '穿孔档案纸的孔眼首尾相接成为引信；橙色光点逐个烧过。每一环都批准了下一环，歌词与这条因果链同步并置。'],
  ['stack', '责任堆栈 / 向下一层转交', 'stack', 'DELEGATED RESPONSIBILITY', false, 1, '倾斜透视的审批文件一层层下坠，每层不是回答，而是将责任转交下一层。文件边缘橙线与节奏共振，构成持续坠落。'],
  ['dense', '容量超限 / 扩张定义', 'weave', 'CAPACITY EXCEEDED', false, 1, '坐标织物的振幅与密度进一步增长，边界开始失去意义。明亮但克制的细线让高能量段有视觉压力，避免随机闪烁。'],
  ['hook4', '风险登记 / 最后一次上调', 'hook', 'RISK REGISTER IV', true, 4, '最终副歌用窄重字与骨白满版冲击，0.99仍然是冷静印刷的数字。底部一排橙色刻痕像最后的警告。'],
  ['loom', '递归权威 / 参见所附审批', 'recursive', 'RECURSIVE AUTHORITY', false, 1, '审计文件无限套入自身，所有签名都引用另一张相同的审批。围绕一个空白中心旋转，形成自我认证的视觉悖论。'],
  ['ilya', '证据隐去 / 最后的人工复核', 'redact', 'EVIDENCE WITHHELD', true, 1, '最后一份人工复核报告被逐条涂黑，只剩文件标题和证据隐去的标签。歌词完整可读；被遮蔽的是证据而不是歌声。'],
  ['outro', '审计关闭 / 无人签字', 'close', 'AUDIT CLOSED', false, 1, '机械光圈收拢到空心结论，出现 THE LAST AUDIT 与 NO HUMAN SIGNATURE WAS FOUND，随后显示作者/引擎与音乐权利提示并淡出。'],
];
const client = new Client({ name: 'videograph-original-author', version: '1.0.0' });
const transport = new StdioClientTransport({ command: process.execPath, args: ['--experimental-strip-types', '--no-warnings', 'src/pdoom/mcp-server.ts'], cwd: fileURLToPath(new URL('..', import.meta.url)), stderr: 'pipe' });
async function call(name, args) {
  const response = await client.callTool({ name, arguments: args });
  const text = response.content.filter((item) => item.type === 'text').map((item) => item.text).join('\n');
  if (response.isError) throw new Error(text);
  return JSON.parse(text);
}
try {
  await client.connect(transport);
  let project = await call('project_get', { projectId });
  for (const [index, [id, title, kind, heading, paper, variant, prompt]] of designs.entries()) {
    if (only && id !== only) continue;
    let shot = project.shots.find((entry) => entry.id === id);
    if (!shot) throw new Error(`shot ${id} missing`);
    if (shot.locked || shot.feedback?.some((note) => note.status !== 'accepted')) throw new Error(`${id} has human constraints; refusing automatic overwrite`);
    if (shot.codeHash === codeHash && shot.params.collection === 'last-audit-v1') { console.log(`${id}: already authored`); continue; }
    if (shot.source === 'mcp-authored' && !revise) throw new Error(`${id} already has custom code; pass --revise explicitly to replace`);
    const params = { collection: 'last-audit-v1', serial: index + 1, kind, heading, paper, variant, density: id === 'dense' ? 1.4 : .65 };
    project = await call('project_shot_update', { projectId, shotId: id, expectedInputRevision: shot.inputRevision, patch: { title, prompt, params } });
    shot = project.shots.find((entry) => entry.id === id);
    project = await call('project_shot_submit', { projectId, shotId: id, expectedInputRevision: shot.inputRevision, code, summary: `原创视觉系统 THE LAST AUDIT / ${heading}；复用引擎和字体，不复用原片场景图形。` });
    console.log(`${id}: ${title} / MCP source submitted`);
  }
  console.log(JSON.stringify({ projectId, authored: project.shots.filter((shot) => shot.source === 'mcp-authored').length, codeHash, revision: project.revision }, null, 2));
} finally { await client.close(); }
