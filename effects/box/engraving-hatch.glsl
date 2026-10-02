/*@effect
{
  "id": "engraving-hatch",
  "name": "铜版刻线",
  "kind": "post",
  "category": "印刷与版画",
  "tags": [
    "engraving",
    "hatching",
    "etching",
    "banknote",
    "刻线"
  ],
  "summary": "明暗用交叉排线的密度表达（亮处疏、暗处密），像钞票或博物志铜版画。",
  "when": "科学、历史、权威感、精致的文字画面。",
  "avoid": "高速运动（排线会闪烁）。",
  "params": {
    "spacing": {
      "type": "float",
      "default": 5,
      "min": 2,
      "max": 14,
      "label": "线距(px)"
    },
    "ink": {
      "type": "color",
      "default": "#1b1a2a",
      "label": "墨色"
    },
    "paper": {
      "type": "color",
      "default": "#f3eee2",
      "label": "纸色"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "pdoom-video",
      "ref": "engine GLSL_COMMON hatch/engrave（MIT）",
      "note": "按原理自写"
    },
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/copperplate",
      "note": "只参考风格名称与观感描述，代码为本项目自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
float hatch(vec2 px, float angle, float lum, float level) {
  vec2 p = fxRot(angle) * px;
  float line = abs(fract(p.y / spacing) - .5) * 2.;
  float width = clamp((level - lum) * 2.2, 0., 1.);
  return 1. - smoothstep(width - .15, width + .15, line);
}
vec4 effect(vec2 uv) {
  float lum = fxLuma(srcTex(uv).rgb);
  vec2 px = uv * uRes;
  float h = hatch(px, .6, lum, .95);
  h = max(h, hatch(px, -.6, lum, .62));
  h = max(h, hatch(px, 1.4, lum, .35));
  return vec4(mix(paper, ink, h), 1.);
}
