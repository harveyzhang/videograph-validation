// SONG-02 校正界面的视图契约：与 videograph-analysis/v2（src/song/contract.mjs）对齐的只读视图 + 修正指令。
// UI 不直接改分析数据：所有修改以 override 发出，由服务端写入 overrides 层（记录作者与时间）。

export interface AnalysisView {
  revision: number;
  duration: number;
  bpm: number | null;
  beats: number[];
  downbeats: number[];
  sections: Array<{ start: number; end: number; name: string; label: string; confidence?: number }>;
  envelopes: { frameRate: number; rms: number[] };
  lyrics?: {
    language: string;
    textSource: 'user' | 'lrc' | 'asr';
    humanConfirmed: boolean;
    lines: Array<{ text: string; start: number; end: number; words: Array<{ w: string; start: number; end: number; conf?: number }> }>;
  };
  overrides: AnalysisOverride[];
  provenance: Record<string, { tool: string; version: string; confidence: number; model?: string }>;
}

export interface AnalysisOverride {
  layer: 'rhythm' | 'sections' | 'lyrics' | 'envelopes' | 'onsets' | 'audio' | 'other';
  /** 目标定位：段落序号、词坐标等；rhythm 层可省略。 */
  scope?: { section?: number; line?: number; word?: number; onset?: string };
  patch: Record<string, unknown>;
  note: string;
  author?: 'human' | 'mcp';
  at?: number;
}
