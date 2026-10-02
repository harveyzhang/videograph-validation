/*@effect
{
  "id": "ink-wash",
  "name": "中国水墨",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": [
    "ink wash",
    "sumi-e",
    "chinese ink",
    "calligraphy",
    "水墨"
  ],
  "summary": "灰阶墨色分层（焦浓重淡清），墨晕沿纸纤维扩散，留白处宣纸透光。",
  "when": "古诗、书法、东方叙事、留白多的空镜。",
  "avoid": "色彩信息重要或需要高饱和的镜头。",
  "params": {
    "spread": {
      "type": "float",
      "default": 0.004,
      "min": 0,
      "max": 0.015,
      "label": "墨晕"
    },
    "contrast": {
      "type": "float",
      "default": 1.4,
      "min": 0.6,
      "max": 3,
      "label": "墨色对比"
    },
    "paper": {
      "type": "color",
      "default": "#f2ecdf",
      "label": "宣纸"
    },
    "seal": {
      "type": "bool",
      "default": true,
      "label": "朱印"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/ink-wash",
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
  vec2 fiber = (vec2(fxNoise(uv * vec2(260., 40.)), fxNoise(uv * vec2(40., 260.))) - .5) * spread;
  float l = 0.;
  for (int i = 0; i < 5; i++) l += fxLuma(srcTex(uv + fiber * float(i)).rgb);
  l = clamp((l / 5. - .5) * contrast + .55, 0., 1.);
  float tones = floor(l * 5. + fxNoise(uv * 50.) * .5) / 5.;
  float ink = 1. - tones;
  ink *= .85 + fxFbm(uv * 25.) * .3;
  vec3 col = mix(paper, vec3(.07, .07, .08), clamp(ink, 0., 1.));
  if (seal) { vec2 s = uv - vec2(.9, .14); float box = step(abs(s.x), .03) * step(abs(s.y), .04); col = mix(col, vec3(.72, .12, .1), box * (.8 + fxNoise(uv * 300.) * .2)); }
  return vec4(col, 1.);
}
