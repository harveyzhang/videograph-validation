/*@effect
{
  "id": "woodcut",
  "name": "木刻版画",
  "kind": "post",
  "category": "印刷与版画",
  "tags": [
    "woodcut",
    "linocut",
    "print",
    "block",
    "版画"
  ],
  "summary": "硬阈值黑白 + 沿形体的刀刻线纹，暗部是实墨、中间调是排线。",
  "when": "民谣、手作、史诗感、文学题材。",
  "avoid": "细节密集的界面或数据图。",
  "params": {
    "threshold": {
      "type": "float",
      "default": 0.45,
      "min": 0.1,
      "max": 0.9,
      "label": "阈值"
    },
    "lineDensity": {
      "type": "float",
      "default": 90,
      "min": 20,
      "max": 220,
      "label": "刻线密度"
    },
    "ink": {
      "type": "color",
      "default": "#141210",
      "label": "墨色"
    },
    "paper": {
      "type": "color",
      "default": "#efe6d2",
      "label": "纸色"
    }
  },
  "bindings": {
    "threshold": {
      "to": "kick",
      "amount": 0.06
    }
  },
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/woodcut",
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
  float warp = fxFbm(uv * 6.) * .35;
  float lines = sin((uv.y + warp * .08) * lineDensity * 3.14159 + uv.x * 4.) * .5 + .5;
  float carved = step(threshold, lum + (lines - .5) * .28 * (1. - abs(lum - threshold) * 2.));
  float rough = step(.5, fxNoise(uv * uRes * .4) + .25);
  float ink_ = 1. - carved;
  ink_ *= mix(1., rough, .15);
  return vec4(mix(paper, ink, ink_), 1.);
}
