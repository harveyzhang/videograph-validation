/*@effect
{
  "id": "type-mask-rise",
  "name": "遮罩上推",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "mask reveal", "slide up", "kinetic typography", "editorial", "文字动画", "遮罩", "上推", "揭示"],
  "summary": "经典的动态排版入场：每一行文字从自己下方一条看不见的“遮罩线”后面向上滑出，行与行依次错开；结尾再向上滑进上方的遮罩消失。",
  "when": "片头标题、杂志/时尚/高级品牌的文字排版、多行文案与引言、发布会的大字幕；任何干净的文字入场。",
  "avoid": "文字压在复杂画面上（每行连同背景一起滑动，复杂背景会露出切边）；lines 与实际行数差太多时会把一行切开。",
  "params": {
    "lines": { "type": "float", "default": 3, "min": 1, "max": 20, "label": "行数（按画面高度均分）" },
    "inEnd": { "type": "float", "default": 0.3, "min": 0.05, "max": 0.8, "label": "入场完成于镜头进度" },
    "outStart": { "type": "float", "default": 0.88, "min": 0.4, "max": 1, "label": "出场开始（1 = 不出场）" },
    "stagger": { "type": "float", "default": 0.35, "min": 0, "max": 0.8, "label": "行间错开" },
    "nudge": { "type": "float", "default": 0, "min": 0, "max": 0.05, "label": "鼓点上弹（通常由节拍驱动）" },
    "fill": { "type": "color", "default": "#0d0d0f", "label": "遮罩外底色" }
  },
  "bindings": { "nudge": { "to": "kick", "amount": 0.015 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/swiss-motion：遮罩文字入场", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（AE 动态排版）：每行字放在一个与行同高的矩形遮罩里，字从遮罩下沿外面向上滑进来，
// 用强缓出（先快后慢）停住；多行时一行接一行错开几帧。出场时再从上沿滑出去。整个过程不改变字形，只有位置与裁切。

vec4 effect(vec2 uv) {
  // ① 行带：从上往下第 k 行，行内局部坐标 f（0 = 行底，1 = 行顶）。
  float n = max(lines, 1.);
  float yTop = 1. - uv.y;
  float k = floor(yTop * n);
  float f = 1. - fract(yTop * n);

  // ② 入场：行 k 的进度按 stagger 错开，强缓出（指数）；位移 = (1 - e) 个行高，从下往上。
  float p = uProgress;
  float span = max(1. - stagger, .1);
  float tIn = clamp((p / inEnd - k / n * stagger) / span, 0., 1.);
  float eIn = 1. - pow(2., -10. * tIn);
  float off = (1. - eIn);
  // ③ 出场：向上滑出（位移为负）。
  if (outStart < .999) {
    float tOut = clamp(((p - outStart) / (1. - outStart) - k / n * stagger) / span, 0., 1.);
    off -= tOut * tOut * 1.05;
  }
  // 鼓点上弹：已就位的行在鼓点时轻轻上提再回落（nudge 挂 kick，单位：行高的比例）
  off -= nudge * n * eIn;

  // ④ 取样：行内位置 f 显示原画面同一行带中 f + off 处的内容；超出本行带（被遮罩挡住）则显示底色。
  float fs = f + off;
  if (fs < 0. || fs > 1.) return vec4(fill, 1.);
  float ys = 1. - (k + 1. - fs) / n;
  return vec4(srcTex(vec2(uv.x, ys)).rgb, 1.);
}
