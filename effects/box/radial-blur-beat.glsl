/*@effect
{
  "id": "radial-blur-beat",
  "name": "拍点径向模糊",
  "kind": "post",
  "category": "运动与节拍",
  "tags": [
    "radial blur",
    "speed",
    "zoom blur",
    "impact",
    "径向模糊"
  ],
  "summary": "鼓点时从中心向外拉出速度线式的径向模糊。",
  "when": "冲刺、加速、进入下一段落。",
  "avoid": "长时间持续（会晕）。",
  "params": {
    "amount": {
      "type": "float",
      "default": 0,
      "min": 0,
      "max": 0.15,
      "label": "模糊量"
    }
  },
  "bindings": {
    "amount": {
      "to": "kick",
      "amount": 0.06
    }
  },
  "inspiredBy": [
    {
      "source": "videos-casebook",
      "ref": "techniques 节奏与卡点：拍脉冲驱动缩放/抖动/色差",
      "note": "按思路自写"
    },
    {
      "source": "shotcraft",
      "ref": "五条通用法则：节拍律动",
      "note": "本仓库"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec3 c = vec3(0.);
  for (int i = 0; i < 10; i++) { float s = 1. - amount * float(i) / 9.; c += srcTex((uv - .5) * s + .5).rgb; }
  return vec4(c / 10., 1.);
}
