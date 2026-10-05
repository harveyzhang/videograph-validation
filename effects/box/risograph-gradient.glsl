/*@effect
{
  "id": "risograph-gradient",
  "name": "渐变网点海报",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["gradient halftone", "poster", "two tone", "dither gradient", "modern print", "渐变网点", "海报", "双色", "现代印刷"],
  "summary": "现代海报风：画面明暗变成从一种颜色到另一种颜色的网点渐变（网点大小表现明暗），背景是平涂的底色，网点角度与大小可调；网点随拍轻轻呼吸。",
  "when": "现代海报/音乐节/展览视觉、潮牌与设计感品牌、标题背景、抽象化的人像与风景。",
  "avoid": "需要写实细节的镜头；与 halftone-cmyk（四色网点）、newsprint-dither（报纸点阵）选一种即可——这个是两色渐变 + 大网点的设计海报风。",
  "params": {
    "inkA": { "type": "color", "default": "#ff5233", "label": "网点颜色（暗部）" },
    "inkB": { "type": "color", "default": "#2f3cff", "label": "网点颜色（中间调）" },
    "paper": { "type": "color", "default": "#f3ede0", "label": "底色" },
    "cell": { "type": "float", "default": 0.02, "min": 0.006, "max": 0.06, "label": "网点间距（画面高度比例）" },
    "angle": { "type": "float", "default": 0.4, "min": 0, "max": 1.5708, "label": "网点角度" },
    "breath": { "type": "float", "default": 0, "min": 0, "max": 0.2, "label": "节拍呼吸（通常由节拍驱动）" }
  },
  "bindings": { "breath": { "to": "beat", "amount": 0.08 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/risograph 与 swiss-motion：现代海报网点", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（当代平面设计）：用大网点做明暗，网点的颜色还沿着明暗在两种专色之间过渡——暗处是浓重的第一色大点，
// 中间调是第二色的中等点，亮处只剩纸色。网点很大、很规则，本身就是装饰。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 网格：旋转后的网点格，取格中心的亮度（网点大小由它决定）
  float cpx = cell * uRes.y;
  vec2 g = fxRot(angle) * (uv * uRes) / cpx;
  vec2 id = floor(g), f = fract(g) - .5;
  vec2 center = (fxRot(-angle) * ((id + .5) * cpx)) / uRes;
  float l = fxLuma(srcTex(center).rgb);
  // ② 网点半径：越暗越大（√ 让面积与明暗成比例），呼吸
  float r = sqrt(clamp(1. - l, 0., 1.)) * .62 * (1. + breath);
  float dotM = smoothstep(r + .04, r - .04, length(f));
  // ③ 网点颜色：暗部 inkA、中间调 inkB
  vec3 ink = mix(inkA, inkB, smoothstep(.25, .65, l));
  return vec4(mix(paper, ink, dotM), 1.);
}
