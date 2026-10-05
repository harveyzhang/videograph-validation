/*@effect
{
  "id": "beat-vignette-pump",
  "name": "拍点暗角收缩",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["vignette", "pump", "beat", "focus", "tunnel", "暗角", "收缩", "聚焦", "卡点"],
  "summary": "每个鼓点四周的暗角猛地向中心收紧（像视线被音乐压缩），然后随拍内衰减慢慢放开；暗角可带颜色，形状可圆可方。整体亮度变化温和，不是闪烁。",
  "when": "低音很重的段落、紧张与压迫感、聚焦主体的强调、电子乐与嘻哈。",
  "avoid": "画面四周有重要内容时；安静的段落。",
  "params": {
    "base": { "type": "float", "default": 0.25, "min": 0, "max": 1, "label": "平时暗角" },
    "pump": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点收紧（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#000000", "label": "暗角颜色" },
    "roundness": { "type": "float", "default": 1, "min": 0, "max": 1, "label": "圆度（0 = 方形）" }
  },
  "bindings": { "pump": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：暗角脉冲", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（调色/剪辑的“侧压”视觉化）：混音里底鼓会把其他声音“压”下去（sidechain pump），这里把它画出来——
// 每个鼓点暗角向中心收紧，画面四周被压暗，随后放开；视觉上与声音的“泵感”同步。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 d = (uv - .5) * vec2(uRes.x / uRes.y, 1.);
  // ① 距离：圆形与方形（切比雪夫）之间插值
  float r = mix(max(abs(d.x) / (uRes.x / uRes.y), abs(d.y)) * 1.4, length(d), roundness);
  // ② 暗角半径：鼓点时向内收（pump 挂 kick），平时由 base 决定
  float inner = mix(.9, .25, clamp(base * .5 + pump * .6, 0., .95));
  float v = smoothstep(inner, inner + .45, r) * clamp(base + pump * .7, 0., 1.);
  return vec4(mix(src, color, clamp(v, 0., 1.)), 1.);
}
