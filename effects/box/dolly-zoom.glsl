/*@effect
{
  "id": "dolly-zoom",
  "name": "希区柯克变焦",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["dolly zoom", "vertigo effect", "zolly", "perspective", "tension", "希区柯克变焦", "眩晕镜头", "滑动变焦", "紧张"],
  "summary": "画面中心的主体大小几乎不变，周围的背景却随小节一下下“涌”向镜头或远离（透视被拉伸），制造眩晕与不安的心理冲击。",
  "when": "顿悟/震惊/恐惧的瞬间、悬疑与惊悚、人物处在压迫环境中、情绪推到顶点的副歌。",
  "avoid": "主体不在画面中心的镜头（调 centerX/centerY 对准主体）；轻松欢快的段落。",
  "params": {
    "amount": { "type": "float", "default": 0.08, "min": 0, "max": 0.5, "label": "背景拉伸量（通常由小节驱动）" },
    "core": { "type": "float", "default": 0.18, "min": 0.02, "max": 0.5, "label": "不变的主体范围（画面高度比例）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "主体中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "主体中心 Y" }
  },
  "bindings": { "amount": { "to": "bar", "amount": 0.15 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：镜头语言", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（《迷魂记》的经典镜头）：摄影机向后移动的同时把焦距推长，让主体在画面里保持同样大小——
// 于是主体不动，背景的透视却在压缩/拉伸，观众感到空间在“呼吸”。
// 二维近似：主体范围内缩放为 1，离主体越远缩放越大（背景涌向镜头），过渡平滑。

vec4 effect(vec2 uv) {
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 c = vec2(centerX, centerY);
  vec2 p = (uv - c) * asp;
  float r = length(p);
  // ① 缩放随距离增长：主体半径内 ≈ 1，向外平滑增大到 1 + amount（amount 挂小节：每小节开头涌一次再回落）
  float k = smoothstep(core, core + .6, r);
  float s = 1. + amount * k * (1. + r);
  // ② 取样点向中心收（= 画面向外放大），只影响背景
  vec2 q = p / s / asp + c;
  // ③ 背景被拉伸时附带一点径向模糊感：在拉伸方向再取一次平均（2 次采样）
  vec3 col = (srcTex(q).rgb * 2. + srcTex(c + (q - c) * (1. - amount * k * .05)).rgb) / 3.;
  return vec4(col, 1.);
}
