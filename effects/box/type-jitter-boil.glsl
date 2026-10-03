/*@effect
{
  "id": "type-jitter-boil",
  "name": "手绘抖动字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "boil", "jitter", "hand drawn", "stop motion", "文字", "抖动", "手绘感", "定格动画"],
  "summary": "文字像手绘动画一样“沸腾”：以每秒 12 张的节奏，每张的轮廓都被轻微地重新描一遍（边缘抖动、整体轻微错位），鼓点时抖得更厉害。",
  "when": "手绘/涂鸦/儿童/定格动画风格、独立音乐与 zine、搞怪字幕、紧张与焦虑的情绪。",
  "avoid": "需要稳重专业的商务字幕；文字压在复杂背景上（字移位后原位用补底色）。",
  "params": {
    "amount": { "type": "float", "default": 0.003, "min": 0, "max": 0.015, "label": "抖动幅度" },
    "fps": { "type": "float", "default": 12, "min": 4, "max": 24, "label": "抖动帧率（张/秒）" },
    "kickBoil": { "type": "float", "default": 0, "min": 0, "max": 0.01, "label": "鼓点加抖（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" }
  },
  "bindings": { "kickBoil": { "to": "kick", "amount": 0.005 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/rubber-hose 与 crayon-book：手绘线条沸腾", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（手绘动画的“line boil”）：动画师把同一张画描好几遍循环播放，每一遍的线条都有微小差别，
// 画面看起来在轻轻“沸腾”，即使角色静止也有生命感。每秒 12 张（一拍二）是传统手绘的节奏。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 当前是第几张：时间量化到 fps（同一张内画面完全静止）
  float frame = floor(uTime * fps);
  float a = amount + kickBoil;
  // ② 每张的轮廓扰动：低频噪声位移场（同一张内固定，张与张之间换种子）+ 整体的小错位
  vec2 p = uv * vec2(uRes.x / uRes.y, 1.);
  vec2 warp = (vec2(fxNoise(p * 18. + frame * 7.31), fxNoise(p * 18. + frame * 3.17 + 11.)) - .5) * 2. * a;
  warp += (vec2(fxHash(vec2(frame, 1.)), fxHash(vec2(frame, 2.))) - .5) * a * .8;
  vec3 moved = srcTex(uv - warp).rgb;
  // ③ 合成：擦掉原位的字，盖上这一张的字
  vec3 c = mix(src, bg, inkOf(src));
  c = mix(c, moved, inkOf(moved));
  return vec4(c, 1.);
}
