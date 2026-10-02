/*@effect
{
  "id": "watercolor",
  "name": "水彩晕染",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": [
    "watercolor",
    "paint",
    "wash",
    "paper",
    "水彩"
  ],
  "summary": "颜色被纸面吸收后向外晕开，边缘积色变深，纸纹颗粒透出。",
  "when": "温柔叙事、节日祝福、儿童与自然题材。",
  "avoid": "高对比科技感、需要锐利文字的镜头。",
  "params": {
    "bleed": {
      "type": "float",
      "default": 0.006,
      "min": 0,
      "max": 0.02,
      "label": "晕染"
    },
    "edgeDarken": {
      "type": "float",
      "default": 0.55,
      "min": 0,
      "max": 1.5,
      "label": "边缘积色"
    },
    "granulation": {
      "type": "float",
      "default": 0.35,
      "min": 0,
      "max": 1,
      "label": "颗粒"
    },
    "paper": {
      "type": "color",
      "default": "#f7f1e3",
      "label": "纸色"
    }
  },
  "bindings": {
    "bleed": {
      "to": "bar",
      "amount": 0.004
    }
  },
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/watercolor",
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
  vec2 warp = (vec2(fxFbm(uv * 7. + uTime * .05), fxFbm(uv * 7. - 3.1)) - .5) * bleed * 2.;
  vec3 c = vec3(0.);
  for (int i = 0; i < 6; i++) { float a = float(i) * 1.047; c += srcTex(uv + warp + vec2(cos(a), sin(a)) * bleed).rgb; }
  c /= 6.;
  float levels = 6.;
  c = floor(c * levels + fxNoise(uv * 30.) * .6) / levels;
  float edge = fxSobel(uv + warp);
  c *= 1. - clamp(edge * edgeDarken, 0., .6);
  float grain = (fxFbm(uv * uRes * .08) - .5) * granulation;
  vec3 pigment = 1. - (1. - c) * (1. + grain);
  return vec4(paper * mix(vec3(1.), pigment, .92), 1.);
}
