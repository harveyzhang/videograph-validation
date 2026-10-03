/*@effect
{
  "id": "type-box-reveal",
  "name": "色块揭示",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "box reveal", "color block", "wipe", "editorial", "文字动画", "色块", "揭示", "遮挡"],
  "summary": "一条实色块从左向右扫过每一行，扫到哪里字就在色块身后出现，色块再从右侧收走；多行依次错开。动态排版里最常见的“色块揭字”。",
  "when": "片头标题、名字/职位条、新闻与访谈的字幕、发布会大字、杂志感排版。",
  "avoid": "文字不是横排时；lines 与实际行数差太多（色块会盖到行与行之间）。",
  "params": {
    "lines": { "type": "float", "default": 3, "min": 1, "max": 12, "label": "行数（按画面高度均分）" },
    "inEnd": { "type": "float", "default": 0.35, "min": 0.05, "max": 0.9, "label": "揭示完成于镜头进度" },
    "stagger": { "type": "float", "default": 0.3, "min": 0, "max": 0.8, "label": "行间错开" },
    "block": { "type": "color", "default": "#ff4d12", "label": "色块颜色" },
    "rowFill": { "type": "float", "default": 0.62, "min": 0.2, "max": 1, "label": "色块高度（行高比例）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "揭示前文字位置的底色" },
    "kickFlash": { "type": "float", "default": 0, "min": 0, "max": 0.5, "label": "鼓点色块提亮（通常由节拍驱动）" }
  },
  "bindings": { "kickFlash": { "to": "kick", "amount": 0.25 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/swiss-motion：色块揭字", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（AE 动态排版）：每行字前面放一个实色矩形，矩形先从 0 宽长到整行宽（盖住字的位置），
// 然后左边缘向右收（露出后面的字），整个过程两段缓动。字本身不动，只是被色块“擦”出来。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float n = max(lines, 1.);
  float row = floor((1. - uv.y) * n);
  float fy = fract((1. - uv.y) * n);
  // ① 本行的进度（行间错开）
  float span = max(1. - stagger, .1);
  float t = clamp((uProgress / inEnd - row / n * stagger) / span, 0., 1.);
  // ② 两段：前半色块右边缘从 0 推到 1（盖），后半左边缘从 0 推到 1（揭），各自 cubic 缓出
  float a = clamp(t * 2., 0., 1.), b = clamp(t * 2. - 1., 0., 1.);
  float right = 1. - pow(1. - a, 3.);
  float left = 1. - pow(1. - b, 3.);
  float inBand = step(abs(fy - .5), rowFill * .5);
  float inBlock = step(left, uv.x) * step(uv.x, right) * inBand;
  // ③ 字是否已被揭开：色块左边缘扫过的地方显示原画面；之前（色块带内）字先被擦成底色，背景保持不动
  float revealed = step(uv.x, left);
  float ink = smoothstep(threshold - .08, threshold + .08, fxLuma(src));
  vec3 c = mix(src, mix(src, bg, ink * inBand), 1. - revealed);
  c = mix(c, block * (1. + kickFlash), inBlock);
  return vec4(c, 1.);
}
