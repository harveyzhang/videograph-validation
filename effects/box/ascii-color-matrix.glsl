/*@effect
{
  "id": "ascii-color-matrix",
  "name": "彩色字符画",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["ascii art", "text art", "characters", "terminal", "color ascii", "字符画", "彩色", "终端", "像素文字"],
  "summary": "画面由彩色的字符拼成：每格按亮度选一个越来越“满”的字符（空格 . : - = + * # @），字符保留原画面颜色，黑底；鼓点时字符整体亮一级。",
  "when": "黑客/编程/极客题材、复古电脑、音乐可视化、“数字化身”的意象。",
  "avoid": "需要细节与真实感的镜头；与 ascii-terminal（单色终端绿字）选一个即可——这个是保留原画面颜色的彩色版。",
  "params": {
    "cell": { "type": "float", "default": 0.02, "min": 0.008, "max": 0.06, "label": "字符大小（画面高度比例）" },
    "gain": { "type": "float", "default": 0, "min": 0, "max": 0.3, "label": "鼓点提亮（通常由节拍驱动）" },
    "saturate": { "type": "float", "default": 1.3, "min": 0, "max": 2, "label": "颜色饱和" },
    "bg": { "type": "color", "default": "#050507", "label": "底色" }
  },
  "bindings": { "gain": { "to": "kick", "amount": 0.15 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/ascii-crt", "note": "只参考风格名称与观感描述；字符点阵为本项目自绘" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；字形为本项目自绘，inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（ASCII 艺术）：用不同“墨量”的字符代替灰度——空格最淡，@ 最浓；从远处看，字符组成的密度就是画面的明暗。
// 彩色版本再给每个字符染上它所在位置的颜色。字符用 5×5 点阵手绘（9 个等级），以整数位图存储。

// 9 级字符的 5×5 点阵（行优先，bit0 = 左上）：空格 . : - = + * # @
const int GL[9] = int[9](0, 4194304, 131200, 14336, 459200, 145536, 22511061, 11512810, 15136302);

vec4 effect(vec2 uv) {
  float cpx = cell * uRes.y;
  vec2 g = vec2(uv.x * uRes.x, (1. - uv.y) * uRes.y) / vec2(cpx * .62, cpx);
  vec2 id = floor(g), f = fract(g);
  // ① 取格子中心的颜色与亮度
  vec3 col = srcTex(vec2((id.x + .5) * cpx * .62 / uRes.x, 1. - (id.y + .5) * cpx / uRes.y)).rgb;
  float l = clamp(fxLuma(col) + gain, 0., 1.);
  // ② 按亮度选字符（9 级）
  int k = int(clamp(floor(l * 9.), 0., 8.));
  // ③ 字符点阵：格内留边距后映射到 5×5
  vec2 q = (f - vec2(.1, .1)) / vec2(.8, .8);
  float on = 0.;
  if (q.x >= 0. && q.x < 1. && q.y >= 0. && q.y < 1.) {
    int bx = int(floor(q.x * 5.)), by = int(floor(q.y * 5.));
    on = float((GL[k] >> (by * 5 + bx)) & 1);
  }
  // ④ 染色：保留原颜色并提饱和，亮度给足
  vec3 tint = clamp(mix(vec3(fxLuma(col)), col, saturate) / max(fxLuma(col), .25) * .9, 0., 1.);
  return vec4(mix(bg, tint, on), 1.);
}
