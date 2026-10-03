/*@effect
{
  "id": "charcoal-sketch",
  "name": "炭笔素描",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["charcoal", "sketch", "drawing", "smudge", "graphite", "炭笔", "素描", "炭精条"],
  "summary": "炭条在粗纹素描纸上排线：暗部黑得发绒、纸纹凸点留白，手指抹开的灰调，亮部用橡皮擦出高光，轮廓重压加深。",
  "when": "人物与静物、回忆/独白、艺术家与手作题材、黑白叙事段落、电影分镜感。",
  "avoid": "需要颜色的镜头；整体很暗的画面会成满版黑（先提亮）；与其他线稿效果连用。",
  "params": {
    "paper": { "type": "color", "default": "#ece6da", "label": "纸色" },
    "darkness": { "type": "float", "default": 1, "min": 0.4, "max": 1.6, "label": "下笔力度" },
    "tooth": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "纸纹粗糙度" },
    "smudge": { "type": "float", "default": 0.004, "min": 0, "max": 0.015, "label": "手抹程度" },
    "hatch": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "排线可见度" }
  },
  "bindings": { "smudge": { "to": "bar", "amount": 0.004 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/urban-sketch 与 one-line：手绘线稿观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：炭条是很软的碳粉棒。在有“牙”（凹凸纹理）的素描纸上划过时，炭粉只附着在纸纹凸起处，轻压时凹处留白；
// 画家先斜着排线铺调子，再用手指/纸擦笔把炭粉抹开成柔和的灰，最后用可塑橡皮擦出高光、用力压实轮廓。

vec4 effect(vec2 uv) {
  // ① 手抹：手指沿右下方向把炭粉推开 → 沿该方向取 4 次平均（smudge 挂小节：每小节开头抹得更开，随后收紧）。
  vec2 sd = normalize(vec2(1., -.6)) * smudge;
  float tone = 0.;
  for (int i = 0; i < 4; i++) tone += fxLuma(srcTex(uv - sd * float(i) * .5).rgb);
  tone /= 4.;
  float dark = clamp((1. - tone) * darkness, 0., 1.);

  // ② 纸纹：素描纸的“牙”是不规则的凸点 + 一点横向纤维，静止不动。
  vec2 p = uv * uRes;
  float t = fxNoise(p * .45) * .6 + fxNoise(p * 1.3 + 9.) * .4;

  // ③ 排线：沿约 60° 斜着一笔一笔铺调子，每笔有入笔/收笔的粗细变化；越暗处排线越密（阈值越低）。
  float a = 1.05;
  float ln = dot(p, vec2(cos(a), sin(a))) / 4.5;
  float stroke = .5 + .5 * sin(ln * 6.2832 + fxNoise(p * .03) * 4.);
  stroke *= .7 + .3 * fxNoise(vec2(floor(ln), dot(p, vec2(-sin(a), cos(a))) * .02));

  // ④ 上炭：炭粉覆盖量 = 暗度 − 纸纹凸点阻挡 + 排线纹理；用 smoothstep 让边缘发绒（炭粉颗粒感）。
  float cover = dark + (stroke - .5) * .35 * hatch - (t - .5) * tooth * .6;
  cover = smoothstep(.15, .85, cover);

  // ⑤ 轮廓重压与橡皮高光：边缘（9 次采样）处压得更黑；原图最亮处被擦回纸色（带一点擦痕方向）。
  float edge = smoothstep(.12, .45, fxSobel(uv));
  cover = max(cover, edge * .85 * darkness);
  float lift = smoothstep(.82, .95, fxLuma(srcTex(uv).rgb));
  cover *= 1. - lift * .9;

  // ⑥ 成色：炭黑不是纯黑，略带冷灰；纸色保留纤维明暗。
  vec3 charcoal = vec3(.09, .09, .1);
  vec3 c = mix(paper * (.95 + .05 * t), charcoal, cover);
  return vec4(c, 1.);
}
