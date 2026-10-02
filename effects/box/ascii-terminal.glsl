/*@effect
{
  "id": "ascii-terminal",
  "name": "字符终端",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "ascii",
    "terminal",
    "matrix",
    "code",
    "字符"
  ],
  "summary": "画面变成按亮度选择的字符块（点、横、十字、实心），绿色终端色。",
  "when": "代码、黑客、数据、AI 内部视角。",
  "avoid": "人物情感特写。",
  "params": {
    "cell": {
      "type": "float",
      "default": 10,
      "min": 6,
      "max": 24,
      "label": "字符尺寸"
    },
    "color": {
      "type": "color",
      "default": "#5cff8a",
      "label": "字符色"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "ASCII / terminal rendering",
      "note": "只参考风格描述，代码为本项目自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
float glyph(vec2 p, float level) {
  vec2 q = abs(p - .5);
  if (level < .2) return 0.;
  if (level < .4) return step(length(p - .5), .12);
  if (level < .6) return step(q.y, .08) * step(q.x, .35);
  if (level < .8) return max(step(q.y, .08) * step(q.x, .35), step(q.x, .08) * step(q.y, .35));
  return step(max(q.x, q.y), .38);
}
vec4 effect(vec2 uv) {
  vec2 cellId = floor(uv * uRes / cell);
  float l = fxLuma(srcTex((cellId + .5) * cell / uRes).rgb);
  float g = glyph(fract(uv * uRes / cell), l);
  return vec4(color * g * (.6 + .4 * l) + vec3(0., .02, .01), 1.);
}
