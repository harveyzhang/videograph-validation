/*@effect
{
  "id": "newsprint-dither",
  "name": "报纸点阵",
  "kind": "post",
  "category": "印刷与版画",
  "tags": [
    "newsprint",
    "dither",
    "bayer",
    "newspaper",
    "报纸"
  ],
  "summary": "Bayer 有序抖动成 1-bit，叠加纸纹与印刷不均。",
  "when": "新闻、宣言、复古科技、低保真。",
  "avoid": "暗部细节重要的镜头。",
  "params": {
    "scale": {
      "type": "float",
      "default": 2,
      "min": 1,
      "max": 6,
      "label": "点阵放大"
    },
    "ink": {
      "type": "color",
      "default": "#161616",
      "label": "墨色"
    },
    "paper": {
      "type": "color",
      "default": "#e8e3d6",
      "label": "纸色"
    },
    "contrast": {
      "type": "float",
      "default": 1.15,
      "min": 0.6,
      "max": 2,
      "label": "对比"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "shotcraft",
      "ref": "media-styles dither",
      "note": "自写实现"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec2 cellUv = floor(uv * uRes / scale) * scale / uRes;
  float l = (fxLuma(srcTex(cellUv).rgb) - .5) * contrast + .5;
  float t = fxBayer4(uv * uRes / scale);
  float on = step(t, l);
  float fiber = fxFbm(uv * vec2(400., 60.)) * .08;
  return vec4(mix(ink, paper * (1. - fiber), on), 1.);
}
