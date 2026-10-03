/*@effect
{
  "id": "type-gold-foil",
  "name": "烫金字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "gold foil", "metallic", "luxury", "glitter", "文字", "烫金", "金属字", "奢华"],
  "summary": "亮色文字变成烫金：金色随视角流动的金属渐变、细密的金箔颗粒、上缘高光下缘暗边；每小节一道光从字上扫过，鼓点时金箔闪烁。",
  "when": "婚礼/节日/颁奖/周年庆、奢侈品与酒类、新年贺卡、高端品牌落版。",
  "avoid": "科技/冷峻/朋克风格；细小的字（金属渐变在细笔画上看不出来）。",
  "params": {
    "gold": { "type": "color", "default": "#e3b04b", "label": "金色" },
    "deep": { "type": "color", "default": "#7a4f14", "label": "暗金色" },
    "sparkle": { "type": "float", "default": 0.3, "min": 0, "max": 1.5, "label": "金箔闪烁（通常由节拍驱动）" },
    "sweep": { "type": "float", "default": 0.8, "min": 0, "max": 2, "label": "扫光亮度" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "sparkle": { "to": "kick", "amount": 0.8 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/art-deco：金色装饰字", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：烫金是用加热的金属版把金箔压到纸上，金箔是镜面，反射的颜色随角度在亮金与暗金之间变化；
// 金箔表面有细微的压痕颗粒，在光下一闪一闪；字的上缘（朝光）亮、下缘暗。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkAt(uv);
  if (ink <= 0.) return vec4(src, 1.);
  // ① 金属渐变：沿斜方向的多段明暗（模拟弯曲的镜面反射周围环境），随时间缓慢流动
  vec2 p = uv * vec2(uRes.x / uRes.y, 1.);
  float g = sin((p.x * .6 + p.y * 1.8) * 9. + uTime * .6) * .5 + .5;
  g = mix(g, fxNoise(p * 6.) , .25);
  vec3 col = mix(deep, gold, smoothstep(.15, .85, g));
  col = mix(col, vec3(1., .95, .8), smoothstep(.85, 1., g) * .6);
  // ② 斜面：上方 2 像素处没有字 → 上缘高光；下方没有字 → 下缘暗边（2 次采样）
  float up = 1. - inkAt(uv + vec2(0., 2. / uRes.y)), dn = 1. - inkAt(uv - vec2(0., 2. / uRes.y));
  col += up * .35; col *= 1. - dn * .4;
  // ③ 扫光：每小节一道斜向高光扫过
  float s = (p.x + p.y * .5) - (fract(uBar + .2) * 3. - .8);
  col += vec3(1., .95, .85) * exp(-s * s * 120.) * sweep;
  // ④ 金箔颗粒闪烁：像素级颗粒，按 1/8 秒换一批，鼓点时更多更亮（只在字上，很小）
  float gr = fxHash(floor(uv * uRes / 2.) + floor(uTime * 8.));
  col += step(.985 - sparkle * .02, gr) * (.6 + sparkle);
  col *= .92 + .16 * fxHash(floor(uv * uRes / 2.));
  return vec4(mix(src, col, ink), 1.);
}
