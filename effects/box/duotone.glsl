/*@effect
{
  "id": "duotone",
  "name": "双色调",
  "kind": "post",
  "category": "胶片与调色",
  "tags": [
    "duotone",
    "two-tone",
    "poster",
    "brand color",
    "双色"
  ],
  "summary": "暗部映射到颜色 A、亮部映射到颜色 B，最快统一品牌色调。",
  "when": "品牌宣传片统一色调、海报感、音乐人视觉。",
  "avoid": "需要多色区分信息的镜头。",
  "params": {
    "shadow": {
      "type": "color",
      "default": "#1b1464",
      "label": "暗部色"
    },
    "highlight": {
      "type": "color",
      "default": "#ff6a3d",
      "label": "亮部色"
    },
    "contrast": {
      "type": "float",
      "default": 1.2,
      "min": 0.5,
      "max": 2.5,
      "label": "对比"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "videograph",
      "ref": "duotone grading",
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
  float l = clamp((fxLuma(srcTex(uv).rgb) - .5) * contrast + .5, 0., 1.);
  return vec4(mix(shadow, highlight, l), 1.);
}
