/*@effect
{
  "id": "water-reflection",
  "name": "水面倒影",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["reflection", "mirror lake", "water", "ripple", "symmetry", "倒影", "水面", "镜湖", "涟漪"],
  "summary": "从画面中某条水平线开始，下方变成上方景物的水面倒影：倒影被细碎波纹扰动、偏暗偏冷，近处波纹更大；每一拍水面泛起一圈涟漪。",
  "when": "风景、城市夜景、人物站在水边的意象、宁静抒情、对称构图。",
  "avoid": "地平线以下有重要内容的镜头（会被倒影覆盖）；俯拍画面。",
  "params": {
    "horizon": { "type": "float", "default": 0.42, "min": 0.1, "max": 0.9, "label": "水面高度（从底部算）" },
    "ripple": { "type": "float", "default": 0.006, "min": 0, "max": 0.03, "label": "波纹强度" },
    "darken": { "type": "float", "default": 0.35, "min": 0, "max": 0.9, "label": "倒影压暗" },
    "drop": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "节拍涟漪（通常由节拍驱动）" },
    "waterTint": { "type": "color", "default": "#4a6a8a", "label": "水色" }
  },
  "bindings": { "drop": { "to": "beat", "amount": 0.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：镜像与对称", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：平静的水面像一面镜子，把岸上的景物上下翻转映出来；水面的细小波纹让倒影横向抖碎，离观者越近（画面越靠下）波纹看起来越大；
// 水会吸收一部分光并带上自身颜色，所以倒影比实景暗、偏冷。

vec4 effect(vec2 uv) {
  if (uv.y >= horizon) return vec4(srcTex(uv).rgb, 1.);
  // ① 镜像：水面以下 y 对应水面以上的 2h - y
  float depth = (horizon - uv.y) / max(horizon, .01);          // 0 水面线 → 1 画面底
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  // ② 波纹：横向位移，近处（depth 大）波长更长、振幅更大；节拍涟漪 = 从中心扩散的一圈额外起伏
  float t = uTime;
  float w = sin(uv.y * 260. / (.4 + depth) + t * 3.) * .6 + (fxNoise(vec2(uv.x * 8., uv.y * 120. / (.4 + depth) - t)) - .5);
  vec2 rp = (uv - vec2(.5, horizon * .5)) * asp;
  float ring = sin(length(rp) * 60. - uBeat * 18.) * exp(-abs(length(rp) - uBeat * .5) * 12.) * drop;
  float off = (w * (.3 + depth) + ring * 2.) * ripple;
  vec2 m = vec2(uv.x + off, 2. * horizon - uv.y + off * .3);
  vec3 c = srcTex(m).rgb;
  // ③ 水的吸收与颜色：越往下越暗越偏水色；水面线处一条细亮线（天光反射）
  c = mix(c * (1. - darken), waterTint * .5, depth * .35);
  c += smoothstep(.006, 0., horizon - uv.y) * .15;
  return vec4(c, 1.);
}
