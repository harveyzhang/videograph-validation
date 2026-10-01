// FB-03 MCP 意见与画面工具：走真实 stdio（MCP server 子进程 + 独立端口服务 + 临时工程目录）。
// 原计划扩展 scripts/mcp-server-test.mjs，但该脚本硬编码旧机器 F:/ 路径与旧工坊队列，本机不可运行；
// 等价验收（inbox → stills(image 内容) → feedbackResponses 提交 → validate → responded/how → 其他镜头不变）在此覆盖。
// 引擎为 helpers.mjs 的 canvas 2D 夹具：验证协议与真实渲染进程路径；真实 pdoom 引擎画面待有参考仓库的机器补验。
import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'node:url';
import { createFixtureProject, fixtureScene } from './helpers.mjs';

const root = fileURLToPath(new URL('../../..', import.meta.url));
const tmp = mkdtempSync(join(tmpdir(), 'videograph-fb03-'));
const projects = join(tmp, 'projects');
const tokenFile = join(tmp, 'service-token');
const port = 5700 + Math.floor(Math.random() * 200);
const base = `http://127.0.0.1:${port}`;
let service, client, projectId;

async function invoke(name, args, expectError = false) {
  const response = await client.callTool({ name, arguments: args });
  const text = response.content.filter((item) => item.type === 'text').map((item) => item.text).join('\n');
  if (expectError) { assert.equal(response.isError, true, text); return text; }
  if (response.isError) throw new Error(text);
  return { value: JSON.parse(text), images: response.content.filter((item) => item.type === 'image') };
}

async function waitJob(jobId, timeout = 120000) {
  const deadline = Date.now() + timeout;
  for (;;) {
    const { value } = await invoke('project_job_get', { projectId, jobId });
    if (['done', 'error', 'cancelled'].includes(value.status)) return value;
    if (Date.now() > deadline) throw new Error(`job ${jobId} 超时：${value.status} ${value.detail ?? ''}`);
    await new Promise((resolve) => setTimeout(resolve, 800));
  }
}

before(async () => {
  mkdirSync(projects, { recursive: true });
  projectId = createFixtureProject(projects);
  service = spawn(process.execPath, ['--no-warnings', 'src/server/index.mjs'], { cwd: root, stdio: 'pipe',
    env: { ...process.env, VIDEOGRAPH_SERVICE_PORT: String(port), VIDEOGRAPH_PROJECTS: projects, VIDEOGRAPH_SERVICE_TOKEN_FILE: tokenFile, VIDEOGRAPH_STUDIO_ORIGINS: `http://127.0.0.1:${port}` } });
  for (let i = 0; i < 100 && !existsSync(tokenFile); i++) await new Promise((resolve) => setTimeout(resolve, 100));
  if (!existsSync(tokenFile)) throw new Error('工程服务未启动');
  client = new Client({ name: 'videograph-fb03-audit', version: '1.0' });
  await client.connect(new StdioClientTransport({ command: process.execPath,
    args: ['--experimental-strip-types', '--no-warnings', 'src/pdoom/mcp-server.ts'], cwd: root,
    // MCP 进程与工程服务共用同一 env 约定：URL/令牌/工程根目录缺一不可（image 内容直接读本地图产物）。
    env: { ...process.env, VIDEOGRAPH_SERVICE_URL: base, VIDEOGRAPH_SERVICE_TOKEN_FILE: tokenFile, VIDEOGRAPH_PROJECTS: projects }, stderr: 'pipe' }));
});
after(async () => {
  await client?.close().catch(() => {});
  service?.kill();
  rmSync(tmp, { recursive: true, force: true });
});

test('工具注册：三个新工具 + 每个描述声明 AI 不能接受意见', async () => {
  const listed = await client.listTools();
  const names = listed.tools.map((tool) => tool.name);
  for (const name of ['project_feedback_inbox', 'project_feedback_ask', 'project_stills']) assert.ok(names.includes(name), `${name} 未注册`);
  for (const name of ['project_feedback_inbox', 'project_feedback_ask', 'project_stills', 'project_shot_submit']) {
    const tool = listed.tools.find((entry) => entry.name === name);
    assert.match(tool.description, /不能接受/, `${name} 描述必须声明 AI 不能接受意见`);
  }
  const submit = listed.tools.find((tool) => tool.name === 'project_shot_submit');
  assert.ok(submit.inputSchema.properties.feedbackResponses, 'submit schema 应含 feedbackResponses');
});

test('验收主线：带锚点意见 → inbox → stills(image) → feedbackResponses 提交 → validate → responded → 其他镜头不变', async () => {
  let project = (await invoke('project_get', { projectId })).value;
  const shotB = project.shots.find((shot) => shot.id === 'b');
  const added = (await invoke('project_feedback_add', { projectId, shotId: 'a', expectedInputRevision: project.shots[0].inputRevision,
    text: '火花再亮一点', anchor: { t: 1.5, lyricElementId: 'el-spark', aspect: 'color' }, preserve: ['歌词时序'] })).value;
  const note = added.shots[0].feedback[0];
  assert.equal(note.anchor.t, 1.5);
  assert.deepEqual(note.preserve, ['歌词时序']);

  const inbox = (await invoke('project_feedback_inbox', {})).value;
  const item = inbox.items.find((entry) => entry.note.id === note.id);
  assert.ok(item, 'inbox 应包含新意见');
  assert.equal(item.targetKind, 'shot');
  assert.equal(item.note.anchor.lyricElementId, 'el-spark');
  assert.match(item.nextStep, /project_shot_submit/);

  const stillsJob = (await invoke('project_stills', { projectId, shotId: 'a', times: [1.5], width: 480 })).value;
  assert.equal(stillsJob.kind, 'stills');
  assert.deepEqual(stillsJob.stills.times, [1.5]);
  const finished = await waitJob(stillsJob.id);
  assert.equal(finished.status, 'done', finished.error);
  const currentFile = finished.result.stills.images[0].file;
  assert.match(currentFile, /^artifacts\/[a-f0-9]{64}\.png$/);
  const bytes = readFileSync(join(projects, projectId, currentFile));
  assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', '产物必须是 PNG');
  assert.equal(bytes.readUInt32BE(16), 480, 'PNG 宽度应为 480');
  const jobAgain = await invoke('project_job_get', { projectId, jobId: stillsJob.id });
  assert.ok(jobAgain.images.length >= 1, 'project_job_get 完成后应以 image 内容返回 stills');
  assert.equal(jobAgain.images[0].mimeType, 'image/png');

  const second = (await invoke('project_feedback_add', { projectId, shotId: 'a', expectedInputRevision: added.shots[0].inputRevision, text: '字再大一点' })).value;
  const note2 = second.shots[0].feedback[1];
  const asked = await invoke('project_feedback_ask', { projectId, targetKind: 'shot', targetId: 'a', feedbackId: note2.id, question: '是指中文字级还是注释文字？' });
  assert.equal(asked.value.shots[0].feedback[1].status, 'needs-clarification');
  const clarifying = (await invoke('project_feedback_inbox', { projectId, status: 'needs-clarification' })).value;
  assert.equal(clarifying.count, 1);

  project = (await invoke('project_get', { projectId })).value;
  const revision = project.shots[0].inputRevision;
  const submitted = (await invoke('project_shot_submit', { projectId, shotId: 'a', expectedInputRevision: revision,
    code: fixtureScene(200), summary: '夹具改写：色调换到 200',
    feedbackResponses: [{ feedbackId: note.id, how: '把火花层色相从 18 调到 200 并提高亮度' }] })).value;
  const responded = submitted.shots[0].feedback[0];
  assert.equal(responded.status, 'responded');
  assert.equal(responded.response.how, '把火花层色相从 18 调到 200 并提高亮度');
  assert.equal(responded.response.outcome, 'addressed');

  // 修改前 vs 当前：同一时间点、同一宽度；提交后再取当前候选，产物应因版本不同而不同。
  const currentAfter = await waitJob((await invoke('project_stills', { projectId, shotId: 'a', times: [1.5], width: 480 })).value.id);
  assert.equal(currentAfter.status, 'done', currentAfter.error);
  const currentAfterFile = currentAfter.result.stills.images[0].file;
  const beforeJob = await waitJob((await invoke('project_stills', { projectId, shotId: 'a', times: [1.5], version: 'before-feedback', width: 480 })).value.id);
  assert.equal(beforeJob.status, 'done', beforeJob.error);
  const beforeFile = beforeJob.result.stills.images[0].file;
  assert.notEqual(beforeFile, currentAfterFile, '版本不同缓存键必须不同');
  assert.notEqual(readFileSync(join(projects, projectId, beforeFile)).toString('hex'), readFileSync(join(projects, projectId, currentAfterFile)).toString('hex'), '修改前与当前候选的画面必须不同');
  assert.notEqual(currentAfterFile, currentFile, '提交后当前画面必须变化');

  const validate = await waitJob((await invoke('project_validate', { projectId, shotId: 'a' })).value.id, 180000);
  assert.equal(validate.status, 'done', validate.error);

  project = (await invoke('project_get', { projectId })).value;
  assert.equal(project.shots[0].status, 'ready');
  assert.ok(project.shots[0].validation?.thumb, '校验后应有缩略图');
  const inboxResponded = (await invoke('project_feedback_inbox', { projectId, status: 'responded' })).value;
  assert.match(inboxResponded.items[0].note.response.how, /色相/);
  assert.match(inboxResponded.items[0].nextStep, /不能接受/);

  const after = project.shots.find((shot) => shot.id === 'b');
  assert.equal(after.module, shotB.module, '其他镜头模块不变');
  assert.equal(after.codeHash, shotB.codeHash, '其他镜头 codeHash 不变');
  assert.equal(after.inputRevision, shotB.inputRevision, '其他镜头输入版本不变');
});

test('stills 入参校验：越界时间与非法宽度被拒绝', async () => {
  const project = (await invoke('project_get', { projectId })).value;
  await invoke('project_stills', { projectId, shotId: 'a', times: [7.5] }, true);
  await invoke('project_stills', { projectId, shotId: 'a', width: 9999 }, true);
  await invoke('project_stills', { projectId, shotId: 'missing' }, true);
  await invoke('project_stills', { projectId, shotId: 'b', version: 'before-feedback' }, true);
});
