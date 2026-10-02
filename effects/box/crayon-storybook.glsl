/*@effect
{
  "id": "crayon-storybook",
  "name": "蜡笔绘本",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": [
    "crayon",
    "storybook",
    "kids",
    "pastel",
    "蜡笔"
  ],
  "summary": "颜色变成斜向蜡笔笔触，纸纹凹处留白，轮廓线抖动。",
  "when": "儿童、科普、温暖品牌、节日。",
  "avoid": "严肃商务与数据展示。",
  "params": {
    "stroke": {
      "type": "float",
      "default": 0.6,
      "min": 0,
      "max": 1,
      "label": "笔触强度"
    },
    "outline": {
      "type": "float",
      "default": 0.8,
      "min": 0,
      "max": 2,
      "label": "轮廓"
    },
    "paper": {
      "type": "color",
      "default": "#fbf5e8",
      "label": "纸色"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/crayon",
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
  vec2 jitter = (vec2(fxNoise(uv * 80. + floor(uTime * 8.)), fxNoise(uv * 80. - floor(uTime * 8.))) - .5) * .003;
  vec3 c = srcTex(uv + jitter).rgb;
  vec2 p = fxRot(.7) * (uv * uRes);
  float strokes = fxNoise(vec2(p.x * .9, p.y * .04));
  float tooth = step(.35, fxNoise(uv * uRes * .6));
  float coverage = clamp(mix(1., strokes * 1.4, stroke) * mix(1., tooth, stroke * .7), 0., 1.);
  vec3 col = mix(paper, c * 1.08, coverage);
  float e = fxSobel(uv + jitter * 2.);
  col = mix(col, vec3(.15, .12, .14), clamp(e * outline, 0., 1.) * .8);
  return vec4(col, 1.);
}
