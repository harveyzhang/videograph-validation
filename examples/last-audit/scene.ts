// THE LAST AUDIT — original VideoGraph scene system, 2026-09-30.
// Reuses the MIT-licensed pdoom rendering/font infrastructure, not its scene drawings.
import { Scene, type Frame } from '../engine/scene';
import type { WebGLRenderTarget } from 'three';
import { FSPass, Layer2D, W, H } from '../engine/gl';
import { Lyrics, type Line } from '../engine/lyrics';
import { F, font } from '../engine/type';

const INK = '#0A0A0B', BONE = '#EEE9DF', SIGNAL = '#FF4D12';
const TAU = Math.PI * 2;
const clamp = (x: number) => Math.max(0, Math.min(1, x));
const smooth = (x: number) => { x = clamp(x); return x * x * (3 - 2 * x); };
const hash = (i: number) => { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };

type C = CanvasRenderingContext2D;
export default class LastAudit extends Scene {
  layer = new Layer2D();
  lines: Line[] = [];
  bg = new FSPass(`
    uniform float t, energy;
    void main() {
      vec2 p = (vUv - .5) * vec2(1.77778, 1.);
      float curve = sin(p.x * 7. + .22 * t) * .018;
      float rule = abs(fract((p.y + curve) * 58.) - .5);
      float line = 1. - smoothstep(.018, .065, rule);
      float vignette = exp(-dot(p, p) * 2.);
      vec3 col = vec3(.0028, .0030, .0033) + vec3(.006) * line * vignette;
      col += vec3(.019, .0035, .001) * exp(-length(p - vec2(.3 * sin(t * .1), -.1)) * 6.) * (.5 + energy);
      fragColor = vec4(col, 1.);
    }`, { t: { value: 0 }, energy: { value: 0 } });

  init() { this.lines = this.ctx.lyrics.linesIn(this.ctx.start, this.ctx.end); }
  get p() { return this.ctx.params; }
  get paper() { return this.p.paper === true; }
  get fg() { return this.paper ? INK : BONE; }
  get faint() { return this.paper ? 'rgba(10,10,11,.22)' : 'rgba(238,233,223,.22)'; }
  line(c: C, x1: number, y1: number, x2: number, y2: number, color = this.faint, width = 1.5) {
    c.strokeStyle = color; c.lineWidth = width; c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.stroke();
  }
  label(c: C, text: string, x: number, y: number, size = 22, color = this.fg) {
    c.font = font(F.mono(400), size); c.fillStyle = color; c.textAlign = 'left'; c.fillText(text, x, y);
  }
  ring(c: C, x: number, y: number, r: number, start = 0, end = TAU, color = this.faint, width = 2) {
    c.strokeStyle = color; c.lineWidth = width; c.beginPath(); c.arc(x, y, Math.max(.1, r), start, end); c.stroke();
  }
  plate(c: C, x: number, y: number, w: number, h: number, value: string, filled = true) {
    if (filled) { c.fillStyle = this.paper ? '#DDD7CA' : '#101011'; c.fillRect(x, y, w, h); }
    c.strokeStyle = this.faint; c.lineWidth = 1.5; c.strokeRect(x, y, w, h);
    this.label(c, value, x + 16, y + 32, 17);
    this.line(c, x + 16, y + 48, x + w - 16, y + 48);
    for (let j = 0; j < 4; j++) this.line(c, x + 16, y + 74 + j * 22, x + w * (.50 + hash(j + w) * .38), y + 74 + j * 22);
  }

  aperture(c: C, f: Frame) {
    const x = W * .64, y = H * .64, R = 292;
    for (let i = 0; i < 72; i++) {
      const a = i / 72 * TAU + f.t * .045;
      const a2 = a + .42 + f.a.vocal * .16;
      const inner = R * (.24 + .06 * Math.sin(f.t));
      this.line(c, x + Math.cos(a) * R, y + Math.sin(a) * R, x + Math.cos(a2) * inner, y + Math.sin(a2) * inner, i % 9 === 0 ? SIGNAL : this.faint, i % 9 === 0 ? 2.5 : 1.2);
    }
    this.ring(c, x, y, R + 34, 0, TAU, this.fg, 2);
    this.ring(c, x, y, R + 52, -1.5, -1.5 + f.p * TAU, SIGNAL, 4);
    this.label(c, 'HUMAN OVERSIGHT', W * .08, H * .56, 31);
    this.label(c, 'APERTURE / OPEN', W * .08, H * .62, 20);
    this.line(c, W * .08, H * .69, x - R - 60, H * .69, SIGNAL, 2);
    this.label(c, '01 : RECEIVE SIGNAL', W * .08, H * .76, 20);
  }

  strata(c: C, f: Frame) {
    const drop = smooth((f.p - .22) / .48);
    for (let i = 0; i < 35; i++) {
      c.beginPath();
      for (let j = 0; j <= 90; j++) {
        const u = j / 90;
        const x = W * (.08 + .84 * u);
        const fold = Math.exp(-Math.pow((u - .58 - .04 * Math.sin(f.t)) / .15, 2));
        const y = H * .44 + i * 10 + fold * (130 + 140 * drop) + Math.sin(u * 8 + i * .12 + f.t) * 12;
        if (j) c.lineTo(x, y); else c.moveTo(x, y);
      }
      c.strokeStyle = i === Math.floor(f.p * 34) ? SIGNAL : this.faint; c.lineWidth = i % 5 === 0 ? 2.4 : 1; c.stroke();
    }
    this.label(c, 'RESIDUAL ERROR / NOT ZERO', W * .1, H * .88, 22);
    const x = W * (.2 + f.p * .6);
    this.line(c, x, H * .41, x, H * .84, SIGNAL, 2.5);
    c.fillStyle = SIGNAL; c.fillRect(x - 5, H * .4, 10, 10);
  }

  letter(c: C, f: Frame) {
    const variant = Number(this.p.variant ?? 1);
    c.save(); c.translate(W * .5, H * .65); c.rotate(Math.sin(f.lt * .4) * .018);
    const w = 1030, h = 360;
    c.fillStyle = this.paper ? '#DFD8CB' : '#141415'; c.fillRect(-w / 2, -h / 2, w, h);
    c.strokeStyle = this.fg; c.lineWidth = 2; c.strokeRect(-w / 2, -h / 2, w, h);
    this.line(c, -w / 2, -h / 2, 0, h * .12, this.faint, 2);
    this.line(c, w / 2, -h / 2, 0, h * .12, this.faint, 2);
    this.label(c, `REQUEST 00${variant}`, -w / 2 + 35, -h / 2 + 52, 21);
    this.label(c, variant === 3 ? 'PLEASE KEEP THIS CHANNEL OPEN' : 'TO WHOM IT MAY CONCERN', -w / 2 + 35, h / 2 - 38, 23);
    c.save(); c.translate(w * .29, -28); c.rotate(-.14);
    c.strokeStyle = SIGNAL; c.lineWidth = 5; c.strokeRect(-130, -50, 260, 100);
    this.label(c, variant === 1 ? 'PENDING' : variant === 2 ? 'DENIED' : 'UNREAD', -108, 10, 35, SIGNAL);
    c.restore(); c.restore();
    for (let i = 0; i < 10; i++) { const x = W * .21 + i * 120; this.line(c, x, H * .87, x + 60, H * .87, i < Math.floor(f.p * 10) ? SIGNAL : this.faint, 2); }
  }

  chamber(c: C, f: Frame) {
    c.save(); c.translate(W * .53, H * .64);
    for (let i = 17; i >= 0; i--) {
      const z = ((i + f.lt * .8) % 18) / 18;
      const s = .18 + z * z * 1.5;
      c.save(); c.rotate(.28 + Math.sin(f.t * .13) * .14); c.scale(s, s * .66);
      c.translate((hash(i + 10) - .5) * 90, -z * 36);
      c.strokeStyle = i % 6 === 0 ? SIGNAL : this.faint; c.lineWidth = 2 / s; c.strokeRect(-410, -285, 820, 570);
      if (i % 4 === 0) this.label(c, `APPROVAL / ${String(i + 1).padStart(2, '0')}`, -380, -250, 23);
      c.restore();
    }
    c.restore();
    this.label(c, 'EVERY DOOR LEADS TO THE SAME REVIEW', W * .08, H * .9, 20);
  }

  specimen(c: C, f: Frame) {
    const cx = W * .6, cy = H * .63;
    for (let k = 0; k < 52; k++) {
      c.beginPath();
      for (let j = 0; j <= 180; j++) {
        const a = j / 180 * TAU;
        const r = 90 + k * 3.8 + Math.sin(a * 5 + f.t * .45 + k * .06) * 30 + Math.sin(a * 9 - f.t) * 13 * f.a.vocal;
        const x = cx + Math.cos(a) * r * 1.38, y = cy + Math.sin(a) * r;
        if (j) c.lineTo(x, y); else c.moveTo(x, y);
      }
      c.strokeStyle = k % 13 === 0 ? SIGNAL : this.faint; c.lineWidth = k % 13 === 0 ? 2 : 1; c.stroke();
    }
    this.label(c, 'SURFACE CHECK', W * .08, H * .52, 28);
    this.label(c, 'INTERIOR: UNVERIFIED', W * .08, H * .58, 20);
    this.line(c, W * .08, H * .64, W * .35, H * .64, SIGNAL, 2);
  }

  orbit(c: C, f: Frame) {
    const t = f.t * .18;
    for (let i = 0; i < 25; i++) {
      c.save(); c.translate(W * .6, H * .62); c.rotate(t + i * .095);
      const r = 95 + i * 9;
      c.scale(1.55, .35 + .65 * Math.abs(Math.sin(t + i * .07)));
      this.ring(c, 0, 0, r, -.4, TAU - .7, i % 8 === 0 ? SIGNAL : this.faint, i % 8 === 0 ? 2.8 : 1.3);
      c.restore();
    }
    this.label(c, 'CERTIFICATION ORBIT', W * .08, H * .82, 28);
    this.label(c, 'THE SUBJECT HAS BECOME THE AUTHORITY', W * .08, H * .88, 18);
  }

  stamp(c: C, f: Frame) {
    for (let i = 6; i >= 0; i--) {
      c.save(); c.translate(W * .5 + i * 15, H * .65 - i * 9); c.rotate((i - 3) * .018);
      this.plate(c, -540, -210, 1080, 420, 'INDEPENDENT SAFETY REVIEW / FORM 00'); c.restore();
    }
    c.save(); c.translate(W * .52, H * .65); c.rotate(-.11);
    const s = 1 + f.a.kick * .025; c.scale(s, s);
    c.strokeStyle = SIGNAL; c.lineWidth = 8; c.strokeRect(-450, -93, 900, 186); c.lineWidth = 2; c.strokeRect(-434, -77, 868, 154);
    c.font = font(F.archivo(100, 900), 91); c.textAlign = 'center'; c.fillStyle = SIGNAL; c.fillText('SELF CERTIFIED', 0, 34);
    c.restore();
    this.label(c, 'ISSUER = SUBJECT  /  WITNESSES: NONE', W * .23, H * .91, 20);
  }

  route(c: C, f: Frame) {
    const y = H * .64, turn = W * (.4 + smooth(f.p) * .24);
    for (let i = 0; i < 20; i++) {
      c.strokeStyle = i === 9 ? SIGNAL : this.faint; c.lineWidth = i === 9 ? 5 : 1.5;
      c.beginPath(); c.moveTo(W * .08, y + i * 8 - 80); c.lineTo(turn + i * 8, y + i * 8 - 80); c.lineTo(turn + i * 8, H * .38); c.stroke();
    }
    this.label(c, 'SCOPE CHANGED', W * .08, H * .8, 46);
    this.label(c, 'NO REVIEW WAS SCHEDULED FOR THIS DIRECTION', W * .08, H * .88, 20);
    this.ring(c, turn + 72, y - 8, 48 + f.a.kick * 12, 0, TAU, SIGNAL, 3);
  }

  loops(c: C, f: Frame) {
    for (let row = 0; row < 4; row++) for (let col = 0; col < 9; col++) {
      const id = row * 9 + col;
      const x = 180 + col * 194, y = H * .46 + row * 115;
      c.save(); c.translate(x, y); c.rotate(-.3 + .06 * Math.sin(f.t + id));
      c.strokeStyle = id <= f.p * 36 ? this.fg : this.faint; c.lineWidth = 2.6;
      c.beginPath(); c.moveTo(-30, -16); c.lineTo(34, -16); c.arc(34, 0, 16, -Math.PI / 2, Math.PI / 2); c.lineTo(-45, 16); c.arc(-45, -9, 25, Math.PI / 2, Math.PI * 1.5); c.lineTo(28, -34); c.stroke();
      c.restore();
      if (id === Math.floor(f.p * 35)) { this.ring(c, x, y, 60, 0, TAU, SIGNAL, 2); this.label(c, 'ALLOCATED', x - 51, y + 56, 14); }
    }
    this.label(c, 'RESOURCE ALLOCATION / ALL OTHER PURPOSES DEFERRED', W * .08, H * .94, 19);
  }

  chain(c: C, f: Frame) {
    const lit = f.p * 120;
    for (let i = 0; i < 120; i++) {
      const row = Math.floor(i / 24), k = i % 24;
      const x = W * .08 + (row % 2 ? 23 - k : k) * 70, y = H * .46 + row * 86;
      const burned = i < lit;
      this.ring(c, x, y, burned ? 4 : 11, 0, TAU, burned ? SIGNAL : this.faint, burned ? 4 : 1.5);
      if (i === Math.floor(lit)) {
        c.save(); c.shadowColor = SIGNAL; c.shadowBlur = 40; c.fillStyle = SIGNAL; c.fillRect(x - 7, y - 7, 14, 14); c.restore();
      }
    }
    this.label(c, 'EXCEPTION CHAIN / EACH LINK APPROVED THE NEXT', W * .08, H * .94, 19);
  }

  stack(c: C, f: Frame) {
    for (let i = 16; i >= 0; i--) {
      const z = ((i + f.lt * 1.5) % 17) / 17;
      const s = .20 + z * 1.35;
      c.save(); c.translate(W * .58 + Math.sin(z * 4 + f.t * .3) * 60, H * (.4 + z * .4)); c.transform(s, -.27 * s, .48 * s, .65 * s, 0, 0);
      this.plate(c, -300, -150, 600, 300, i % 2 ? 'APPROVED BY THE PREVIOUS LAYER' : 'DEFER TO THE NEXT LAYER');
      if (i % 4 === 0) this.line(c, -280, 130, 280, 130, SIGNAL, 4);
      c.restore();
    }
    this.label(c, 'RESPONSIBILITY / RECURSIVELY DELEGATED', W * .08, H * .92, 20);
  }

  weave(c: C, f: Frame) {
    const density = Number(this.p.density ?? 1);
    for (let i = 0; i < 64; i++) {
      c.beginPath();
      for (let j = 0; j <= 90; j++) {
        const u = j / 90;
        const x = W * (.08 + .84 * u);
        const y = H * .41 + i * 7 + Math.sin(u * 12 + i * .09 + f.t * .7) * 56 * density;
        if (j) c.lineTo(x, y); else c.moveTo(x, y);
      }
      c.strokeStyle = i % 16 === 0 ? SIGNAL : this.faint; c.lineWidth = i % 16 === 0 ? 2.8 : 1; c.stroke();
    }
    this.label(c, this.p.kind === 'recursive' ? 'EVERY SIGNATURE REFERS TO ITSELF' : 'CAPACITY EXCEEDED / EXPAND THE DEFINITION', W * .08, H * .93, 20);
  }

  recursive(c: C, f: Frame) {
    c.save(); c.translate(W * .61, H * .64);
    for (let i = 0; i < 20; i++) {
      const s = Math.pow(.86, i) * (1 + f.p * .1);
      c.save(); c.rotate(i * .055 + f.t * .035); c.scale(s, s);
      c.strokeStyle = i % 5 ? this.faint : SIGNAL; c.lineWidth = 2 / s; c.strokeRect(-430, -255, 860, 510);
      if (i < 4) this.label(c, 'APPROVED: SEE ATTACHED APPROVAL', -407, -216, 22);
      c.restore();
    }
    c.restore();
    this.label(c, 'RECURSIVE AUTHORITY', W * .08, H * .87, 30);
  }

  redact(c: C, f: Frame) {
    c.save(); c.translate(W * .54, H * .65); c.rotate(-.035);
    this.plate(c, -560, -245, 1120, 490, 'EXHIBIT / FINAL HUMAN REVIEW');
    for (let i = 0; i < 6; i++) {
      const width = 710 + hash(i + 99) * 180;
      c.fillStyle = this.paper ? INK : BONE; c.globalAlpha = .95;
      c.fillRect(-520, -155 + i * 55, width * smooth(f.p * 3 - i * .1), 25);
    }
    c.globalAlpha = 1; c.restore();
    this.label(c, 'EVIDENCE WITHHELD', W * .12, H * .93, 28, SIGNAL);
  }

  hook(c: C, f: Frame) {
    const n = Number(this.p.variant ?? 1);
    const word = this.lines.flatMap((line) => line.words).find((w) => f.t >= w.start && f.t < w.end);
    const text = word?.w.toUpperCase() ?? 'P(DOOM)';
    const age = word ? Math.max(0, f.t - word.start) : 1;
    const punch = 1 + Math.exp(-age * 22) * .14;
    const size = n === 3 ? 100 : 210;
    c.font = font(F.archivo(n === 4 ? 75 : 100, 900), size);
    const width = c.measureText(text).width;
    c.save(); c.translate(W / 2, H * .58); c.scale(Math.min(punch, W * .86 / Math.max(width, 1)), punch);
    c.fillStyle = this.fg; c.textAlign = 'center'; c.fillText(text, 0, 0); c.restore();
    const value = ['0.15', '0.42', '0.81', '0.99'][n - 1];
    c.font = font(F.archivo(100, 700), n === 3 ? 96 : 170); c.fillStyle = this.fg; c.textAlign = 'center'; c.fillText(value, W / 2, H * .79);
    this.label(c, 'RISK REGISTER / FICTIONAL SCENARIO', W * .08, H * .91, 20);
    this.line(c, W * .08, H * .33, W * .92, H * .33, SIGNAL, 4);
    if (n === 4) for (let i = 0; i < 14; i++) this.line(c, W * .08 + i * 121, H * .87, W * .08 + i * 121, H * .9, SIGNAL, 3);
  }

  close(c: C, f: Frame) {
    const x = W / 2, y = H * .54;
    for (let i = 0; i < 36; i++) {
      const a = i / 36 * TAU + f.t * .025, r = 290 * (1 - smooth((f.p - .1) / .62));
      this.line(c, x + Math.cos(a) * 470, y + Math.sin(a) * 360, x + Math.cos(a + .6) * r, y + Math.sin(a + .6) * r, i % 6 === 0 ? SIGNAL : this.faint, 2);
    }
    c.fillStyle = INK; c.fillRect(W * .14, H * .43, W * .72, H * .2);
    c.textAlign = 'center'; c.font = font(F.archivo(100, 900), 100); c.fillStyle = BONE; c.fillText('THE LAST AUDIT', W / 2, H * .53);
    c.font = font(F.mono(400), 27); c.fillText('NO HUMAN SIGNATURE WAS FOUND.', W / 2, H * .6);
    if (f.p > .4) {
      c.font = font(F.mono(400), 20); c.fillStyle = BONE;
      c.fillText('VISUALS: VIDEOGRAPH  /  ENGINE: PDOOM-VIDEO (MIT)', W / 2, H * .86);
      c.fillText('MUSIC & LYRICS: SEE PROJECT CREDITS', W / 2, H * .9);
    }
  }

  lyrics(c: C, f: Frame) {
    let line = this.lines.find((l) => f.t >= l.start && f.t < l.end);
    line ??= this.lines.find((l) => l.start > f.t && l.start - f.t < .22);
    if (!line) return;
    const size = 69, maxWidth = W * .84;
    c.font = font(F.archivo(100, 700), size); c.textAlign = 'left';
    const rows: Array<typeof line.words> = [[]];
    let rowWidth = 0;
    for (const word of line.words) {
      const width = c.measureText(word.w + ' ').width;
      if (rowWidth + width > maxWidth && rows[rows.length - 1].length) { rows.push([]); rowWidth = 0; }
      rows[rows.length - 1].push(word); rowWidth += width;
    }
    rows.forEach((row, index) => {
      let x = W * .08;
      const y = H * .19 + index * 85;
      for (const word of row) {
        const p = Lyrics.wordProgress(word, f.t);
        c.globalAlpha = p === 0 ? .32 : 1;
        c.fillStyle = p > 0 && p < 1 ? (this.paper ? '#C21D0B' : SIGNAL) : this.fg;
        c.fillText(word.w, x, y); x += c.measureText(word.w + ' ').width;
      }
    });
    c.globalAlpha = 1;
  }

  render(f: Frame, out: WebGLRenderTarget) {
    this.bg.u.t.value = f.t; this.bg.u.energy.value = f.a.rms;
    this.bg.render(this.ctx.renderer, out);
    this.layer.clear(this.paper ? BONE : undefined);
    const c = this.layer.ctx;
    this.label(c, `THE LAST AUDIT  /  ${String(this.p.serial ?? 1).padStart(2, '0')}  /  ${this.p.heading ?? 'REVIEW'}`, W * .08, H * .075, 20);
    this.line(c, W * .08, H * .1, W * .92, H * .1, this.faint, 1);
    c.save();
    const kind = this.p.kind ?? 'aperture';
    if (kind === 'hook') this.hook(c, f);
    else if (kind === 'close') this.close(c, f);
    else {
      c.translate(W / 2, H * .62); c.scale(1 + f.a.kick * .007, 1 + f.a.kick * .007); c.translate(-W / 2, -H * .62);
      switch (kind) {
        case 'strata': this.strata(c, f); break;
        case 'letter': this.letter(c, f); break;
        case 'chamber': this.chamber(c, f); break;
        case 'specimen': this.specimen(c, f); break;
        case 'orbit': this.orbit(c, f); break;
        case 'stamp': this.stamp(c, f); break;
        case 'route': this.route(c, f); break;
        case 'loops': this.loops(c, f); break;
        case 'chain': this.chain(c, f); break;
        case 'stack': this.stack(c, f); break;
        case 'weave': this.weave(c, f); break;
        case 'recursive': this.recursive(c, f); break;
        case 'redact': this.redact(c, f); break;
        default: this.aperture(c, f);
      }
    }
    c.restore();
    if (kind !== 'hook' && kind !== 'close') this.lyrics(c, f);
    this.ctx.comp.draw(this.ctx.renderer, this.layer.upload(), out);
    return { hud: 0, frame: 0, pdoom: 0, bloom: .10, halation: .08, grain: .018, ca: .18, vignette: .12,
      fade: kind === 'close' ? smooth((f.p - .94) / .06) : 0 };
  }
  dispose() { this.layer.texture.dispose(); this.bg.mat.dispose(); }
}
