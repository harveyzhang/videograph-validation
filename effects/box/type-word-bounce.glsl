/*@effect
{
  "id": "type-word-bounce",
  "name": "逐字跳跳",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "bounce", "hop", "beat", "lyrics", "文字动画", "跳动", "逐字", "歌词律动"],
  "summary": "文字按列（≈逐字）跟着节拍依次往上跳一下再落下（像卡拉OK 里跳动的小球经过每个字），跳起的字略微放大、落地时压扁一点；背景不动。",
  "when": "儿歌/可爱/流行歌词、口号与洗脑段落、综艺花字、跟唱提示。",
  "avoid": "文字压在复杂背景上（原位用补底色）；慢速抒情歌（跳动太欢快）。",
  "params": {
    "columns": { "type": "float", "default": 8, "min": 2, "max": 30, "label": "列数（≈ 字数）" },
    "height": { "type": "float", "default": 0.07, "min": 0, "max": 0.15, "label": "跳起高度" },
    "perBar": { "type": "float", "default": 1, "min": 0.25, "max": 4, "label": "每小节跳过一遍的次数" },
    "squash": { "type": "float", "default": 0.15, "min": 0, "max": 0.4, "label": "落地压扁" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" },
    "kick": { "type": "float", "default": 0, "min": 0, "max": 0.05, "label": "鼓点全体跳（通常由节拍驱动）" }
  },
  "bindings": { "kick": { "to": "kick", "amount": 0.015 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：歌词跳动", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（老式卡拉OK 的跳动小球 / AE 的逐字弹跳）：一个跳点沿着字依次落在每个字上，被“踩”到的字跳起来；
// 跳起时拉长、落地时压扁（挤压与伸展），让字显得有弹性。节拍：跳点按小节相位扫过所有列。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec3 base = mix(src, bg, inkOf(src));
  // 字可能跳到上方或压到下方，检查本列在 3 种可能偏移下的取样
  float col = floor(uv.x * columns);
  float cx = (col + .5) / columns;
  // ① 本列的跳动相位：跳点按小节相位 × perBar 扫过所有列；每列在自己的窗口里跳一次
  float sweep = fract(uBar * perBar) * columns;
  float ph = clamp(sweep - col, 0., 1.);
  float hop = sin(ph * 3.1416);                              // 0 → 1 → 0
  // ② 挤压与伸展：腾空时纵向拉长，刚落地压扁
  float sy = 1. + hop * .08 - squash * exp(-pow((ph - .97) * 12., 2.));
  float sx = 1. / max(sy, .5);
  float lift = hop * height + kick;
  // ③ 取样：以本列中心、画面中线为基准做缩放，再上移 lift
  vec2 q = vec2(cx + (uv.x - cx) / sx, .5 + (uv.y - lift - .5) / sy);
  vec3 s = srcTex(q).rgb;
  float m = inkOf(s) * step(abs(q.x - cx), .5 / columns);
  return vec4(mix(base, s, m), 1.);
}
