// _window-template.ts — SONG-03 通用场景模板：新歌工程的场景起点（project_shot_source 对未生成镜头返回本文件）。
// 只依赖窗口歌词（lyrics.linesIn）、拍点与包络；不用 ly.get('原句')，换歌不崩。
// 契约见 engine/docs/ENGINE.md：默认导出 extends Scene 的类，render(f, out) 必须完全覆盖 out。
import type * as THREE from 'three';
import { Scene, type Frame, type PostOverrides } from '../engine/scene';
import { Layer2D, W, H, clearRT } from '../engine/gl';
import { HEX } from '../engine/palette';
import { F, font } from '../engine/type';
import { Lyrics } from '../engine/lyrics';

export default class WindowTemplate extends Scene {
  private ui = new Layer2D();

  render(f: Frame, out: THREE.WebGLRenderTarget): PostOverrides {
    const { renderer, comp, lyrics, start, end } = this.ctx;
    clearRT(renderer, out);
    const L = this.ui; L.clear(HEX.ink); const c = L.ctx;

    // 节拍律动：每拍一次衰减（beatPhase 0→1），下拍（小节起点）更重
    const beatHit = Math.pow(1 - f.beatPhase, 3);
    const barHit = Math.pow(1 - f.barPhase, 4);
    const inset = 80 - 24 * barHit;
    c.strokeStyle = HEX.signal;
    c.globalAlpha = 0.35 + 0.65 * beatHit;
    c.lineWidth = 3 + 6 * f.a.kick;
    c.strokeRect(inset, inset, W - inset * 2, H - inset * 2);
    c.globalAlpha = 1;

    // 窗口歌词：逐词卡拉OK，高亮永不超前人声（wordProgress 是唯一时间来源）
    const line = lyrics.linesIn(start, end).find((entry) => f.t >= entry.start - 0.4 && f.t < entry.end + 0.4);
    if (line) {
      c.font = font(F.archivo(100, 700), 72);
      c.textBaseline = 'middle';
      const gap = 24;
      const widths = line.words.map((word) => c.measureText(word.w).width);
      let x = (W - (widths.reduce((sum, width) => sum + width, 0) + gap * (widths.length - 1))) / 2;
      line.words.forEach((word, index) => {
        const progress = Lyrics.wordProgress(word, f.t);
        c.fillStyle = progress <= 0 ? HEX.graphite : progress < 1 ? HEX.signal : HEX.bone;
        c.fillText(word.w, x, H / 2);
        x += widths[index]! + gap;
      });
    }

    comp.draw(renderer, L.upload(), out);
    return { bloom: 0.2 + 0.4 * beatHit, hud: 0 };
  }

  dispose() { this.ui.texture.dispose(); }
}
