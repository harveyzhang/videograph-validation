import type { ArtifactType } from '../blackboard/store';

export type PdoomTaskId = 'analyze-stems' | 'align-lyrics' | 'analyze-audio' | 'render-stills' | 'render-video';

export interface PdoomTaskSpec {
  id: PdoomTaskId;
  label: string;
  cwd: string;
  command: string;
  args: string[];
  outputs: Array<{ type: ArtifactType; path: string; schema: string }>;
  requires: string[];
  destructive: boolean;
}

/**
 * 这是唯一允许交给本地 Worker 的 P(DOOM) 命令表。
 * LLM/MCP 只能引用 task id，不能提交任意 shell 字符串。
 */
export const pdoomTasks: Record<PdoomTaskId, PdoomTaskSpec> = {
  'analyze-stems': {
    id: 'analyze-stems', label: '分离音频 Stem', cwd: 'pdoom-video/analysis', command: 'uv',
    args: ['run', 'python', '-m', 'demucs', '-n', 'htdemucs_ft', '-o', 'stems', '../audio/pdoom.mp3'],
    outputs: [{ type: 'stems', path: 'analysis/stems/htdemucs_ft/pdoom', schema: 'stems/v1' }], requires: ['uv', 'python', '4GB model cache'], destructive: false,
  },
  'align-lyrics': {
    id: 'align-lyrics', label: '逐词歌词对齐', cwd: 'pdoom-video/analysis', command: 'uv',
    args: ['run', 'python', 'align.py'],
    outputs: [{ type: 'lyrics-aligned', path: 'pdoom-video/data/lyrics.json', schema: 'lyrics/v1' }], requires: ['uv', 'analysis/work intermediates'], destructive: false,
  },
  'analyze-audio': {
    id: 'analyze-audio', label: '分析节拍与音频特征', cwd: 'pdoom-video/analysis', command: 'uv',
    args: ['run', 'python', 'analyze.py'],
    outputs: [{ type: 'audio-analysis', path: 'pdoom-video/data/audio.json', schema: 'audio-analysis/v1' }], requires: ['uv', 'Demucs stems'], destructive: false,
  },
  'render-stills': {
    id: 'render-stills', label: '生成 Plate 静帧', cwd: 'pdoom-video/app', command: 'bun',
    args: ['scripts/render.ts', 'stills', '--samples', '4'],
    outputs: [{ type: 'plate', path: 'pdoom-video/app/public/plates', schema: 'plate/v1' }], requires: ['bun', 'Chrome', 'GPU'], destructive: false,
  },
  'render-video': {
    id: 'render-video', label: '导出完整视频', cwd: 'pdoom-video/app', command: 'bun',
    args: ['scripts/render.ts', 'video', '--samples', 'auto', '--shutter', '0.2', '--out', '../out/pdoom.mp4'],
    outputs: [{ type: 'video', path: 'pdoom-video/out/pdoom.mp4', schema: 'video/v1' }], requires: ['bun', 'Chrome', 'ffmpeg/libx264', 'GPU'], destructive: false,
  },
};

export function getPdoomTask(id: string): PdoomTaskSpec | null {
  return id in pdoomTasks ? pdoomTasks[id as PdoomTaskId] : null;
}

export function taskCommandPreview(id: PdoomTaskId): string {
  const task = pdoomTasks[id];
  return `${task.command} ${task.args.join(' ')}`;
}
