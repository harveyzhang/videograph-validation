/*@effect
{
  "id": "pen-and-wash",
  "name": "钢笔淡彩",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": [
    "urban sketch",
    "pen",
    "line art",
    "wash",
    "钢笔淡彩"
  ],
  "summary": "墨线勾出轮廓，颜色被冲淡成水彩底，像城市速写。",
  "when": "城市、旅行、建筑、产品示意。",
  "avoid": "纯色大块、几乎没有轮廓的画面。",
  "params": {
    "line": {
      "type": "float",
      "default": 1.2,
      "min": 0.2,
      "max": 3,
      "label": "线条强度"
    },
    "wash": {
      "type": "float",
      "default": 0.55,
      "min": 0,
      "max": 1,
      "label": "淡彩"
    },
    "paper": {
      "type": "color",
      "default": "#faf6ec",
      "label": "纸色"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/urban-sketch",
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
  vec2 wobble = (vec2(fxNoise(uv * 40.), fxNoise(uv * 40. + 7.)) - .5) * .002;
  float e = fxSobel(uv + wobble);
  float ink = smoothstep(.12, .45, e * line);
  vec3 c = srcTex(uv + vec2(.004, -.003)).rgb;
  vec3 washCol = mix(paper, c, wash * (.6 + fxFbm(uv * 9.) * .5));
  return vec4(mix(washCol, vec3(.11, .1, .12), ink), 1.);
}
