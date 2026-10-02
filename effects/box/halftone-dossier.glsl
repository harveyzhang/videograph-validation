/*@effect
{
  "id": "halftone-dossier",
  "name": "复古半调案卷",
  "kind": "post",
  "category": "印刷与版画",
  "tags": [
    "halftone",
    "dossier",
    "newspaper",
    "mono",
    "档案"
  ],
  "summary": "单色圆点半调 + 发黄纸张 + 轻微压印，像旧报纸或机密档案。",
  "when": "调查、档案、历史回顾、悬疑。",
  "avoid": "色彩是主要信息的镜头。",
  "params": {
    "cell": {
      "type": "float",
      "default": 6,
      "min": 3,
      "max": 18,
      "label": "网点尺寸(px)"
    },
    "ink": {
      "type": "color",
      "default": "#1d1a17",
      "label": "油墨"
    },
    "paper": {
      "type": "color",
      "default": "#e9dfc7",
      "label": "纸色"
    },
    "angle": {
      "type": "float",
      "default": 0.78,
      "min": 0,
      "max": 1.57,
      "label": "网角"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/halftone-dossier",
      "note": "只参考风格名称与观感描述，代码为本项目自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  float lum = fxLuma(srcTex(uv).rgb);
  vec2 p = fxRot(angle) * (uv * uRes);
  vec2 cp = (fract(p / cell) - .5) * cell;
  float r = sqrt(1. - lum) * cell * .66;
  float dotMask = 1. - smoothstep(r - .8, r + .8, length(cp));
  float stain = fxFbm(uv * 3.) * .18 + fxFbm(uv * 40.) * .06;
  vec3 base = paper * (1. - stain);
  return vec4(mix(base, ink, dotMask * .92), 1.);
}
