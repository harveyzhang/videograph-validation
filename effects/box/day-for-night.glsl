/*@effect
{
  "id": "day-for-night",
  "name": "日转夜",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["day for night", "moonlight", "night grade", "blue hour", "american night", "日转夜", "月光", "夜景调色", "美式夜景"],
  "summary": "把白天拍的画面调成月光下的夜景：整体大幅压暗、偏冷蓝、饱和度降低，天空（画面上部的亮处）压得更暗，只留少量高光像月光反射；可选星点。",
  "when": "需要夜景但只有白天素材、悬疑与潜行、冷峻孤独的情绪、梦境。",
  "avoid": "画面里有明显的太阳或强烈投影（会露馅）；本来就是夜景的画面。",
  "params": {
    "darkness": { "type": "float", "default": 0.6, "min": 0, "max": 0.9, "label": "压暗程度" },
    "moon": { "type": "color", "default": "#7fa6ff", "label": "月光色" },
    "skyDarken": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "天空额外压暗" },
    "stars": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "星点" },
    "glint": { "type": "float", "default": 0, "min": 0, "max": 0.5, "label": "高光闪烁（通常由节拍驱动）" }
  },
  "bindings": { "glint": { "to": "beat", "amount": 0.15 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：调色", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（好莱坞的“美式夜景”）：在白天欠曝两三档拍摄，冲印时整体偏蓝、降饱和，天空压暗——
// 观众会把它读成月光下的夜晚。人眼在暗光下靠视杆细胞看东西，颜色感很弱且偏蓝（浦肯野效应），所以夜景要冷、要灰。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float l = fxLuma(src);
  // ① 欠曝 + 降饱和：颜色向灰靠拢，再整体压暗（伽马变暗，暗部压得更狠）
  vec3 c = mix(vec3(l), src, .35);
  c = pow(c, vec3(1. + darkness * 1.5)) * (1. - darkness * .5);
  // ② 月光：整体乘上冷蓝色，亮部保留一点更亮的蓝白（月光反射）
  c *= mix(vec3(1.), moon * 1.2, .8);
  c += moon * smoothstep(.75, 1., l) * (.15 + glint);
  // ③ 天空：画面上部且原本很亮的地方额外压暗（白天的天空在夜里应该是暗的）
  float sky = smoothstep(.45, .9, uv.y) * smoothstep(.45, .8, l);
  c *= 1. - skyDarken * sky * .8;
  // ④ 星点：只在被压暗的天空区域出现（静止，个别缓慢闪烁）
  vec2 g = floor(uv * uRes / 3.);
  float st = step(.9965, fxHash(g)) * sky * stars;
  c += vec3(.8, .85, 1.) * st * (.6 + .4 * sin(uTime * 2. + fxHash(g + 1.) * 20.));
  return vec4(c, 1.);
}
