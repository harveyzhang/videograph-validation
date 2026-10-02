/*@effect
{
  "id": "one-line-sketch",
  "name": "一笔线稿",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": [
    "line art",
    "one line",
    "sketch",
    "minimal",
    "线稿"
  ],
  "summary": "只保留轮廓线，白底黑线（或反相），线条随时间轻微抖动。",
  "when": "极简、概念说明、白板讲解。",
  "avoid": "轮廓不清的画面。",
  "params": {
    "threshold": {
      "type": "float",
      "default": 0.22,
      "min": 0.05,
      "max": 0.8,
      "label": "线条阈值"
    },
    "invert": {
      "type": "bool",
      "default": false,
      "label": "黑底白线"
    },
    "ink": {
      "type": "color",
      "default": "#1e1e24",
      "label": "线色"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/one-line",
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
  vec2 boil = (vec2(fxNoise(uv * 25. + floor(uTime * 6.)), fxNoise(uv * 25. - floor(uTime * 6.) * 1.7)) - .5) * .0025;
  float e = smoothstep(threshold, threshold + .15, fxSobel(uv + boil));
  vec3 bg = invert ? vec3(.06) : vec3(.97, .96, .94);
  vec3 fg = invert ? vec3(.95) : ink;
  return vec4(mix(bg, fg, e), 1.);
}
