/*@effect
{
  "id": "rgb-split-beat",
  "name": "RGB 拍点分离",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "rgb split",
    "chromatic",
    "beat",
    "impact",
    "色散"
  ],
  "summary": "每个鼓点瞬间把 RGB 三个通道向外推开，随后回位。",
  "when": "卡点、重拍、标题砸入。",
  "avoid": "已经很花的画面上叠加。",
  "params": {
    "amount": {
      "type": "float",
      "default": 0,
      "min": 0,
      "max": 0.05,
      "label": "分离距离"
    },
    "radial": {
      "type": "bool",
      "default": true,
      "label": "径向"
    }
  },
  "bindings": {
    "amount": {
      "to": "kick",
      "amount": 0.018
    }
  },
  "inspiredBy": [
    {
      "source": "videos-casebook",
      "ref": "techniques 拍脉冲驱动色差",
      "note": "按思路自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec2 dir = radial ? (uv - .5) : vec2(1., 0.);
  vec3 c = vec3(srcTex(uv + dir * amount).r, srcTex(uv).g, srcTex(uv - dir * amount).b);
  return vec4(c, 1.);
}
