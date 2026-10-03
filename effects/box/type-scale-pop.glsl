/*@effect
{
  "id": "type-scale-pop",
  "name": "弹性缩放字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "scale", "pop", "elastic", "bounce", "文字动画", "弹出", "缩放", "Q弹"],
  "summary": "文字从一个点“啵”地弹出放大，冲过头再回弹几下站稳（弹性缓动），背景保持不动；每个鼓点文字轻轻鼓一下；结尾缩回消失。",
  "when": "综艺花字、口号与强调词、可爱/活泼的品牌、游戏与儿童内容、价格与数字的强调。",
  "avoid": "文字压在复杂画面上（文字原位用补底色填）；严肃新闻与商务字幕。",
  "params": {
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "缩放中心 X（对准文字中心）" },
    "centerY": { "type": "float", "default": 0.55, "min": 0, "max": 1, "label": "缩放中心 Y" },
    "inEnd": { "type": "float", "default": 0.25, "min": 0.03, "max": 0.7, "label": "弹出完成于镜头进度" },
    "outStart": { "type": "float", "default": 0.9, "min": 0.4, "max": 1, "label": "缩回开始（1 = 不缩回）" },
    "bounce": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "弹性（回弹幅度）" },
    "throb": { "type": "float", "default": 0, "min": 0, "max": 0.15, "label": "鼓点鼓起（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" }
  },
  "bindings": { "throb": { "to": "kick", "amount": 0.06 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/game-show：综艺花字弹出", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（动画的“挤压与伸展”原则）：物体弹出时会冲过目标大小再回弹，像弹簧——这让文字显得有弹性、有重量。
// 只缩放“字”：在缩放后的位置找字，原位的字用补底色擦掉，背景不动。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 弹性缓动：0 → 1，冲过头后按衰减正弦回弹（bounce 控制回弹幅度）。
  float p = uProgress;
  float t = clamp(p / inEnd, 0., 1.);
  float s = t >= 1. ? 1. : 1. - pow(1. - t, 3.) * cos(t * 3.1416 * (1. + bounce * 2.)) * (1. - t * .2);
  s = mix(1. - pow(1. - t, 3.), s, bounce);
  // ② 出场：反向缩到 0（加速）；鼓点鼓起：已弹出后每个鼓点放大一点再回落（throb 挂 kick）。
  if (outStart < .999) { float o = clamp((p - outStart) / (1. - outStart), 0., 1.); s *= 1. - o * o; }
  s *= 1. + throb * step(.999, t);

  // ③ 缩放后的字：显示点 uv 对应原图里 (uv - c)/s + c（s≈0 时什么都没有）。
  vec2 c0 = vec2(centerX, centerY);
  vec3 scaled = s > .01 ? srcTex((uv - c0) / s + c0).rgb : bg;
  float inkS = s > .01 ? inkOf(scaled) : 0.;

  // ④ 合成：原位的字擦掉 → 盖上缩放后的字。
  vec3 c = mix(src, bg, inkOf(src));
  c = mix(c, scaled, inkS);
  return vec4(c, 1.);
}
