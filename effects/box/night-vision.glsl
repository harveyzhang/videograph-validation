/*@effect
{
  "id": "night-vision",
  "name": "夜视仪",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "night vision",
    "green",
    "military",
    "surveillance",
    "夜视"
  ],
  "summary": "绿色增益、颗粒、圆形视野与扫描闪烁。",
  "when": "潜入、监视、悬疑、“被观察”。",
  "avoid": "明亮温暖的情绪。",
  "params": {
    "gain": {
      "type": "float",
      "default": 1.6,
      "min": 0.8,
      "max": 3,
      "label": "增益"
    },
    "scope": {
      "type": "bool",
      "default": true,
      "label": "圆形视野"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "night vision / surveillance",
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
  float l = pow(fxLuma(srcTex(uv).rgb) * gain, .9);
  l += (fxHash(uv * uRes + floor(uTime * 30.)) - .5) * .18;
  vec3 c = vec3(.15, 1., .25) * l;
  c *= .95 + .05 * sin(uv.y * uRes.y * 2. + uTime * 20.);
  if (scope) { vec2 d = (uv - .5) * vec2(uRes.x / uRes.y, 1.); c *= smoothstep(.5, .44, length(d)); }
  return vec4(c, 1.);
}
