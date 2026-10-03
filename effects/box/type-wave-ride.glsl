/*@effect
{
  "id": "type-wave-ride",
  "name": "波浪字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "wave", "wobble", "kinetic type", "jelly", "文字动画", "波浪", "律动", "果冻"],
  "summary": "文字像漂在水面上一样随一道正弦波上下起伏、左右轻摆，波峰从左向右跑；每一拍波幅涌起再回落，背景保持不动。",
  "when": "轻快的流行/儿童/夏日题材、歌词大字、可爱风标题；需要文字“跟着音乐摇”的镜头。",
  "avoid": "文字压在复杂画面上（文字移开后的空位用纯色补，复杂背景会露馅）；严肃/商务字幕。",
  "params": {
    "amp": { "type": "float", "default": 0.02, "min": 0, "max": 0.06, "label": "波幅（画面高度比例）" },
    "waves": { "type": "float", "default": 2, "min": 0.3, "max": 8, "label": "一屏内的波数" },
    "speed": { "type": "float", "default": 1.2, "min": 0, "max": 5, "label": "波速" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "darkText": { "type": "bool", "default": false, "label": "深色字（浅底）" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" }
  },
  "bindings": { "amp": { "to": "beat", "amount": 0.025 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：歌词律动", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（AE 的“波浪”文字动画）：每个字符的基线被一条移动的正弦波推着走，相邻字符相位不同，
// 整行字像波浪一样起伏；常配合每拍一次的波幅涌动。
// 这里只移动“字”（按亮度识别）：先在位移后的位置找字，没有字的地方显示原画面，原本是字、现在空了的地方用补底色。

float inkOf(vec3 c) {
  float l = fxLuma(c);
  return darkText ? smoothstep(threshold + .08, threshold - .08, l) : smoothstep(threshold - .08, threshold + .08, l);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 波：沿 x 的正弦相位随时间向右移动；amp 挂每拍——每拍开头波幅涌起，然后回落。
  float ph = uv.x * waves * 6.2832 - uTime * speed * 3.;
  vec2 off = vec2(cos(ph) * amp * .35 * uRes.y / uRes.x, sin(ph) * amp);

  // ② 字的新位置：显示点 uv 上的字来自原图的 uv - off（2 次采样：位移后的字 + 原位）。
  vec3 moved = srcTex(uv - off).rgb;
  float inkMoved = inkOf(moved);
  float inkHere = inkOf(src);

  // ③ 合成：先把原位的字擦掉（补底色），再把位移后的字盖上去。
  vec3 c = mix(src, bg, inkHere);
  c = mix(c, moved, inkMoved);
  return vec4(c, 1.);
}
