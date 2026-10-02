/*@effect
{
  "id": "beat-zoom-punch",
  "name": "拍点推镜冲击",
  "kind": "post",
  "category": "运动与节拍",
  "tags": [
    "beat",
    "zoom",
    "punch",
    "impact",
    "卡点"
  ],
  "summary": "每个鼓点瞬间放大再衰减回位（脉冲衰减，不缓入），最常用的卡点手法。",
  "when": "副歌、产品亮相、标题砸入。",
  "avoid": "安静段落或已有强烈镜头运动时。",
  "params": {
    "zoom": {
      "type": "float",
      "default": 0,
      "min": 0,
      "max": 0.2,
      "label": "放大量"
    }
  },
  "bindings": {
    "zoom": {
      "to": "kick",
      "amount": 0.07
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
  vec2 u = (uv - .5) / (1. + zoom) + .5;
  return vec4(srcTex(u).rgb, 1.);
}
