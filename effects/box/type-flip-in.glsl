/*@effect
{
  "id": "type-flip-in",
  "name": "逐字翻转入场",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "flip", "3d rotate", "card flip", "stagger", "文字动画", "翻转", "3D", "逐字"],
  "summary": "文字按列（≈ 逐字）绕水平轴从“躺平”翻起到正面，带透视压缩与明暗变化，从左到右依次翻起；结尾再依次向后翻倒。",
  "when": "标题与口号的入场、游戏/综艺/科技感的字卡、数字与价格的翻出。",
  "avoid": "文字压在复杂背景上（每列连背景一起翻转）；镜头太短时翻转看不清。",
  "params": {
    "columns": { "type": "float", "default": 12, "min": 2, "max": 40, "label": "列数（≈ 字数）" },
    "inEnd": { "type": "float", "default": 0.5, "min": 0.05, "max": 0.9, "label": "入场完成于镜头进度" },
    "outStart": { "type": "float", "default": 0.9, "min": 0.4, "max": 1, "label": "翻倒开始（1 = 不翻倒）" },
    "stagger": { "type": "float", "default": 0.6, "min": 0, "max": 0.9, "label": "列间错开" },
    "wobble": { "type": "float", "default": 0, "min": 0, "max": 0.5, "label": "鼓点点头（通常由节拍驱动）" },
    "fill": { "type": "color", "default": "#0d0d0f", "label": "背景底色" }
  },
  "bindings": { "wobble": { "to": "kick", "amount": 0.2 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：逐字 3D 入场", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（AE 逐字 3D 旋转）：每个字是一张卡片，绕自己底边的水平轴从 -90°（平躺、看不见）翻到 0°（正对镜头），
// 翻的过程中卡片在屏幕上的高度按 cos(角度) 压缩、受光变化；字与字之间错开时间。

vec4 effect(vec2 uv) {
  float col = floor(uv.x * columns);
  float order = col / max(columns - 1., 1.);
  float p = uProgress;
  float span = max(1. - stagger, .1);
  // ① 本列的翻起角度：入场 -90° → 0°（带一点过冲），出场 0° → +90°（向后倒）；鼓点点头
  float tIn = clamp((p / inEnd - order * stagger) / span, 0., 1.);
  float e = 1. - pow(1. - tIn, 3.) + sin(tIn * 3.1416) * .08;
  float ang = (1. - e) * -1.5708;
  if (outStart < .999) ang += clamp(((p - outStart) / (1. - outStart) - order * stagger) / span, 0., 1.) * 1.5708;
  ang += wobble * sin(uBeat * 3.1416) * step(.999, tIn);
  float k = cos(ang);
  if (k <= .02) return vec4(fill, 1.);
  // ② 绕画面水平中线翻转：屏幕上的 y 按 k 压缩（透视近似：靠近我们的那一边略宽）
  float y = (uv.y - .5) / k + .5;
  float persp = 1. + sin(ang) * (y - .5) * .4;
  float cx = (col + .5) / columns;
  float x = cx + (uv.x - cx) / persp;
  if (y < 0. || y > 1.) return vec4(fill, 1.);
  // ③ 受光：卡片转离正面时变暗
  vec3 c = srcTex(vec2(x, y)).rgb * (.45 + .55 * k);
  return vec4(c, 1.);
}
