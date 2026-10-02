// runtime.mjs — 特效箱的浏览器运行时（纯 ES 模块，studio 与无头预览共用；不依赖构建）。
// 动效契约（与引擎内宿主一致，见 src/server/transition-runtime.mjs）：
//   后期 post：     vec4 effect(vec2 uv)，用 srcTex(uv) 取画面（显示空间 0..1）。
//   转场 transition：vec4 transition(vec2 uv)，用 getFromColor/getToColor 与 progress（gl-transitions 接口）。
//   通用 uniform：uRes, uTime, uProgress（镜头内 0..1）, uBeat（拍内相位 0..1）, uBar（小节相位）, uKick（鼓点脉冲 0..1）, uEnergy；
//   参数按 manifest 声明为同名 uniform（float/vec2/vec3/int/bool）。节拍绑定由宿主在每帧把 基础值 + 强度 × 脉冲 写进参数。

export const FX_COMMON = `
float fxHash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float fxNoise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3. - 2. * f);
  return mix(mix(fxHash(i), fxHash(i + vec2(1, 0)), u.x), mix(fxHash(i + vec2(0, 1)), fxHash(i + vec2(1, 1)), u.x), u.y); }
float fxFbm(vec2 p) { float v = 0., a = .5; for (int i = 0; i < 5; i++) { v += a * fxNoise(p); p *= 2.03; a *= .5; } return v; }
float fxLuma(vec3 c) { return dot(c, vec3(.2126, .7152, .0722)); }
mat2 fxRot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }
float fxBayer4(vec2 p) { ivec2 q = ivec2(mod(p, 4.)); int i = q.x + q.y * 4;
  int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5); return (float(m[i]) + .5) / 16.; }
vec3 fxHex(float r, float g, float b) { return vec3(r, g, b) / 255.; }
float fxSobel(vec2 uv) { vec2 px = 1. / uRes; float tl = fxLuma(srcTex(uv + px * vec2(-1, 1)).rgb), t = fxLuma(srcTex(uv + px * vec2(0, 1)).rgb), tr = fxLuma(srcTex(uv + px * vec2(1, 1)).rgb);
  float l = fxLuma(srcTex(uv + px * vec2(-1, 0)).rgb), r = fxLuma(srcTex(uv + px * vec2(1, 0)).rgb);
  float bl = fxLuma(srcTex(uv + px * vec2(-1, -1)).rgb), b = fxLuma(srcTex(uv + px * vec2(0, -1)).rgb), br = fxLuma(srcTex(uv + px * vec2(1, -1)).rgb);
  float gx = -tl - 2. * l - bl + tr + 2. * r + br, gy = -tl - 2. * t - tr + bl + 2. * b + br; return length(vec2(gx, gy)); }
`;

const COMMON_UNIFORMS = 'uniform vec2 uRes; uniform float uTime, uProgress, uBeat, uBar, uKick, uEnergy;';
const glslType = { float: 'float', int: 'int', bool: 'bool', vec2: 'vec2', vec3: 'vec3', vec4: 'vec4', ivec2: 'ivec2', color: 'vec3' };

/** 把参数声明成 uniform；color 用 "#RRGGBB" 默认值，运行时转 vec3。 */
export function paramUniforms(params = {}) {
  return Object.entries(params).map(([name, spec]) => `uniform ${glslType[spec.type ?? 'float']} ${name};`).join('\n');
}
export function hexToVec3(hex) {
  const m = /^#?([0-9a-f]{6})$/i.exec(String(hex ?? ''));
  const n = m ? parseInt(m[1], 16) : 0xffffff;
  return [(n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255];
}

/** 预览宿主的片元着色器（WebGL2，显示空间）。 */
export function previewFragment(effect) {
  const head = `#version 300 es\nprecision highp float;\nprecision highp int;\nin vec2 vUv;\nout vec4 fragColor;\n${COMMON_UNIFORMS}\n${effect.declaresUniforms ? '' : paramUniforms(effect.params)}\n`; // gl-transitions 等上游代码自己声明参数 uniform
  if (effect.kind === 'transition') {
    return `${head}uniform sampler2D uFrom, uTo; uniform float progress, ratio;
vec4 getFromColor(vec2 uv) { return texture(uFrom, uv); }
vec4 getToColor(vec2 uv) { return texture(uTo, uv); }
vec4 srcTex(vec2 uv) { return texture(uFrom, uv); }
${FX_COMMON}\n${effect.glsl}\nvoid main() { fragColor = transition(vUv); }`;
  }
  return `${head}uniform sampler2D uSrc;\nvec4 srcTex(vec2 uv) { return texture(uSrc, clamp(uv, 0., 1.)); }\n${FX_COMMON}\n${effect.glsl}\nvoid main() { vec4 c = effect(vUv); fragColor = vec4(clamp(c.rgb, 0., 1.), 1.); }`;
}

/** 当前帧参数值：基础值 + 节拍绑定。clock = { beat, bar, kick, energy }。 */
export function resolveParams(effect, values = {}, clock = {}) {
  const out = {};
  for (const [name, spec] of Object.entries(effect.params ?? {})) {
    let value = values[name] ?? spec.default;
    const binding = (values.__bindings ?? effect.bindings ?? {})[name];
    if (binding && (spec.type ?? 'float') === 'float') {
      const pulse = binding.to === 'kick' ? clock.kick ?? 0 : binding.to === 'bar' ? Math.pow(1 - (clock.bar ?? 0), 3) : binding.to === 'energy' ? clock.energy ?? 0 : Math.pow(1 - (clock.beat ?? 0), 3);
      value = value + (binding.amount ?? 0) * pulse;
      if (spec.min !== undefined) value = Math.max(spec.min, value);
      if (spec.max !== undefined) value = Math.min(spec.max, value);
    }
    out[name] = spec.type === 'color' ? hexToVec3(value) : value;
  }
  return out;
}

/** 合成节拍时钟（预览用）：bpm 拍速，kick 在每拍起点衰减。 */
export function beatClock(t, bpm = 120) {
  const beats = t * bpm / 60;
  const beat = beats - Math.floor(beats);
  const bar = (beats / 4) - Math.floor(beats / 4);
  return { beat, bar, kick: Math.exp(-beat * 7), energy: 0.55 + 0.45 * Math.exp(-bar * 3) };
}

// ------------------------------------------------------------------ 演示素材（canvas2D，960×540）
const DEMO_W = 960, DEMO_H = 540;
export const DEMO_SOURCES = {
  type: '文字海报：大字、细线、橙色强调',
  scene: '风景：天空渐变、山峦剪影、太阳',
  shapes: '几何：彩色图形与网格运动',
  portrait: '人像剪影：柔光、轮廓与背景字',
};
export function drawDemo(ctx, name, t, clock = beatClock(t)) {
  const w = DEMO_W, h = DEMO_H;
  ctx.save();
  if (name === 'scene') {
    const sky = ctx.createLinearGradient(0, 0, 0, h);
    sky.addColorStop(0, '#2b4a7e'); sky.addColorStop(.55, '#e98d5a'); sky.addColorStop(1, '#f6d29a');
    ctx.fillStyle = sky; ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#fff1c9'; ctx.beginPath(); ctx.arc(w * .68, h * .52 - t * 6 % 40, 58 + 6 * clock.kick, 0, Math.PI * 2); ctx.fill();
    const ridge = (y, amp, freq, color, speed) => { ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(0, h);
      for (let x = 0; x <= w; x += 8) ctx.lineTo(x, y + Math.sin(x * freq + t * speed) * amp + Math.sin(x * freq * 2.7) * amp * .4); ctx.lineTo(w, h); ctx.fill(); };
    ridge(h * .62, 28, .012, '#4a3b5c', .2); ridge(h * .72, 34, .009, '#2e2840', .35); ridge(h * .84, 22, .015, '#171522', .5);
  } else if (name === 'shapes') {
    ctx.fillStyle = '#0e1220'; ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = 'rgba(255,255,255,.08)'; ctx.lineWidth = 1;
    for (let x = 0; x < w; x += 40) { ctx.beginPath(); ctx.moveTo(x + (t * 20) % 40, 0); ctx.lineTo(x + (t * 20) % 40, h); ctx.stroke(); }
    const colors = ['#ff5a36', '#ffd23f', '#3bceac', '#5b8cff', '#e365ff'];
    for (let i = 0; i < 9; i++) {
      const a = t * (.4 + i * .07) + i, r = 60 + 30 * Math.sin(t + i);
      ctx.fillStyle = colors[i % colors.length]; ctx.globalAlpha = .85;
      ctx.save(); ctx.translate(w / 2 + Math.cos(a) * (120 + i * 28), h / 2 + Math.sin(a * 1.3) * (80 + i * 12)); ctx.rotate(a);
      const s = r * (1 + .25 * clock.kick);
      if (i % 3 === 0) ctx.fillRect(-s / 2, -s / 2, s, s); else if (i % 3 === 1) { ctx.beginPath(); ctx.arc(0, 0, s / 2, 0, Math.PI * 2); ctx.fill(); } else { ctx.beginPath(); ctx.moveTo(0, -s / 2); ctx.lineTo(s / 2, s / 2); ctx.lineTo(-s / 2, s / 2); ctx.fill(); }
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  } else if (name === 'portrait') {
    const bg = ctx.createRadialGradient(w * .5, h * .4, 40, w * .5, h * .5, w * .7);
    bg.addColorStop(0, '#f2d7c2'); bg.addColorStop(1, '#3b2c3f'); ctx.fillStyle = bg; ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = 'rgba(255,255,255,.12)'; ctx.font = '700 150px "Segoe UI", sans-serif'; ctx.fillText('VOICE', 40 - (t * 30) % 200, 200);
    ctx.fillStyle = '#1a1420'; ctx.beginPath(); ctx.ellipse(w * .5, h * .42, 92, 118, Math.sin(t * .6) * .05, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.moveTo(w * .5 - 230, h); ctx.quadraticCurveTo(w * .5, h * .5, w * .5 + 230, h); ctx.fill();
    ctx.strokeStyle = '#ffb36b'; ctx.lineWidth = 3 + 4 * clock.kick; ctx.beginPath(); ctx.ellipse(w * .5, h * .42, 98, 124, 0, -1.2, .4); ctx.stroke();
  } else {
    ctx.fillStyle = '#0d0d0f'; ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = 'rgba(238,233,223,.25)'; ctx.lineWidth = 1;
    for (let i = 0; i < 12; i++) { const y = 60 + i * 38 + Math.sin(t + i) * 4; ctx.beginPath(); ctx.moveTo(60, y); ctx.lineTo(w - 60, y); ctx.stroke(); }
    const scale = 1 + .08 * clock.kick;
    ctx.save(); ctx.translate(w / 2, h / 2); ctx.scale(scale, scale);
    ctx.fillStyle = '#eee9df'; ctx.font = '900 168px "Segoe UI", "Arial Black", sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText('AUDIT', 0, -10);
    ctx.fillStyle = '#ff4d12'; ctx.fillRect(-250, 82, 500 * ((t * .25) % 1), 10);
    ctx.font = '600 22px Consolas, monospace'; ctx.fillStyle = '#ff4d12'; ctx.fillText(`THE LAST AUDIT · ${(t % 60).toFixed(2)}s`, 0, 130);
    ctx.restore();
  }
  ctx.restore();
}

// ------------------------------------------------------------------ WebGL2 预览渲染器
const VERT = `#version 300 es\nin vec2 position; out vec2 vUv; void main() { vUv = position * .5 + .5; gl_Position = vec4(position, 0., 1.); }`;

export class EffectPreviewer {
  constructor(canvas) {
    this.canvas = canvas;
    const gl = canvas.getContext('webgl2', { preserveDrawingBuffer: true, premultipliedAlpha: false });
    if (!gl) throw new Error('浏览器不支持 WebGL2');
    this.gl = gl;
    this.programs = new Map();
    this.buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    this.sources = [0, 1].map(() => { const c = document.createElement('canvas'); c.width = DEMO_W; c.height = DEMO_H; return c; });
    this.textures = [0, 1].map(() => this.makeTexture());
  }
  makeTexture() {
    const gl = this.gl, tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.LINEAR], [gl.TEXTURE_MAG_FILTER, gl.LINEAR], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v);
    return tex;
  }
  /** 编译并缓存；返回 { program } 或抛出带行号的错误。 */
  compile(effect) {
    const key = `${effect.id}:${effect.version ?? 1}:${effect.glsl.length}`;
    if (this.programs.has(key)) return this.programs.get(key);
    const gl = this.gl;
    const shader = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(`${effect.id} 着色器编译失败：${gl.getShaderInfoLog(s)}`); return s; };
    const program = gl.createProgram();
    gl.attachShader(program, shader(gl.VERTEX_SHADER, VERT));
    gl.attachShader(program, shader(gl.FRAGMENT_SHADER, previewFragment(effect)));
    gl.bindAttribLocation(program, 0, 'position');
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(`${effect.id} 链接失败：${gl.getProgramInfoLog(program)}`);
    const entry = { program, uniforms: new Map() };
    this.programs.set(key, entry);
    return entry;
  }
  /** 画一帧：effect 定义、参数值、时间 t（秒）、演示素材名（转场用 [from, to]），progress 仅转场/镜头进度。 */
  render(effect, { values = {}, t = 0, source = 'type', toSource = 'scene', progress, bpm = 120 } = {}) {
    const gl = this.gl, clock = beatClock(t, bpm);
    const names = effect.kind === 'transition' ? [source, toSource] : [source];
    names.forEach((name, i) => {
      const ctx = this.sources[i].getContext('2d');
      drawDemo(ctx, name, t, clock);
      gl.activeTexture(gl.TEXTURE0 + i); gl.bindTexture(gl.TEXTURE_2D, this.textures[i]);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, this.sources[i]);
    });
    const { program, uniforms } = this.compile(effect);
    gl.useProgram(program);
    const loc = (name) => { if (!uniforms.has(name)) uniforms.set(name, gl.getUniformLocation(program, name)); return uniforms.get(name); };
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    gl.uniform2f(loc('uRes'), this.canvas.width, this.canvas.height);
    const p = progress ?? ((t % 4) / 4);
    gl.uniform1f(loc('uTime'), t); gl.uniform1f(loc('uProgress'), p); gl.uniform1f(loc('uBeat'), clock.beat);
    gl.uniform1f(loc('uBar'), clock.bar); gl.uniform1f(loc('uKick'), clock.kick); gl.uniform1f(loc('uEnergy'), clock.energy);
    if (effect.kind === 'transition') {
      gl.uniform1i(loc('uFrom'), 0); gl.uniform1i(loc('uTo'), 1);
      const tp = progress ?? Math.min(1, Math.max(0, ((t % 3) - .5) / 2));
      gl.uniform1f(loc('progress'), tp); gl.uniform1f(loc('ratio'), this.canvas.width / this.canvas.height);
    } else gl.uniform1i(loc('uSrc'), 0);
    for (const [name, value] of Object.entries(resolveParams(effect, values, clock))) {
      const type = effect.params[name].type ?? 'float', l = loc(name);
      if (type === 'float') gl.uniform1f(l, value); else if (type === 'int') gl.uniform1i(l, value); else if (type === 'bool') gl.uniform1i(l, value ? 1 : 0);
      else if (type === 'vec2') gl.uniform2fv(l, value); else if (type === 'vec4') gl.uniform4fv(l, value); else if (type === 'ivec2') gl.uniform2iv(l, value); else gl.uniform3fv(l, value);
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buffer);
    gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }
}
