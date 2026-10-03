/*@effect
{
  "id": "beat-slice-shuffle",
  "name": "拍点切片洗牌",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["slice", "shuffle", "beat", "rearrange", "jump cut feel", "切片", "洗牌", "错位", "卡点"],
  "summary": "画面被切成几条横带，每个拍点横带的排列顺序被打乱重组（像把一张海报切条后重新拼），拍内保持；鼓点那一下各条额外左右错开，随后归位。",
  "when": "潮流/电子/嘻哈卡点、时装与杂志感、标题与 Logo 的节奏变化、转场前的蓄力。",
  "avoid": "需要连续阅读的画面；对“画面被打乱”敏感的叙事镜头。",
  "params": {
    "bands": { "type": "float", "default": 6, "min": 2, "max": 20, "label": "横带数" },
    "chaos": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "打乱比例" },
    "shift": { "type": "float", "default": 0, "min": 0, "max": 0.2, "label": "鼓点错开（通常由节拍驱动）" },
    "gap": { "type": "float", "default": 0.003, "min": 0, "max": 0.02, "label": "带缝" },
    "gapColor": { "type": "color", "default": "#0a0a0b", "label": "带缝颜色" }
  },
  "bindings": { "shift": { "to": "kick", "amount": 0.06 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/swiss-motion：切片拼贴", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（拼贴与剪辑）：把画面裁成横条，每一拍重新排列一次——观众看到的是同一张画面被不断“洗牌”，
// 结构在变、内容不变，非常适合卡点。每拍内排列固定（不会抖），换拍时整体跳变。

vec4 effect(vec2 uv) {
  float n = floor(bands + .5);
  float k = floor(uv.y * n);
  float fy = fract(uv.y * n);
  // ① 本拍的排列：每条以 chaos 概率与一条随机的条交换（用拍号做种子；拍内固定）
  float beatN = floor(uTime * 2.);
  float src = k;
  if (fxHash(vec2(k, beatN)) < chaos) src = floor(fxHash(vec2(k + 7., beatN)) * n);
  // ② 鼓点错开：每条按自己的方向左右偏移（shift 挂 kick）
  float dx = (fxHash(vec2(k, beatN + 3.)) - .5) * 2. * shift;
  vec2 q = vec2(uv.x + dx, (src + fy) / n);
  vec3 c = srcTex(q).rgb;
  // ③ 带缝
  float g = gap * n;
  float inGap = step(fy, g) + step(1. - g, fy);
  return vec4(mix(c, gapColor, min(inGap, 1.)), 1.);
}
