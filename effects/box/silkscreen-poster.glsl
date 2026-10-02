/*@effect
{
  "id": "silkscreen-poster",
  "name": "丝印海报",
  "kind": "post",
  "category": "印刷与版画",
  "tags": [
    "silkscreen",
    "poster",
    "posterize",
    "travel poster",
    "丝印"
  ],
  "summary": "把画面压成 4 个平涂色块（可自定义色板），色块边缘轻微错版。",
  "when": "旅行海报、产品宣传的主视觉、复古广告。",
  "avoid": "需要渐变细节的写实画面。",
  "params": {
    "c1": {
      "type": "color",
      "default": "#1f2a44",
      "label": "暗色"
    },
    "c2": {
      "type": "color",
      "default": "#c9473c",
      "label": "中暗"
    },
    "c3": {
      "type": "color",
      "default": "#e8a94b",
      "label": "中亮"
    },
    "c4": {
      "type": "color",
      "default": "#f6efdc",
      "label": "亮色"
    },
    "offset": {
      "type": "float",
      "default": 0.003,
      "min": 0,
      "max": 0.015,
      "label": "错版"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/silkscreen-poster",
      "note": "只参考风格名称与观感描述，代码为本项目自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec3 band(float l) { return l < .25 ? c1 : l < .5 ? c2 : l < .75 ? c3 : c4; }
vec4 effect(vec2 uv) {
  float l = fxLuma(srcTex(uv).rgb) + (fxNoise(uv * uRes * .5) - .5) * .04;
  float l2 = fxLuma(srcTex(uv + vec2(offset, -offset)).rgb);
  vec3 col = band(l);
  if (band(l2) != col) col = mix(col, band(l2), .35);
  return vec4(col, 1.);
}
