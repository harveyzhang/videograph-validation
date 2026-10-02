// Served as a virtual module inside a frozen engine host; no editor/storage privileges.
// 宿主职责：① 内置转场（dissolve/wipe/dip）② 特效箱转场（mode=effect，gl-transitions 接口）③ 镜头后期栈（shot.effects）。
// reference-server 在本模块前注入 FX_COMMON / hexToVec3 / resolveParams（源自 src/fx/runtime.mjs，与特效箱预览同一份实现）。
import * as THREE from 'three';
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

// ---------------------------------------------------------------- 特效箱宿主（引擎内）
// 引擎场景输出是线性 HDR；动效在显示空间编写（与预览一致），所以进出各做一次 sRGB 编解码。HDR 高光在动效处被截到 1。
const FX_COLOR = `
vec3 fxToDisplay(vec3 c) { c = clamp(c, 0., 1.); return mix(c * 12.92, 1.055 * pow(c, vec3(1. / 2.4)) - .055, step(.0031308, c)); }
vec3 fxToLinear(vec3 c) { c = clamp(c, 0., 1.); return mix(c / 12.92, pow((c + .055) / 1.055, vec3(2.4)), step(.04045, c)); }`;
const glslType = { float: 'float', int: 'int', bool: 'bool', vec2: 'vec2', vec3: 'vec3', vec4: 'vec4', ivec2: 'ivec2', color: 'vec3' };
function fxFragment(effect) {
  const params = effect.declaresUniforms ? '' : Object.entries(effect.specs ?? {}).map(([name, spec]) => `uniform ${glslType[spec.type ?? 'float']} ${name};`).join('\n');
  const head = `precision highp float;\nprecision highp int;\nin vec2 vUv;\nout vec4 fragColor;\nuniform vec2 uRes; uniform float uTime, uProgress, uBeat, uBar, uKick, uEnergy;\n${params}\n${FX_COLOR}\n`;
  if (effect.kind === 'transition') {
    return `${head}uniform sampler2D uFrom, uTo; uniform float progress, ratio;
vec4 getFromColor(vec2 uv) { return vec4(fxToDisplay(texture(uFrom, uv).rgb), 1.); }
vec4 getToColor(vec2 uv) { return vec4(fxToDisplay(texture(uTo, uv).rgb), 1.); }
vec4 srcTex(vec2 uv) { return getFromColor(uv); }
${FX_COMMON}\n${effect.glsl}\nvoid main() { fragColor = vec4(fxToLinear(transition(vUv).rgb), 1.); }`;
  }
  return `${head}uniform sampler2D uSrc;
vec4 srcTex(vec2 uv) { return vec4(fxToDisplay(texture(uSrc, clamp(uv, 0., 1.)).rgb), 1.); }
${FX_COMMON}\n${effect.glsl}\nvoid main() { fragColor = vec4(fxToLinear(effect(vUv).rgb), 1.); }`;
}
const FX_VERT = 'precision highp float;\nin vec3 position;\nout vec2 vUv;\nvoid main() { vUv = position.xy * .5 + .5; gl_Position = vec4(position.xy, 0., 1.); }';

class FxPass {
  constructor(effect) {
    this.effect = effect;
    const uniforms = { uRes: { value: [1, 1] }, uTime: { value: 0 }, uProgress: { value: 0 }, uBeat: { value: 0 }, uBar: { value: 0 }, uKick: { value: 0 }, uEnergy: { value: 0 },
      uSrc: { value: null }, uFrom: { value: null }, uTo: { value: null }, progress: { value: 0 }, ratio: { value: 16 / 9 } };
    for (const name of Object.keys(effect.specs ?? {})) uniforms[name] = { value: 0 };
    this.mat = new THREE.RawShaderMaterial({ glslVersion: THREE.GLSL3, vertexShader: FX_VERT, fragmentShader: fxFragment(effect), uniforms, depthTest: false, depthWrite: false });
    this.scene = new THREE.Scene();
    this.mesh = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.mat);
    this.mesh.frustumCulled = false;
    this.scene.add(this.mesh);
    this.cam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  }
  render(renderer, target, { src, from, to, progress = 0, frame, width, height }) {
    const u = this.mat.uniforms;
    const clock = { beat: frame.beatPhase ?? 0, bar: frame.barPhase ?? 0, kick: frame.a?.kick ?? Math.exp(-(frame.beatPhase ?? 0) * 7), energy: frame.a?.rms ?? 0.5 };
    u.uRes.value = [width, height]; u.uTime.value = frame.t; u.uProgress.value = frame.p ?? 0;
    u.uBeat.value = clock.beat; u.uBar.value = clock.bar; u.uKick.value = clock.kick; u.uEnergy.value = clock.energy;
    u.uSrc.value = src ?? null; u.uFrom.value = from ?? null; u.uTo.value = to ?? null; u.progress.value = progress; u.ratio.value = width / height;
    const values = resolveParams({ params: this.effect.specs }, { ...this.effect.params, __bindings: this.effect.bindings }, clock);
    for (const [name, value] of Object.entries(values)) u[name].value = value;
    renderer.setRenderTarget(target);
    renderer.render(this.scene, this.cam);
  }
  dispose() { this.mat.dispose(); this.mesh.geometry.dispose(); }
}

export function wrapTransitionScene(Original, spec, fps) {
  const effects = spec.effects ?? [];
  if (!spec.incomingTransition && spec.end === spec.logicalEnd && !effects.length) return Original;
  return class TransitionScene extends Original {
    constructor(ctx) {
      super({ ...ctx, start: spec.logicalStart, end: spec.logicalEnd });
      this.vgSpec = spec;
      this.vgTarget = null;
      this.vgPass = null;
      this.vgFx = null;
      if (spec.incomingTransition) this.handlesTransition = true;
    }
    /** 镜头后期栈：src → 动效 1 → … → 动效 N → target（中间用两张 RT 乒乓）。 */
    vgApplyEffects(srcRT, target, frame) {
      this.vgFx ??= { passes: effects.map((effect) => new FxPass({ ...effect, kind: 'post' })), rts: [makeRT(), makeRT()] };
      const { passes, rts } = this.vgFx;
      const width = srcRT.width, height = srcRT.height;
      let input = srcRT;
      passes.forEach((pass, index) => {
        const output = index === passes.length - 1 ? target : rts[index % 2];
        pass.render(this.ctx.renderer, output, { src: input.texture, frame, width, height });
        input = output;
      });
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
      if (!transition || !frame.under) {
        if (!effects.length) return super.render(own, out);
        this.vgTarget ??= makeRT();
        const post = super.render(own, this.vgTarget);
        this.vgApplyEffects(this.vgTarget, out, own);
        return post;
      }
      this.vgTarget ??= makeRT();
      const post = super.render(own, this.vgTarget);
      let incoming = this.vgTarget;
      if (effects.length) { this.vgEffected ??= makeRT(); this.vgApplyEffects(this.vgTarget, this.vgEffected, own); incoming = this.vgEffected; }
      const p = Math.max(0, Math.min(1, frame.tin));
      const eased = transition.easing === 'linear' ? p : p * p * (3 - 2 * p);
      if (transition.mode === 'effect' && transition.effect) {
        this.vgTransitionFx ??= new FxPass({ ...transition.effect, kind: 'transition' });
        this.vgTransitionFx.render(this.ctx.renderer, out, { from: frame.under, to: incoming.texture, progress: eased, frame: own, width: incoming.width, height: incoming.height });
        return post;
      }
      this.vgPass ??= new FSPass(shader, { texA: { value: null }, texB: { value: null }, progress: { value: 0 }, kind: { value: 0 }, reverseX: { value: false } });
      this.vgPass.u.progress.value = eased;
      this.vgPass.u.texA.value = frame.under;
      this.vgPass.u.texB.value = incoming.texture;
      this.vgPass.u.kind.value = transition.mode === 'wipe' ? 1 : transition.mode === 'dip' ? 2 : 0;
      this.vgPass.u.reverseX.value = transition.direction === 'right';
      this.vgPass.render(this.ctx.renderer, out);
      return post;
    }
    dispose() {
      super.dispose();
      this.vgTarget?.dispose();
      this.vgEffected?.dispose();
      this.vgPass?.mat.dispose();
      this.vgTransitionFx?.dispose();
      if (this.vgFx) { this.vgFx.passes.forEach((pass) => pass.dispose()); this.vgFx.rts.forEach((rt) => rt.dispose()); }
    }
  };
}
