/*@effect
{
  "id": "beat-shake",
  "name": "拍点震动",
  "kind": "post",
  "category": "运动与节拍",
  "tags": [
    "beat",
    "shake",
    "camera shake",
    "impact",
    "震动"
  ],
  "summary": "鼓点时画面按确定性噪声抖动并迅速稳定。",
  "when": "重拍、爆炸、强调冲击。",
  "avoid": "字幕阅读段、长时间连续使用。",
  "params": {
    "amount": {
      "type": "float",
      "default": 0,
      "min": 0,
      "max": 0.05,
      "label": "幅度"
    }
  },
  "bindings": {
    "amount": {
      "to": "kick",
      "amount": 0.015
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
  float t = floor(uTime * 30.);
  vec2 off = (vec2(fxHash(vec2(t, 1.)), fxHash(vec2(t, 2.))) - .5) * amount;
  vec2 u = (uv - .5) * (1. - amount) + .5 + off;
  return vec4(srcTex(u).rgb, 1.);
}
