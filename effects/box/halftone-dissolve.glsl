/*@effect
{
  "id": "halftone-dissolve",
  "name": "网点溶解转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["halftone", "dots", "pop art", "dissolve", "comic", "网点", "波普", "溶解", "漫画转场"],
  "summary": "下一个镜头以一片规则的圆形网点出现：网点从斜对角一侧开始长大、相互连成整片，把上一个镜头“吃掉”；网点边缘带一点印刷油墨的颗粒。",
  "when": "波普/漫画/复古印刷风格、综艺与潮流、杂志感的段落衔接。",
  "avoid": "写实电影感的衔接。时长建议 0.6–1.2 秒。",
  "params": {
    "spacing": { "type": "float", "default": 0.035, "min": 0.008, "max": 0.1, "label": "网点间距（画面高度比例）" },
    "angle": { "type": "float", "default": 0.785, "min": 0, "max": 1.5708, "label": "网格角度（弧度）" },
    "sweep": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "从一侧扫过的程度（0 = 全屏同时长大）" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/halftone-dossier：网点", "note": "只参考风格名称与观感描述，代码为本项目自写；与 gl-transitions 的 PolkaDotsCurtain 不同：网点按扫描前沿大小渐变且带油墨颗粒" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（印刷的半调网点）：网点越大，颜色越“满”，当网点大到相互接触，就连成一片实色。
// 转场里让“新镜头的网点”从一侧开始长大，逐渐盖满画面。

vec4 transition(vec2 uv) {
  vec3 a = getFromColor(uv).rgb, b = getToColor(uv).rgb;
  vec2 p = uv * vec2(ratio, 1.);
  // ① 旋转网格，求到最近网点中心的距离
  vec2 g = fxRot(angle) * p / spacing;
  vec2 f = fract(g) - .5;
  float d = length(f);
  // ② 网点半径：随进度增长，并沿对角线方向错开（扫描前沿）
  float diag = (uv.x + (1. - uv.y)) * .5;
  float local = clamp(progress * (1. + sweep) - diag * sweep, 0., 1.);
  float r = local * .85;                                  // 0.707 时网点刚好连成片
  // ③ 油墨颗粒：边缘不完全圆
  float grain = (fxNoise(uv * uRes * .4) - .5) * .06;
  float m = smoothstep(r + .02, r - .02, d + grain);
  return vec4(mix(a, b, m), 1.);
}
