// Served as a virtual module inside a frozen engine host; no editor/storage privileges.
import { FSPass, makeRT } from '/src/engine/gl.ts';

const shader = `
  uniform sampler2D texA, texB;
  uniform float progress;
  uniform int kind;
  uniform bool reverseX;
  void main() {
    vec4 a = texture(texA, vUv), b = texture(texB, vUv);
    float p = clamp(progress, 0., 1.);
    if (kind == 1) {
      float x = reverseX ? 1. - vUv.x : vUv.x;
      float m = 1. - smoothstep(p - .012, p + .012, x);
      if (p <= 0.) m = 0.; if (p >= 1.) m = 1.;
      fragColor = mix(a, b, m);
    } else if (kind == 2) {
      vec4 ink = vec4(.0030, .0030, .00335, 1.);
      fragColor = p < .5 ? mix(a, ink, p * 2.) : mix(ink, b, (p - .5) * 2.);
    } else fragColor = mix(a, b, p);
  }
`;

export function wrapTransitionScene(Original, spec, fps) {
  if (!spec.incomingTransition && spec.end === spec.logicalEnd) return Original;
  return class TransitionScene extends Original {
    constructor(ctx) {
      super({ ...ctx, start: spec.logicalStart, end: spec.logicalEnd });
      this.vgSpec = spec;
      this.vgTarget = null;
      this.vgPass = null;
      if (spec.incomingTransition) this.handlesTransition = true;
    }
    render(frame, out) {
      // 过渡放在切点之后；出镜画面停在上一段末帧，入镜画面始终使用当前歌曲时间。
      const spec = this.vgSpec;
      const t = frame.t >= spec.logicalEnd ? Math.max(spec.logicalStart, spec.logicalEnd - 1 / fps) : frame.t;
      const held = t !== frame.t;
      const beat = held ? this.ctx.audio.beatAt(t) : frame.beat;
      const bar = held ? this.ctx.audio.barAt(t) : frame.bar;
      const own = { ...frame, t, dt: held ? 0 : frame.dt, lt: t - spec.logicalStart,
        p: Math.max(0, Math.min(1, (t - spec.logicalStart) / (spec.logicalEnd - spec.logicalStart))),
        start: spec.logicalStart, end: spec.logicalEnd,
        a: held ? this.ctx.audio.sample(t) : frame.a, beat, bar,
        beatPhase: ((beat % 1) + 1) % 1, barPhase: ((bar % 1) + 1) % 1,
        under: null, tin: 1, tout: 0 };
      const transition = spec.incomingTransition;
      if (!transition || !frame.under) return super.render(own, out);
      this.vgTarget ??= makeRT();
      this.vgPass ??= new FSPass(shader, { texA: { value: null }, texB: { value: null }, progress: { value: 0 }, kind: { value: 0 }, reverseX: { value: false } });
      const post = super.render(own, this.vgTarget);
      const p = Math.max(0, Math.min(1, frame.tin));
      this.vgPass.u.progress.value = transition.easing === 'linear' ? p : p * p * (3 - 2 * p);
      this.vgPass.u.texA.value = frame.under;
      this.vgPass.u.texB.value = this.vgTarget.texture;
      this.vgPass.u.kind.value = transition.mode === 'wipe' ? 1 : transition.mode === 'dip' ? 2 : 0;
      this.vgPass.u.reverseX.value = transition.direction === 'right';
      this.vgPass.render(this.ctx.renderer, out);
      return post;
    }
    dispose() {
      super.dispose();
      this.vgTarget?.dispose();
      this.vgPass?.mat.dispose();
    }
  };
}
