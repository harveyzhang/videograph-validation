/*@effect
{
  "id": "floating-card",
  "name": "悬浮卡片",
  "kind": "post",
  "category": "画面版式",
  "tags": ["card", "rounded", "floating", "glassmorphism", "ui", "卡片", "圆角", "悬浮", "毛玻璃"],
  "summary": "画面缩成一张圆角卡片悬浮在自己的模糊放大背景上（毛玻璃风格），卡片带柔和投影与一圈细亮边，随时间轻微倾斜漂浮；鼓点时卡片轻轻弹一下。",
  "when": "App/产品/社交内容的包装、语录与金句卡、现代简约的品牌片、多段内容的“卡片式”呈现。",
  "avoid": "需要全屏冲击的电影感镜头。",
  "params": {
    "scale": { "type": "float", "default": 0.72, "min": 0.3, "max": 0.95, "label": "卡片大小" },
    "radius": { "type": "float", "default": 0.04, "min": 0, "max": 0.15, "label": "圆角" },
    "tilt": { "type": "float", "default": 0.02, "min": 0, "max": 0.1, "label": "漂浮倾斜" },
    "blur": { "type": "float", "default": 0.025, "min": 0, "max": 0.06, "label": "背景模糊" },
    "bounce": { "type": "float", "default": 0, "min": 0, "max": 0.05, "label": "鼓点弹动（通常由节拍驱动）" }
  },
  "bindings": { "bounce": { "to": "kick", "amount": 0.015 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/glass-product 与 dark-keynote：卡片 UI", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（现代 UI 的“毛玻璃 + 卡片”）：内容放在一张圆角卡片上，卡片下方有大而柔的投影表示它离背景有距离；
// 背景是同一内容的放大模糊版（颜色呼应但不抢视线）；卡片边缘一圈细亮边像玻璃的折光。

float rbox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.)) + min(max(q.x, q.y), 0.) - r; }

vec4 effect(vec2 uv) {
  float A = uRes.x / uRes.y;
  // ① 背景：放大 1.3 倍 + 8 次环形模糊 + 略提亮（毛玻璃的雾白）
  vec2 bq = (uv - .5) / 1.3 + .5;
  vec3 bg = vec3(0.);
  for (int i = 0; i < 8; i++) { float a = float(i) * .7854; bg += srcTex(bq + vec2(cos(a), sin(a)) * blur * vec2(1. / A, 1.)).rgb; }
  bg = mix(bg / 8., vec3(1.), .12);
  // ② 卡片位置：缓慢漂浮的倾斜（旋转一点 + 上下浮动），鼓点弹动
  vec2 p = (uv - vec2(.5, .5 + sin(uTime * .8) * .01)) * vec2(A, 1.);
  p = fxRot(sin(uTime * .6) * tilt) * p;
  float s = scale * (1. + bounce);
  vec2 hb = vec2(A * s * .5, s * .5);
  float d = rbox(p, hb, radius);
  // ③ 投影：向下偏移、很宽很淡
  float dsh = rbox(p - vec2(0., -.03), hb, radius);
  bg *= 1. - .35 * exp(-max(dsh, 0.) * 14.);
  // ④ 卡片内容 + 细亮边
  vec3 card = srcTex(p / (hb * 2.) + .5).rgb;
  float inside = smoothstep(.002, -.002, d);
  float rim = smoothstep(.004, 0., abs(d + .002)) * .5;
  vec3 c = mix(bg, card, inside) + rim;
  return vec4(c, 1.);
}
