/*@effect
{
  "id": "warhol-quad",
  "name": "波普四格",
  "kind": "post",
  "category": "画面版式",
  "tags": ["warhol", "pop art", "four panels", "screen print", "grid", "波普", "沃霍尔", "四格", "丝网"],
  "summary": "画面变成 2×2 四格，每格是同一画面的高反差丝网版本，分别印成四套撞色；每个小节四格的配色顺时针轮换一次。",
  "when": "波普/潮流/时尚、人物肖像与偶像、产品的趣味展示、副歌的视觉爆点。",
  "avoid": "需要真实颜色或细节的镜头；四格里主体会变小，远景人物不适合。",
  "params": {
    "posterize": { "type": "float", "default": 0.5, "min": 0.2, "max": 0.8, "label": "黑白分界" },
    "gap": { "type": "float", "default": 0.01, "min": 0, "max": 0.05, "label": "格缝" },
    "rotate": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "配色轮换（通常由小节驱动）" },
    "gapColor": { "type": "color", "default": "#111111", "label": "格缝颜色" }
  },
  "bindings": { "rotate": { "to": "bar", "amount": 0.3 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/silkscreen-poster：波普丝印", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（沃霍尔的丝网版画）：把一张照片做成高反差的黑色版，再在不同颜色的底色块上反复印刷，
// 每一格用一套刺眼的撞色——同一张脸被重复成一组波普符号。

vec3 pal(float i, float tone) {
  // 四套配色：底色（亮部）/ 中间色 / 墨色（暗部）
  vec3 a, b;
  if (i < .5) { a = vec3(1., .85, .1); b = vec3(.95, .2, .55); }
  else if (i < 1.5) { a = vec3(.3, .85, 1.); b = vec3(1., .45, .1); }
  else if (i < 2.5) { a = vec3(1., .45, .7); b = vec3(.2, .4, 1.); }
  else { a = vec3(.6, 1., .3); b = vec3(.6, .2, .9); }
  return tone > .66 ? a : tone > .33 ? b : vec3(.06, .05, .08);
}

vec4 effect(vec2 uv) {
  // ① 四格：每格显示整幅画面缩小后的样子
  vec2 cell = floor(uv * 2.);
  vec2 f = fract(uv * 2.);
  vec3 s = srcTex(f).rgb;
  // ② 丝网分色：亮度压成三档（亮/中/暗），档位边缘带一点噪声（网版不完美）
  float l = fxLuma(s) + (fxNoise(uv * uRes * .3) - .5) * .06;
  float tone = smoothstep(posterize - .2, posterize + .2, l);
  tone = tone > .7 ? 1. : tone > .3 ? .5 : 0.;
  // ③ 配色：每格一套，按小节顺时针轮换（rotate 挂小节：小节开头那一下“跳”一格）
  float idx = mod(cell.x + (1. - cell.y) * 2. + floor(uBar * 4. + rotate * 4.), 4.);
  vec3 c = pal(idx, tone);
  // ④ 格缝
  vec2 g = abs(f - .5) * 2.;
  float inGap = step(1. - gap * 4., max(g.x, g.y));
  return vec4(mix(c, gapColor, inGap), 1.);
}
