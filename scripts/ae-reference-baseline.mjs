// AE-04 基准：对 pdoom 参考复现工程（公认的好作品）跑 LLM-AE 工具，产出节奏指标基准与图片。
// 用法：先起独立服务实例，再 node scripts/ae-reference-baseline.mjs [projectId]
//   VIDEOGRAPH_SERVICE_URL / VIDEOGRAPH_SERVICE_TOKEN_FILE 指向该实例；不给 projectId 时从参考 BGM 导入一个新工程。
// 输出：.cache/ae-baseline/{cue-sheet.txt, rhythm-*.txt, *.png, metrics.json}
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const out = join(root, '.cache/ae-baseline');
mkdirSync(out, { recursive: true });
const client = new Client({ name: 'videograph-ae-baseline', version: '1.0' });
await client.connect(new StdioClientTransport({ command: process.execPath, args: ['--experimental-strip-types', '--no-warnings', 'src/pdoom/mcp-server.ts'], cwd: root, env: process.env, stderr: 'inherit' }));
async function call(name, args) {
  const response = await client.callTool({ name, arguments: args });
  const texts = response.content.filter((item) => item.type === 'text').map((item) => item.text);
  if (response.isError) throw new Error(`${name}: ${texts.join('\n')}`);
  return { value: JSON.parse(texts[0]), text: texts[1] ?? null, images: response.content.filter((item) => item.type === 'image') };
}
async function finish(result, label) {
  let { value } = result;
  while (!['done', 'error', 'cancelled'].includes(value.status)) {
    ({ value } = await call('project_job_get', { projectId, jobId: value.id, waitSeconds: 45 }));
    console.log(`  ${label}: ${value.status} ${value.detail ?? ''}`);
  }
  if (value.status !== 'done') throw new Error(`${label}: ${value.status} ${value.error ?? ''}`);
  return call('project_job_get', { projectId, jobId: value.id });
}
const save = (name, images) => images.forEach((image, i) => writeFileSync(join(out, `${name}${i ? '-' + i : ''}.png`), Buffer.from(image.data, 'base64')));

let projectId = process.argv[2];
if (!projectId) {
  const { value } = await call('project_create_from_audio', { audioPath: resolve(root, '../pdoom-video/audio/pdoom.mp3'), name: 'AE 基准 · P(doom) 参考复现' });
  projectId = value.id;
  console.log('imported reference project', projectId);
}
const metrics = {};
const cue = await call('song_cue_sheet', { projectId });
writeFileSync(join(out, 'cue-sheet.txt'), cue.text);
console.log('cue sheet', cue.value.bars, 'bars');

const contact = await finish(await call('project_contact_sheet', { projectId, waitSeconds: 45 }), 'contact-sheet');
save('contact-sheet', contact.images);

const project = (await call('project_get', { projectId, includeAnalysis: true })).value;
const chorus = project.song.sections.find((section) => section.name.startsWith('chorus'));
const strip = await finish(await call('project_filmstrip', { projectId, around: project.song.downbeats.find((t) => t >= chorus.start - 0.01), frames: 5, waitSeconds: 45 }), 'filmstrip');
save('filmstrip-chorus1-entry', strip.images);

for (const [label, args] of [['shot-01', { shotId: project.shots[0].id }], ['chorus1', { start: chorus.start, end: chorus.end, sampleFps: 30 }], ['whole', { sampleFps: 15 }]]) {
  const started = Date.now();
  const report = await finish(await call('project_rhythm_report', { projectId, ...args, waitSeconds: 45 }), `rhythm ${label}`);
  writeFileSync(join(out, `rhythm-${label}.txt`), report.text);
  save(`rhythm-${label}`, report.images);
  metrics[label] = { seconds: Math.round((Date.now() - started) / 1000), ...report.value.result.metrics };
  console.log(`rhythm ${label}: ${Math.round((Date.now() - started) / 1000)}s`);
}
writeFileSync(join(out, 'metrics.json'), JSON.stringify({ projectId, metrics }, null, 2));
console.log(JSON.stringify({ projectId, out }));
await client.close();
