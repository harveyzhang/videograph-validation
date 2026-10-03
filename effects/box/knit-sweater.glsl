/*@effect
{
  "id": "knit-sweater",
  "name": "毛线编织",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["knit", "sweater", "yarn", "wool", "cozy", "毛衣", "编织", "毛线", "温暖"],
  "summary": "画面变成一件毛衣的编织纹：一列列 V 形的针圈，每个针圈是一段蓬松的毛线、带纤维毛刺和柔和阴影，颜色限制在几种毛线色；鼓点时毛线微微鼓起。",
  "when": "冬季/圣诞/节日、温暖舒适的家居与生活方式品牌、手作与可爱题材。",
  "avoid": "需要细节与清晰文字的镜头；夏季与科技题材。",
  "params": {
    "size": { "type": "float", "default": 0.03, "min": 0.01, "max": 0.08, "label": "针圈大小（画面高度比例）" },
    "levels": { "type": "float", "default": 5, "min": 2, "max": 12, "label": "毛线色级数" },
    "fuzz": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "毛绒感" },
    "puff": { "type": "float", "default": 0, "min": 0, "max": 0.3, "label": "鼓点鼓起（通常由节拍驱动）" }
  },
  "bindings": { "puff": { "to": "kick", "amount": 0.12 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/paper-popup 与 crayon-book：手作质感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（平针编织）：正面看到的是一列列竖着的 V 字，每个 V 由左右两条斜的“腿”组成，是同一个线圈；
// 毛线由许多纤维捻成，边缘有毛刺；提花毛衣的图案就是每个 V 换一种颜色。

vec4 effect(vec2 uv) {
  float spx = size * uRes.y;
  vec2 g = vec2(uv.x * uRes.x / (spx * .8), uv.y * uRes.y / (spx * .6));
  vec2 id = floor(g), f = fract(g);
  // ① 针圈颜色：中心取色，量化到有限线色
  vec3 col = srcTex((id + .5) * vec2(spx * .8, spx * .6) / uRes).rgb;
  col = floor(col * levels + .5) / levels;
  // ② V 字的两条腿：左腿从左上到中下，右腿从右上到中下；每条腿是一个椭圆形的线圈截面
  vec2 q = f - vec2(.5, 0.);
  float leg = .26 * (1. + puff);
  vec2 lq = fxRot(-.6) * (q - vec2(-.2, .5));
  vec2 rq = fxRot(.6) * (q - vec2(.2, .5));
  float dl = length(lq / vec2(leg, .58)), dr = length(rq / vec2(leg, .58));
  float lm = smoothstep(1., .8, dl), rm = smoothstep(1., .8, dr);
  // ③ 毛线体积：截面中心亮、边缘暗；捻线纹沿线方向；毛刺（边缘噪声）
  float shadeL = 1. - dl * .55, shadeR = 1. - dr * .55;
  float twistL = .85 + .15 * sin(lq.y * 30. + lq.x * 12.), twistR = .85 + .15 * sin(rq.y * 30. - rq.x * 12.);
  float fz = (fxNoise(uv * uRes * .7) - .5) * fuzz;
  lm = clamp(lm + fz * smoothstep(.7, 1., dl) * 2., 0., 1.);
  rm = clamp(rm + fz * smoothstep(.7, 1., dr) * 2., 0., 1.);
  // ④ 合成：针圈之间的缝隙是深色（看到下面一层），两条腿盖上去
  vec3 c = col * .25;
  c = mix(c, col * shadeL * twistL, lm);
  c = mix(c, col * shadeR * twistR * 1.05, rm);
  return vec4(c, 1.);
}
