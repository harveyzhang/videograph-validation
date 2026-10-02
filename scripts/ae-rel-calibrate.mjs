// AE-04 相对运动校准：读工程 artifacts 下缓存的节奏采样帧（*.gray，64×36 灰度），计算每小节绝对运动、墨量、相对运动与五分位。
// 用法：node scripts/ae-rel-calibrate.mjs <projectId> [sampleFps=15] [--shots]
//   只认帧数 = 曲长 × sampleFps 的全片采样文件（取最新一个）；--shots 时按镜头汇总，便于判断具体镜头。
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { readProject, projectDir } from '../src/server/project-store.mjs';
import { motionSeries, barGrid, INK_FLOOR } from '../src/server/rhythm.mjs';

const [projectId, fpsArg, flag] = process.argv.slice(2);
if (!projectId) throw new Error('usage: node scripts/ae-rel-calibrate.mjs <projectId> [sampleFps] [--shots]');
const sampleFps = Number(fpsArg ?? 15);
const project = readProject(projectId);
const size = 64 * 36;
const frameCount = Math.floor(project.song.duration * sampleFps - 1e-6) + 1;
const dir = join(projectDir(projectId), 'artifacts');
const candidates = readdirSync(dir).filter((name) => name.endsWith('.gray')).map((name) => ({ name, stat: statSync(join(dir, name)) }))
  .filter(({ stat }) => stat.size === frameCount * size).sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs);
if (!candidates.length) throw new Error(`没有 ${frameCount} 帧的全片采样（先跑 project_rhythm_report sampleFps=${sampleFps}）`);
const bytes = readFileSync(join(dir, candidates[0].name));
const frames = Array.from({ length: frameCount }, (_, i) => bytes.subarray(i * size, (i + 1) * size));
const { motion, ink } = motionSeries(frames);
const times = frames.map((_, i) => i / sampleFps);
const mean = (list) => (list.length ? list.reduce((a, b) => a + b, 0) / list.length : 0);
const pick = (start, end, series) => series.filter((_, i) => times[i] >= start && times[i] < end);
const bars = barGrid(project.song).bars.map((bar) => {
  const m = mean(pick(bar.start, bar.end, motion)), k = mean(pick(bar.start, bar.end, ink));
  return { index: bar.index, start: bar.start, motion: m, ink: k, rel: m / Math.max(k, INK_FLOOR) };
});
const quint = (values) => { const sorted = [...values].sort((a, b) => a - b); return [0.2, 0.4, 0.6, 0.8].map((q) => +sorted[Math.round(q * (sorted.length - 1))].toFixed(4)); };
console.log(JSON.stringify({ projectId, name: project.name, frames: frameCount, file: candidates[0].name.slice(0, 12),
  motionQuintiles: quint(bars.map((b) => b.motion)), inkQuintiles: quint(bars.map((b) => b.ink)), relQuintiles: quint(bars.map((b) => b.rel)) }));
if (flag === '--shots') {
  for (const shot of project.shots) {
    const own = bars.filter((bar) => bar.start >= shot.start - 0.05 && bar.start < shot.end - 0.05);
    console.log(`${shot.id.padEnd(11)} ${shot.start.toFixed(1).padStart(6)}s  motion ${mean(own.map((b) => b.motion)).toFixed(4)}  ink ${mean(own.map((b) => b.ink)).toFixed(4)}  rel ${mean(own.map((b) => b.rel)).toFixed(3)}`);
  }
}
