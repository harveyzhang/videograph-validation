/*@effect
{
  "id": "beat-exposure",
  "name": "拍点曝光呼吸",
  "kind": "post",
  "category": "运动与节拍",
  "tags": [
    "beat",
    "exposure",
    "pulse",
    "flash",
    "呼吸"
  ],
  "summary": "下拍时亮度轻微提升再回落（有上限，避免闪烁风险）。",
  "when": "需要节奏感但不想动画面的镜头。",
  "avoid": "把强度调高做全屏闪白（>3 次/秒是光敏风险）。",
  "params": {
    "amount": {
      "type": "float",
      "default": 0,
      "min": 0,
      "max": 0.35,
      "label": "提亮"
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
  vec3 c = srcTex(uv).rgb;
  return vec4(c + (1. - c) * amount * .6 + c * amount * .4, 1.);
}
