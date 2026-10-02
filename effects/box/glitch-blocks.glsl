/*@effect
{
  "id": "glitch-blocks",
  "name": "数字故障",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "glitch",
    "datamosh",
    "digital",
    "error",
    "故障"
  ],
  "summary": "在鼓点上把画面切成块状错位 + 通道分离，平时安静。",
  "when": "AI/科技主题的重音、转折、系统报错。",
  "avoid": "情绪舒缓的段落；不要每一拍都用。",
  "params": {
    "amount": {
      "type": "float",
      "default": 0,
      "min": 0,
      "max": 1,
      "label": "基础强度"
    },
    "blockSize": {
      "type": "float",
      "default": 24,
      "min": 6,
      "max": 80,
      "label": "块尺寸"
    }
  },
  "bindings": {
    "amount": {
      "to": "kick",
      "amount": 0.9
    }
  },
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "glitch transitions on beat",
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
  vec2 block = floor(uv * uRes / blockSize);
  float seed = floor(uTime * 12.);
  float r = fxHash(block + seed);
  float on = step(1. - amount * .35, r);
  vec2 shift = vec2((fxHash(block.yy + seed) - .5) * .12, 0.) * on;
  float split = .012 * amount;
  vec3 c = vec3(srcTex(uv + shift + vec2(split, 0.)).r, srcTex(uv + shift).g, srcTex(uv + shift - vec2(split, 0.)).b);
  if (on > .5 && fxHash(block + 3.) > .7) c = c.gbr;
  return vec4(c, 1.);
}
