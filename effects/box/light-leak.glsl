/*@effect
{
  "id": "light-leak",
  "name": "漏光",
  "kind": "post",
  "category": "胶片与调色",
  "tags": [
    "light leak",
    "warm",
    "analog",
    "flare",
    "漏光"
  ],
  "summary": "暖色漏光从画面边缘缓慢游走，在下拍时更亮。",
  "when": "青春、回忆、夏日、温暖品牌。",
  "avoid": "冷峻、科技、夜景主色调。",
  "params": {
    "strength": {
      "type": "float",
      "default": 0.45,
      "min": 0,
      "max": 1.2,
      "label": "强度"
    },
    "color": {
      "type": "color",
      "default": "#ff8a3d",
      "label": "漏光色"
    }
  },
  "bindings": {
    "strength": {
      "to": "bar",
      "amount": 0.35
    }
  },
  "inspiredBy": [
    {
      "source": "videograph",
      "ref": "analog light leak",
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
  vec3 c = srcTex(uv).rgb;
  vec2 center = vec2(1.1 + .2 * sin(uTime * .3), .2 + .4 * sin(uTime * .21));
  float leak = smoothstep(1.1, 0., length((uv - center) * vec2(1.2, 2.)));
  leak *= .7 + .3 * fxFbm(uv * 3. + uTime * .1);
  c = 1. - (1. - c) * (1. - color * leak * strength);
  return vec4(c, 1.);
}
