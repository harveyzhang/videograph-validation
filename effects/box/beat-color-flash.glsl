/*@effect
{
  "id": "beat-color-flash",
  "name": "拍点色彩冲击",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["color flash", "beat", "tint pulse", "impact", "卡点", "色彩冲击", "染色", "节拍"],
  "summary": "每个鼓点让画面瞬间被染上一层强调色（暗部染得多、亮部保留），然后在半拍内褪回原色；颜色每小节换一次。整体亮度变化很小，不是白闪。",
  "when": "卡点剪辑、副歌重音、运动与舞蹈、产品亮相的节奏强调。",
  "avoid": "需要准确色彩的镜头；安静段落。",
  "params": {
    "hit": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "染色强度（通常由节拍驱动）" },
    "colorA": { "type": "color", "default": "#ff2a6d", "label": "颜色 A" },
    "colorB": { "type": "color", "default": "#2ad5ff", "label": "颜色 B（隔小节交替）" },
    "keepLights": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "保留亮部" }
  },
  "bindings": { "hit": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：色彩冲击", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（MV 剪辑）：在重拍上叠一层纯色、用“颜色”或“叠加”混合模式，持续一两帧后淡出，画面像被音乐染了一下。
// 安全：用色相替换而不是加亮，亮部基本保留，整体平均亮度变化很小（远低于光敏阈值）。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float l = fxLuma(src);
  // ① 本小节的颜色：小节序号奇偶交替（小节序号 = 时间 − 小节相位；只用作切换，不影响时机）
  float barN = floor((uTime / 2.) - uBar + .5);
  vec3 tint = mod(barN, 2.) < 1. ? colorA : colorB;
  // ② 染色：用颜色的色度替换画面色度，亮度保持原样（“颜色”混合模式），暗部多染、亮部少染
  vec3 colored = tint / max(fxLuma(tint), .05) * l;
  float k = clamp(hit, 0., 1.) * mix(1., 1. - l, keepLights);
  return vec4(mix(src, clamp(colored, 0., 1.), k), 1.);
}
