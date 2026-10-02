/*@effect
{
  "id": "film-grain",
  "name": "胶片颗粒与划痕",
  "kind": "post",
  "category": "胶片与调色",
  "tags": [
    "film",
    "grain",
    "dust",
    "scratches",
    "胶片"
  ],
  "summary": "动态颗粒、偶发灰尘与竖向划痕、轻微闪烁。",
  "when": "电影感、纪录片、怀旧，几乎任何镜头的“质感层”。",
  "avoid": "颗粒超过 10%（压缩后会糊、体积变大）。",
  "params": {
    "grain": {
      "type": "float",
      "default": 0.08,
      "min": 0,
      "max": 0.3,
      "label": "颗粒"
    },
    "dust": {
      "type": "float",
      "default": 0.4,
      "min": 0,
      "max": 1,
      "label": "灰尘划痕"
    },
    "flicker": {
      "type": "float",
      "default": 0.03,
      "min": 0,
      "max": 0.15,
      "label": "闪烁"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "videos-casebook",
      "ref": "playbook 颗粒 ≤10%",
      "note": "经验规则，代码自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;
  float frame = floor(uTime * 24.);
  c += (fxHash(uv * uRes + frame) - .5) * grain;
  float scratchX = fxHash(vec2(frame, 1.));
  c *= 1. - dust * .35 * step(.985, fxHash(vec2(frame, 2.))) * smoothstep(.0015, 0., abs(uv.x - scratchX));
  float speck = step(.9993, fxHash(floor(uv * uRes / 3.) + frame));
  c = mix(c, vec3(.05), speck * dust);
  c *= 1. + (fxHash(vec2(frame, 3.)) - .5) * flicker;
  return vec4(c, 1.);
}
