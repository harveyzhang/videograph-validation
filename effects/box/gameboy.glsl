/*@effect
{
  "id": "gameboy",
  "name": "掌机四绿",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "gameboy",
    "palette",
    "retro game",
    "green",
    "掌机"
  ],
  "summary": "四级绿色调色板 + 像素格，经典掌机屏幕。",
  "when": "游戏梗、复古科技、可爱风。",
  "avoid": "品牌色严格的镜头。",
  "params": {
    "pixel": {
      "type": "float",
      "default": 4,
      "min": 1,
      "max": 12,
      "label": "像素尺寸"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "handheld console palette",
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
  float l = fxLuma(srcTex((cell + .5) * pixel / uRes).rgb) + (fxBayer4(cell) - .5) * .2;
  vec3 c = l < .25 ? fxHex(15., 56., 15.) : l < .5 ? fxHex(48., 98., 48.) : l < .75 ? fxHex(139., 172., 15.) : fxHex(155., 188., 15.);
  vec2 grid = fract(uv * uRes / pixel);
  c *= .9 + .1 * step(.12, min(grid.x, grid.y));
  return vec4(c, 1.);
}
