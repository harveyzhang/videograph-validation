/*@effect
{
  "id": "vaporwave-grade",
  "name": "蒸汽波调色",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["vaporwave", "synthwave", "outrun", "pink cyan", "retro 80s", "蒸汽波", "合成器浪潮", "粉青", "复古"],
  "summary": "粉紫与青蓝的蒸汽波配色：暗部推向深紫、亮部推向粉橙、中间调带青，叠一层轻微的横向扫描线与发光，整体有 80 年代录像带的梦幻感；每拍色调轻轻摆动。",
  "when": "蒸汽波/合成器浪潮/City Pop、夜景与霓虹、复古游戏、梦幻怀旧的 MV。",
  "avoid": "自然写实与纪录题材；肤色要求真实的人像。",
  "params": {
    "amount": { "type": "float", "default": 0.85, "min": 0, "max": 1, "label": "强度" },
    "pink": { "type": "color", "default": "#ff6ec7", "label": "粉色（亮部）" },
    "cyan": { "type": "color", "default": "#3de1ff", "label": "青色（中间调）" },
    "purple": { "type": "color", "default": "#2a0a5e", "label": "紫色（暗部）" },
    "scan": { "type": "float", "default": 0.12, "min": 0, "max": 0.5, "label": "扫描线" },
    "sway": { "type": "float", "default": 0, "min": 0, "max": 0.3, "label": "色调摆动（通常由节拍驱动）" }
  },
  "bindings": { "sway": { "to": "beat", "amount": 0.12 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/cel-anime-80s：80 年代霓虹配色", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（网络亚文化“蒸汽波”）：把 80 年代广告、录像带画面重新调成夸张的粉色与青色，加上扫描线与柔光——
// 一种被理想化的、霓虹色的怀旧。调色思路是“三向分离”：暗部紫、中间青、亮部粉。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float l = fxLuma(src);
  // ① 三向分离：按亮度在 紫 → 青 → 粉 之间取目标色；sway 挂每拍让中间调的位置摆动一下
  float m = .45 + sway;
  vec3 target = l < m ? mix(purple, cyan, smoothstep(0., m, l)) : mix(cyan, pink, smoothstep(m, 1., l));
  // ② 保留一部分原色彩差异（让画面不至于完全单调），亮度按目标色重新分配
  vec3 c = mix(src, target * (.6 + .7 * l) + (src - l) * .3, amount);
  // ③ 柔光：亮部向外泛一点（4 次采样）
  vec2 o = 3. / uRes;
  vec3 bl = (srcTex(uv + vec2(o.x, 0.)).rgb + srcTex(uv - vec2(o.x, 0.)).rgb + srcTex(uv + vec2(0., o.y)).rgb + srcTex(uv - vec2(0., o.y)).rgb) * .25;
  c += max(bl - .6, 0.) * pink * .6 * amount;
  // ④ 扫描线
  c *= 1. - scan * (.5 + .5 * sin(uv.y * uRes.y * 3.1416));
  return vec4(c, 1.);
}
