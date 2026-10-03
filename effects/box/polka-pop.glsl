/*@effect
{
  "id": "polka-pop",
  "name": "波点波普",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["polka dots", "ben day", "pop art", "lichtenstein", "comic print", "波点", "本戴点", "波普艺术", "利希滕斯坦"],
  "summary": "罗伊·利希滕斯坦式的波普画：颜色压成几种饱和的原色平涂，中间调用大大的圆形本戴点表现，轮廓是粗黑描边；点阵随拍轻轻放大缩小。",
  "when": "波普/漫画/复古广告、潮牌与时尚、综艺花字背景、趣味产品展示。",
  "avoid": "写实与严肃题材；需要细节的人脸特写（点会盖住五官，调大 dotSize 反而更像漫画）。",
  "params": {
    "dotSize": { "type": "float", "default": 0.025, "min": 0.008, "max": 0.08, "label": "网点间距（画面高度比例）" },
    "outline": { "type": "float", "default": 0.7, "min": 0, "max": 1.5, "label": "黑描边" },
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 0.3, "label": "网点呼吸（通常由节拍驱动）" },
    "paper": { "type": "color", "default": "#fff8e7", "label": "纸色" }
  },
  "bindings": { "pulse": { "to": "beat", "amount": 0.12 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/halftone-dossier 与 silkscreen-poster：波普网点", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：廉价漫画印刷用“本戴点”（规则排列的同大小圆点）表现中间色，利希滕斯坦把这种印刷痕迹放大成艺术——
// 有限的几种原色（红、黄、蓝、黑、白）平涂，中间调是大圆点，轮廓是粗黑线。

vec3 popColor(vec3 c) {
  // 映射到最近的波普原色
  vec3 p[5] = vec3[5](vec3(.92, .15, .17), vec3(1., .85, .1), vec3(.12, .4, .85), vec3(1., .97, .9), vec3(.08, .08, .1));
  vec3 best = p[0]; float bd = 1e3;
  for (int i = 0; i < 5; i++) { vec3 d = c - p[i]; float dd = dot(d, d); if (dd < bd) { bd = dd; best = p[i]; } }
  return best;
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float l = fxLuma(src);
  // ① 平涂原色
  vec3 flat_ = popColor(src * 1.15);
  // ② 本戴点：中间调区域，纸色上的原色圆点（点大小固定，随拍呼吸）
  vec2 g = fxRot(.26) * (uv * uRes) / (dotSize * uRes.y);
  float d = length(fract(g) - .5);
  float r = .32 * (1. + pulse);
  float mid = smoothstep(.25, .4, l) * smoothstep(.85, .7, l);
  vec3 dotted = mix(paper, flat_, smoothstep(r + .03, r - .03, d));
  vec3 c = mix(flat_, dotted, mid);
  // ③ 粗黑描边（9 次采样的 Sobel）
  float e = smoothstep(.15, .4, fxSobel(uv)) * outline;
  c = mix(c, vec3(.06), clamp(e, 0., 1.));
  return vec4(c, 1.);
}
