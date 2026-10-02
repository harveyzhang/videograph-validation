/*@effect
{
  "id": "vhs-tape",
  "name": "VHS 录像带",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "vhs",
    "tape",
    "retro",
    "80s",
    "录像带"
  ],
  "summary": "色度偏移、跟踪横纹、磁带噪点与轻微抖动。",
  "when": "回忆、80/90 年代、家庭录像、复古广告。",
  "avoid": "需要清晰阅读的界面与小字。",
  "params": {
    "chroma": {
      "type": "float",
      "default": 0.004,
      "min": 0,
      "max": 0.015,
      "label": "色度偏移"
    },
    "noise": {
      "type": "float",
      "default": 0.12,
      "min": 0,
      "max": 0.5,
      "label": "噪点"
    },
    "tracking": {
      "type": "float",
      "default": 0.5,
      "min": 0,
      "max": 1,
      "label": "跟踪纹"
    }
  },
  "bindings": {
    "chroma": {
      "to": "kick",
      "amount": 0.006
    }
  },
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "VHS / camcorder look",
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
  float line = floor(uv.y * uRes.y);
  float jitter = (fxHash(vec2(line, floor(uTime * 24.))) - .5) * .002;
  float band = smoothstep(.0, .02, abs(fract(uv.y * .5 - uTime * .07) - .5) - .45) ;
  float bandShift = (1. - band) * tracking * .02;
  vec2 u = uv + vec2(jitter + bandShift, 0.);
  float r = srcTex(u + vec2(chroma, 0.)).r, g = srcTex(u).g, b = srcTex(u - vec2(chroma, 0.)).b;
  vec3 c = vec3(r, g, b);
  c = mix(c, vec3(fxLuma(c)), .15) * vec3(1.03, 1., .95);
  c += (fxHash(uv * uRes + uTime) - .5) * noise;
  c *= .92 + .08 * sin(uv.y * uRes.y * 1.5);
  return vec4(c, 1.);
}
