/*@effect
{
  "id": "thermal-camera",
  "name": "热成像",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "thermal",
    "heat map",
    "infrared",
    "surveillance",
    "热成像"
  ],
  "summary": "亮度映射到热力色带（黑-紫-红-黄-白），带传感器噪点。",
  "when": "监控、科技审视、能量与热度的隐喻。",
  "avoid": "需要真实颜色的镜头。",
  "params": {
    "gain": {
      "type": "float",
      "default": 1.1,
      "min": 0.5,
      "max": 2,
      "label": "增益"
    },
    "noise": {
      "type": "float",
      "default": 0.04,
      "min": 0,
      "max": 0.2,
      "label": "噪点"
    }
  },
  "bindings": {
    "gain": {
      "to": "kick",
      "amount": 0.25
    }
  },
  "inspiredBy": [
    {
      "source": "pdoom-video",
      "ref": "engine heat GLSL（MIT）",
      "note": "按原理自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec3 heat(float t) {
  t = clamp(t, 0., 1.);
  vec3 c = mix(vec3(0.), vec3(.35, 0., .55), smoothstep(0., .25, t));
  c = mix(c, vec3(.95, .15, .1), smoothstep(.25, .55, t));
  c = mix(c, vec3(1., .85, .1), smoothstep(.55, .8, t));
  return mix(c, vec3(1.), smoothstep(.8, 1., t));
}
vec4 effect(vec2 uv) {
  float l = fxLuma(srcTex(uv).rgb) * gain + (fxHash(uv * uRes + uTime) - .5) * noise;
  return vec4(heat(l), 1.);
}
