// AnalysisCorrector — SONG-02 分析校正界面：波形/拍网格、BPM 微调、段落改名、逐词时间校正、歌词确认。
// 自包含组件（Canvas 自绘 + 内联样式），通过回调把修正写入 overrides；节点画布接线由集成者完成。
// 无障碍：词时间可用键盘微调（选中词后方向键 ±10ms，Shift ±1 帧）。
import { useCallback, useEffect, useRef, useState } from 'react';
import { CheckCircle2, Pencil, RefreshCw, Undo2 } from 'lucide-react';
import type { AnalysisOverride, AnalysisView } from './types';

const PANEL: React.CSSProperties = { display: 'flex', flexDirection: 'column', gap: 10, color: '#EEE9DF', background: '#1b1b1b', border: '1px solid #353535', borderRadius: 8, padding: 12 };
const ROW: React.CSSProperties = { display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' };
const INPUT: React.CSSProperties = { background: '#1e1e1e', color: '#EEE9DF', border: '1px solid #353535', borderRadius: 4, padding: '3px 7px', fontSize: 13 };
const BTN: React.CSSProperties = { ...INPUT, cursor: 'pointer' };
const LABEL: React.CSSProperties = { fontSize: 12, color: '#9C978F' };

const MS = 0.001;
const FRAME_30 = 1 / 30;

export interface AnalysisCorrectorProps {
  analysis: AnalysisView;
  onOverride: (override: AnalysisOverride) => void;
  onUndo: () => void;
  onConfirmLyrics: () => void;
  seekAudio?: (t: number) => void;
}

/** 波形条 + 拍网格 + 段落带的 Canvas 顶栏；下方是逐词时间编辑器。 */
export function AnalysisCorrector({ analysis, onOverride, onUndo, onConfirmLyrics, seekAudio }: AnalysisCorrectorProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [selectedWord, setSelectedWord] = useState<{ line: number; word: number } | null>(null);
  const [instrumentalNote, setInstrumentalNote] = useState('');

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const width = canvas.width, height = canvas.height;
    const duration = analysis.duration;
    ctx.fillStyle = '#151517';
    ctx.fillRect(0, 0, width, height);
    const rms = analysis.envelopes.rms;
    const fps = analysis.envelopes.frameRate;
    ctx.strokeStyle = '#5E5B57';
    ctx.beginPath();
    for (let x = 0; x < width; x++) {
      const t = (x / width) * duration;
      const value = rms[Math.min(rms.length - 1, Math.round(t * fps))] ?? 0;
      const y = height * 0.72 - value * height * 0.55;
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.strokeStyle = 'rgba(255, 77, 18, 0.55)';
    for (const beat of analysis.beats) {
      const x = Math.round((beat / duration) * width);
      ctx.moveTo(x, height * 0.2);
      ctx.lineTo(x, height * 0.8);
    }
    ctx.stroke();
    ctx.strokeStyle = '#FF4D12';
    for (const downbeat of analysis.downbeats) {
      const x = Math.round((downbeat / duration) * width);
      ctx.moveTo(x, height * 0.14);
      ctx.lineTo(x, height * 0.86);
    }
    ctx.stroke();
    const sectionColors = ['rgba(238, 233, 223, 0.14)', 'rgba(255, 138, 61, 0.14)'];
    analysis.sections.forEach((section, index) => {
      ctx.fillStyle = sectionColors[index % 2]!;
      const x0 = (section.start / duration) * width;
      const x1 = (section.end / duration) * width;
      ctx.fillRect(x0, 0, x1 - x0, height);
      ctx.fillStyle = '#9C978F';
      ctx.font = '11px Arial';
      ctx.fillText(section.name, x0 + 3, 12, Math.max(20, x1 - x0 - 6));
    });
  }, [analysis]);

  const patchWord = useCallback((delta: number) => {
    if (!selectedWord) return;
    const line = analysis.lyrics?.lines[selectedWord.line];
    if (!line) return;
    const word = line.words[selectedWord.word];
    if (!word) return;
    onOverride({
      layer: 'lyrics',
      scope: { line: selectedWord.line, word: selectedWord.word },
      patch: { start: Math.max(0, word.start + delta) },
      note: `词「${word.w}」起点 ${delta >= 0 ? '+' : ''}${(delta * 1000).toFixed(0)}ms`,
    });
  }, [analysis, selectedWord, onOverride]);

  return <section style={PANEL} aria-label="分析校正">
    <div style={ROW}>
      <strong>分析校正</strong>
      <span style={LABEL}>rev {analysis.revision} · {analysis.beats.length} 拍 · {analysis.sections.length} 段 · 来源 {analysis.provenance.rhythm?.tool ?? '未知'}</span>
      <button style={BTN} onClick={onUndo} disabled={analysis.overrides.length === 0} title="撤销最近一次修正"><Undo2 size={13} />撤销</button>
    </div>
    <canvas ref={canvasRef} width={960} height={120} style={{ width: '100%', border: '1px solid #353535', borderRadius: 4 }} role="img" aria-label="波形与拍网格" />
    <div style={ROW}>
      <label><span style={LABEL}>BPM</span>
        <input style={{ ...INPUT, width: 80 }} type="number" step="0.01" value={analysis.bpm ?? ''}
          onChange={(event) => onOverride({ layer: 'rhythm', patch: { bpm: Number(event.target.value) }, note: 'BPM 微调' })} /></label>
      <button style={BTN} onClick={() => onOverride({ layer: 'rhythm', patch: { bpmShift: -0.01 }, note: 'BPM −0.01' })} title="BPM 微降">−</button>
      <button style={BTN} onClick={() => onOverride({ layer: 'rhythm', patch: { bpmShift: 0.01 }, note: 'BPM +0.01' })} title="BPM 微升">+</button>
      <label><span style={LABEL}>全局偏移 s</span>
        <input style={{ ...INPUT, width: 80 }} type="number" step="0.005" value={analysis.overrides.filter((entry) => entry.layer === 'rhythm' && entry.patch.offset !== undefined).slice(-1)[0]?.patch.offset as number ?? 0}
          onChange={(event) => onOverride({ layer: 'rhythm', patch: { offset: Number(event.target.value) }, note: '全局时间偏移' })} /></label>
    </div>
    <div style={ROW}>
      <strong style={{ fontSize: 13 }}>段落</strong>
      {analysis.sections.map((section, index) => <label key={index}>
        <span style={LABEL}>#{index + 1} {section.start.toFixed(1)}–{section.end.toFixed(1)}s</span>
        <input style={{ ...INPUT, width: 110 }} value={section.name}
          onChange={(event) => onOverride({ layer: 'sections', scope: { section: index }, patch: { name: event.target.value }, note: '段落重命名' })} />
      </label>)}
    </div>
    {analysis.lyrics ? <>
      <div style={ROW}>
        <strong style={{ fontSize: 13 }}>歌词（{analysis.lyrics.textSource}）</strong>
        <span style={{ ...LABEL, color: analysis.lyrics.humanConfirmed ? '#8FE388' : '#FF8A3D' }}>
          {analysis.lyrics.humanConfirmed ? '已由人确认' : '待人确认——确认后才能用于镜头规划'}
        </span>
        {!analysis.lyrics.humanConfirmed && <button style={{ ...BTN, borderColor: '#FF4D12', color: '#FF4D12' }} onClick={onConfirmLyrics}><CheckCircle2 size={13} />我确认这些歌词</button>}
        <span style={LABEL}>选中词后：方向键 ±10ms，Shift+方向键 ±1 帧（30fps）</span>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4, maxHeight: 260, overflow: 'auto' }}>
        {analysis.lyrics.lines.map((line, lineIndex) => <div key={lineIndex} style={ROW}>
          <span style={{ ...LABEL, width: 46 }}>{line.start.toFixed(2)}s</span>
          {line.words.map((word, wordIndex) => {
            const isSelected = selectedWord?.line === lineIndex && selectedWord?.word === wordIndex;
            const lowConf = (word.conf ?? 1) < 0.5;
            return <button key={wordIndex} style={{
              ...BTN, borderColor: isSelected ? '#FF4D12' : lowConf ? '#C21D0B' : '#353535',
              color: lowConf ? '#FF8A3D' : '#EEE9DF',
            }} onClick={() => { setSelectedWord({ line: lineIndex, word: wordIndex }); seekAudio?.(word.start); }}
              onKeyDown={(event) => {
                if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
                  event.preventDefault();
                  const step = event.shiftKey ? FRAME_30 : 10 * MS;
                  patchWord(event.key === 'ArrowLeft' ? -step : step);
                }
              }}
              title={`${word.start.toFixed(3)}–${word.end.toFixed(3)}s${word.conf !== undefined ? ` · conf ${word.conf.toFixed(2)}` : ''}`}>
              {word.w}
            </button>;
          })}
        </div>)}
      </div>
    </> : <div style={ROW}><Pencil size={13} /><span style={LABEL}>器乐工程：没有歌词层，不伪造歌词。{instrumentalNote}</span>
      <button style={BTN} onClick={() => setInstrumentalNote('如需歌词，请在导入时提供文本或 LRC；ASR 草稿也要经人确认。')}><RefreshCw size={12} />说明</button></div>}
  </section>;
}
