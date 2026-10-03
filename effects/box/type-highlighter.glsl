/*@effect
{
  "id": "type-highlighter",
  "name": "荧光笔划重点",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "highlighter", "marker", "emphasis", "hand drawn", "文字", "荧光笔", "划重点", "强调"],
  "summary": "一支荧光笔从左到右在文字后面涂出一道半透明的高亮色带：色带边缘有手绘的轻微抖动、两端略圆，字保持在色带上面清晰可读。",
  "when": "讲解/教学/科普视频的重点词、文档与笔记风格、引用与金句、产品卖点强调。",
  "avoid": "深色字压在深色背景上（荧光色要在浅底或深底亮字上才明显）；画面里字很多时整片都会被涂。",
  "params": {
    "inEnd": { "type": "float", "default": 0.35, "min": 0.05, "max": 0.9, "label": "涂完于镜头进度" },
    "thickness": { "type": "float", "default": 0.045, "min": 0.01, "max": 0.15, "label": "笔宽（画面高度比例）" },
    "wobble": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "手抖" },
    "marker": { "type": "color", "default": "#e9ff3c", "label": "荧光色" },
    "opacity": { "type": "float", "default": 0.8, "min": 0.1, "max": 1, "label": "色带不透明度（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "darkText": { "type": "bool", "default": false, "label": "深色字（浅底）" }
  },
  "bindings": { "opacity": { "to": "beat", "amount": 0.15 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/whiteboard 与 living-screencast：讲解强调", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：荧光笔是半透明的染料，涂在字上会和纸色相乘；人手涂的时候色带的上下边缘不是直线，
// 两端因为笔头停顿颜色更浓、略圆。这里先找出“字所在的行带”（当前像素上下 thickness 范围内有没有字），
// 再让色带按镜头进度从左往右延伸。

float inkAt(vec2 p) {
  float l = fxLuma(srcTex(p).rgb);
  return darkText ? smoothstep(threshold + .08, threshold - .08, l) : smoothstep(threshold - .08, threshold + .08, l);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 行带：在当前像素周围 5 列 × 3 行的网格里找字（15 次采样，横向间距 ≈ 一个字宽的一半、纵向 ±thickness）——
  //    只要附近有字，这里就在“这一行文字”的矩形范围里，于是色带是一整条，而不是贴着字形的轮廓。
  float wob = (fxNoise(vec2(uv.x * 14., 3.)) - .5) * thickness * .6 * wobble;
  float band = 0.;
  for (int j = -1; j <= 1; j++)
    for (int i = -2; i <= 2; i++)
      band = max(band, inkAt(vec2(uv.x + float(i) * thickness * .6 * uRes.y / uRes.x, uv.y + wob + float(j) * thickness)));

  // ② 涂抹进度：前沿从左到右，带一点倾斜（笔是斜着拖的），前沿处颜色更浓（笔头停顿）。
  float front = clamp(uProgress / inEnd, 0., 1.) * 1.1 - .05;
  float x = uv.x + (uv.y - .5) * .05;
  float drawn = smoothstep(front, front - .01, x);
  float tip = exp(-pow((x - front) * 60., 2.)) * .3;

  // ③ 合成：荧光色相乘到画面上（半透明染料），亮字（深底）时改为在字下方加色——两种情况都保证字可读。
  float a = clamp(band * drawn * (opacity + tip), 0., 1.);
  vec3 c = darkText ? mix(src, src * marker, a) : mix(src, marker, a * (1. - inkAt(uv)));
  return vec4(c, 1.);
}
