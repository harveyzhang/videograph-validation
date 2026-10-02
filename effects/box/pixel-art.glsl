/*@effect
{
  "id": "pixel-art",
  "name": "像素画",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "pixel",
    "8-bit",
    "retro game",
    "mosaic",
    "像素"
  ],
  "summary": "降分辨率 + 限制调色板 + 有序抖动，像 16 色游戏画面。",
  "when": "游戏、怀旧、轻松幽默。",
  "avoid": "需要细节的镜头。",
  "params": {
    "pixel": {
      "type": "float",
      "default": 6,
      "min": 2,
      "max": 24,
      "label": "像素尺寸"
    },
    "levels": {
      "type": "float",
      "default": 4,
      "min": 2,
      "max": 8,
      "label": "色阶"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "pixel art / 8-bit",
      "note": "只参考风格描述，代码为本项目自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec2 cell = floor(uv * uRes / pixel);
  vec2 cuv = (cell + .5) * pixel / uRes;
  vec3 c = srcTex(cuv).rgb;
  float d = fxBayer4(cell) - .5;
  c = floor(c * (levels - 1.) + .5 + d * .9) / (levels - 1.);
  return vec4(c, 1.);
}
