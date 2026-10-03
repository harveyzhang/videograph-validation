/*@effect
{
  "id": "beat-mirror-flip",
  "name": "拍点镜像翻转",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["mirror", "flip", "beat", "symmetry", "kaleido", "镜像", "翻转", "对称", "卡点"],
  "summary": "每拍切换一种镜像方式：原画 → 左右对称 → 上下对称 → 四向对称，循环往复；切换落在拍点上，拍内保持。鼓点时对称轴附近闪一道细光。",
  "when": "电子/嘻哈/时尚卡点、Logo 与图形的节奏变化、迷幻与对称美学。",
  "avoid": "有文字的镜头（镜像会把字反过来）；需要稳定叙事的段落。",
  "params": {
    "modes": { "type": "float", "default": 4, "min": 2, "max": 4, "label": "循环的模式数（2 = 只在原画/左右对称间切换）" },
    "seam": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "对称轴闪光（通常由节拍驱动）" },
    "seamColor": { "type": "color", "default": "#ffffff", "label": "对称轴颜色" }
  },
  "bindings": { "seam": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：镜像切换", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（剪辑软件的镜像效果 + 卡点）：每个拍点切换一次镜像——画面突然变成对称图形，结构变了但颜色与内容延续，
// 跟音乐咬合。和 mirror-split（固定对称）不同：这里按拍循环切换模式。

vec4 effect(vec2 uv) {
  float m = mod(floor(uTime * 2.), floor(modes + .5));
  vec2 q = uv;
  // ① 模式：0 原画；1 左右对称（右半是左半的镜像）；2 上下对称；3 四向对称
  if (m == 1. || m == 3.) q.x = .5 - abs(uv.x - .5);
  if (m == 2. || m == 3.) q.y = .5 + abs(uv.y - .5);
  vec3 c = srcTex(q).rgb;
  // ② 对称轴闪光（鼓点）
  float px = 1.5 / uRes.x, py = 1.5 / uRes.y;
  float axis = 0.;
  if (m == 1. || m == 3.) axis = max(axis, smoothstep(px * 2., 0., abs(uv.x - .5)));
  if (m == 2. || m == 3.) axis = max(axis, smoothstep(py * 2., 0., abs(uv.y - .5)));
  c = mix(c, seamColor, axis * clamp(seam, 0., 1.));
  return vec4(c, 1.);
}
