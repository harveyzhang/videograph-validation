/*@effect
{
  "id": "gradient-map",
  "name": "渐变映射",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["gradient map", "color grade", "duotone plus", "stylize", "lut", "渐变映射", "调色", "风格化", "三色调"],
  "summary": "把画面的明暗映射到一条五色渐变上（暗部 → 中暗 → 中间 → 中亮 → 高光），可做出霓虹、日落、冰川等各种统一色调；映射强度可调，鼓点时渐变整体沿明暗方向滑动一下。",
  "when": "统一整片色调的风格化镜头、音乐 MV 段落调色、品牌色画面、复古与蒸汽波。",
  "avoid": "需要真实肤色与产品色的镜头（mix 调低可保留部分原色）。",
  "params": {
    "c0": { "type": "color", "default": "#120a2a", "label": "暗部" },
    "c1": { "type": "color", "default": "#4b1f7a", "label": "中暗" },
    "c2": { "type": "color", "default": "#d1386b", "label": "中间调" },
    "c3": { "type": "color", "default": "#ff9a4a", "label": "中亮" },
    "c4": { "type": "color", "default": "#fff2c6", "label": "高光" },
    "amount": { "type": "float", "default": 0.9, "min": 0, "max": 1, "label": "映射强度" },
    "shift": { "type": "float", "default": 0, "min": -0.3, "max": 0.3, "label": "明暗滑动（通常由节拍驱动）" }
  },
  "bindings": { "shift": { "to": "kick", "amount": 0.08 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：调色", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（Photoshop/AE 的“渐变映射”调整层）：先把画面变成黑白（只剩明暗），再按明暗在一条自定义渐变上查颜色——
// 原来的色相全部被替换，但明暗结构保留，于是任何画面都能被统一成同一套配色。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 明暗：亮度 + 鼓点滑动（shift 挂 kick：鼓点时整体往亮部推一点，颜色“亮”一下）
  float l = clamp(fxLuma(src) + shift, 0., 1.);
  // ② 五色渐变查表（四段线性插值）
  float x = l * 4.;
  vec3 g = x < 1. ? mix(c0, c1, x) : x < 2. ? mix(c1, c2, x - 1.) : x < 3. ? mix(c2, c3, x - 2.) : mix(c3, c4, x - 3.);
  return vec4(mix(src, g, amount), 1.);
}
