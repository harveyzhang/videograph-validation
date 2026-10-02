/*@effect
{
  "id": "sepia-oldfilm",
  "name": "老电影",
  "kind": "post",
  "category": "胶片与调色",
  "tags": [
    "sepia",
    "old film",
    "silent movie",
    "vintage",
    "老电影"
  ],
  "summary": "棕褐色调 + 强暗角 + 帧抖动与闪烁，像默片。",
  "when": "历史回顾、“很久以前”、幽默反差。",
  "avoid": "现代科技感镜头。",
  "params": {
    "tone": {
      "type": "float",
      "default": 0.9,
      "min": 0,
      "max": 1,
      "label": "褐色程度"
    },
    "vignette": {
      "type": "float",
      "default": 0.6,
      "min": 0,
      "max": 1.5,
      "label": "暗角"
    },
    "shake": {
      "type": "float",
      "default": 0.002,
      "min": 0,
      "max": 0.01,
      "label": "帧抖动"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "videograph",
      "ref": "old film look",
      "note": "本项目原创"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  float frame = floor(uTime * 18.);
  vec2 u = uv + (vec2(fxHash(vec2(frame, 5.)), fxHash(vec2(frame, 6.))) - .5) * shake;
  float l = fxLuma(srcTex(u).rgb);
  vec3 sepia = vec3(l * 1.07, l * .92, l * .72);
  vec3 c = mix(srcTex(u).rgb, sepia, tone);
  c *= 1. - vignette * pow(length(uv - .5) * 1.2, 2.);
  c *= .92 + .08 * fxHash(vec2(frame, 7.));
  c += (fxHash(uv * uRes + frame) - .5) * .06;
  return vec4(c, 1.);
}
