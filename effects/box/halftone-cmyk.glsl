/*@effect
{
  "id": "halftone-cmyk",
  "name": "CMYK 半调网点",
  "kind": "post",
  "category": "印刷与版画",
  "tags": [
    "halftone",
    "comic",
    "pop art",
    "print",
    "网点"
  ],
  "summary": "四色网点按不同角度排列，模拟胶印与波普漫画。",
  "when": "流行艺术、漫画、复古广告。",
  "avoid": "大量小字的界面镜头（网点会吃掉笔画）。",
  "params": {
    "cell": {
      "type": "float",
      "default": 9,
      "min": 3,
      "max": 28,
      "label": "网点尺寸(px)"
    },
    "softness": {
      "type": "float",
      "default": 0.9,
      "min": 0.2,
      "max": 2,
      "label": "边缘柔和"
    }
  },
  "bindings": {
    "cell": {
      "to": "kick",
      "amount": 3
    }
  },
  "inspiredBy": [
    {
      "source": "shotcraft",
      "ref": "media-styles halftone",
      "note": "自写实现"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
float dotScreen(vec2 uv, float angle, float amount) {
  vec2 p = fxRot(angle) * (uv * uRes);
  vec2 cellPos = (fract(p / cell) - .5) * cell;
  float r = sqrt(clamp(amount, 0., 1.)) * cell * .62;
  return 1. - smoothstep(r - softness, r + softness, length(cellPos));
}
vec4 effect(vec2 uv) {
  vec3 rgb = srcTex(uv).rgb;
  float k = 1. - max(rgb.r, max(rgb.g, rgb.b));
  vec3 cmy = (1. - rgb - k) / max(1. - k, 1e-3);
  float c = dotScreen(uv, .26, cmy.r), m = dotScreen(uv, 1.3, cmy.g), y = dotScreen(uv, 0., cmy.b), kk = dotScreen(uv, .78, k);
  vec3 col = vec3(1. - c * .9, 1. - m * .9, 1. - y * .9) * (1. - kk * .92);
  return vec4(col * vec3(.98, .96, .92), 1.);
}
