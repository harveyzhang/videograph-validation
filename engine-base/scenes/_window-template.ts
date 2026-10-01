// _window-template.ts — SONG-03 通用场景模板：新歌工程的场景起点。
// 只依赖窗口歌词（lyrics.linesIn）、拍点事件与包络；不用 ly.get('原句')，换歌不崩。
// 契约与 engine/docs/ENGINE.md 一致：默认导出 extends Scene 的类，render(f, out) 完全覆盖 out。
import type { Frame } from '../engine/type';
import { Scene, type PostOverrides } from '../engine/scene';

export default class WindowTemplate extends Scene {
  override render(f: Frame, out: import('three').WebGLRenderTarget | null): PostOverrides {
    const g = this.begin2D(f);
    const W = g.canvas.width, H = g.canvas.height;
    g.clearRect(0, 0, W, H);
    g.fillStyle = '#0A0A0B';
    g.fillRect(0, 0, W, H);

    // 节拍律动：大变化落在 downbeat/kick 上（pulse 衰减由事件数组驱动）
    const kick = f.audio.pulse(f.t, f.audio.kickEvents, 0.12);

    // 窗口歌词：逐词卡拉OK，高亮永不超前人声（wordProgress 是唯一时间来源）
    const lines = f.lyrics.linesIn(f.window.start, f.window.end);
    g.textAlign = 'center';
    g.font = `600 ${Math.round(H * 0.06)}px Archivo`;
    const lineHeight = H * 0.1;
    lines.forEach((line, index) => {
      const y = H * 0.5 + (index - (lines.length - 1) / 2) * lineHeight;
      let x = W / 2 - (line.endX ?? 0) / 2; // linesIn 提供排版辅助；此处按默认居中处理
      for (const word of line.words) {
        const progress = word.progress(f.t); // 0..1，wordProgress 的窗口化封装
        g.fillStyle = progress > 0 && progress < 1 ? '#FF4D12' : '#EEE9DF';
        g.globalAlpha = progress === 0 ? 0.3 : 1;
        g.fillText(word.text, x, y);
        x += (g.measureText(word.text).width ?? 0) + H * 0.02;
      }
    });
    g.globalAlpha = 1;

    // 拍点冲击示例：kick 时的一次呼吸缩放
    g.strokeStyle = '#FF8A3D';
    g.lineWidth = Math.max(1.5, H * 0.004);
    g.shadowColor = '#FF4D12';
    g.shadowBlur = 14 * kick;
    g.strokeRect(W * 0.08, H * 0.08, W * 0.84, H * 0.84);
    g.shadowBlur = 0;

    return this.end2D(f, g, out, { bloom: 0.2 + kick * 0.3 });
  }
}
