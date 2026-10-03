/*@effect
{
  "id": "type-knockout-fill",
  "name": "镂空图案字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "knockout", "pattern fill", "gradient text", "stripes", "文字", "镂空", "图案填充", "渐变字"],
  "summary": "亮色文字变成一扇“窗”，窗里流动着斜条纹与三色渐变，字外的画面压暗；文字下方带一道硬投影。每小节条纹换一个流动方向感。",
  "when": "流行/运动/潮牌标题、促销与倒计时大字、片头品牌名；字体粗大时最好看。",
  "avoid": "细字体或小字（图案在笔画里看不出来）；需要原本字色（比如品牌标准色）的镜头。",
  "params": {
    "stripes": { "type": "float", "default": 14, "min": 2, "max": 60, "label": "条纹密度" },
    "flow": { "type": "float", "default": 0.6, "min": 0, "max": 3, "label": "流动速度" },
    "c1": { "type": "color", "default": "#ff4d12", "label": "渐变色 1" },
    "c2": { "type": "color", "default": "#ffd23f", "label": "渐变色 2" },
    "c3": { "type": "color", "default": "#ff3d7f", "label": "渐变色 3" },
    "dim": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "字外压暗" },
    "shadow": { "type": "float", "default": 6, "min": 0, "max": 30, "label": "投影距离（像素）" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.1, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "flow": { "to": "bar", "amount": 1.2 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/game-show 与 silkscreen-poster：图案填充字", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（印刷与平面设计）：“镂空字”是在一张纸上把字刻掉，透过字的形状看到下面的图案纸；
// 动态版本把下面的图案换成流动的条纹和渐变，字外的部分压暗以突出字形，再加一道错位的硬投影增加厚度。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float front = inkAt(uv);

  // ① 硬投影：向右下偏移 shadow 像素处如果是字，这里就在投影里（1 次采样）。
  float sh = inkAt(uv + vec2(-shadow, shadow) / uRes) * (1. - front);

  // ② 窗下的图案：斜条纹（45°，按画面高度归一）+ 三色横向渐变，随时间流动；flow 挂小节——每小节开头流得快，随后放慢。
  vec2 p = uv * vec2(uRes.x / uRes.y, 1.);
  float s = fract((p.x + p.y) * stripes * .5 - uTime * flow);
  float band = smoothstep(.45, .5, s) - smoothstep(.95, 1., s);
  float gx = fract(uv.x * .8 + uTime * flow * .1);
  vec3 grad = gx < .333 ? mix(c1, c2, gx * 3.) : gx < .666 ? mix(c2, c3, gx * 3. - 1.) : mix(c3, c1, gx * 3. - 2.);
  vec3 pattern = mix(grad, grad * .55, band);

  // ③ 合成：字外压暗 → 投影（近黑）→ 字内图案。
  vec3 c = src * (1. - dim);
  c = mix(c, vec3(.03), sh * .85);
  c = mix(c, pattern, front);
  return vec4(c, 1.);
}
