/*@effect
{
  "id": "vignette",
  "name": "暗角",
  "kind": "post",
  "category": "胶片与调色",
  "tags": [
    "vignette",
    "focus",
    "cinematic",
    "暗角"
  ],
  "summary": "四角压暗，把视线收向画面中心，可随下拍呼吸。",
  "when": "几乎任何需要聚焦主体的镜头。",
  "avoid": "画面重要信息在四角时。",
  "params": {
    "amount": {
      "type": "float",
      "default": 0.5,
      "min": 0,
      "max": 1.5,
      "label": "强度"
    },
    "roundness": {
      "type": "float",
      "default": 0.6,
      "min": 0,
      "max": 1,
      "label": "圆度"
    }
  },
  "bindings": {
    "amount": {
      "to": "beat",
      "amount": 0.12
    }
  },
  "inspiredBy": [
    {
      "source": "videograph",
      "ref": "vignette",
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
  vec2 d = (uv - .5) * mix(vec2(1.), vec2(uRes.x / uRes.y, 1.), roundness);
  float v = smoothstep(.85, .2, length(d) * 1.1);
  return vec4(srcTex(uv).rgb * mix(1., v, amount), 1.);
}
