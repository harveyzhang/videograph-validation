/*@effect
{
  "id": "cyanotype",
  "name": "蓝晒",
  "kind": "post",
  "category": "印刷与版画",
  "tags": [
    "cyanotype",
    "blueprint",
    "sun print",
    "蓝晒"
  ],
  "summary": "普鲁士蓝单色调 + 纸面笔刷边缘，像蓝晒照片。",
  "when": "植物、记忆、手作、温柔叙事。",
  "avoid": "需要暖色情绪的镜头。",
  "params": {
    "deep": {
      "type": "color",
      "default": "#0f2c5c",
      "label": "深蓝"
    },
    "light": {
      "type": "color",
      "default": "#e8eef3",
      "label": "纸白"
    },
    "edge": {
      "type": "float",
      "default": 0.08,
      "min": 0,
      "max": 0.25,
      "label": "刷边"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles",
      "note": "只参考风格名称与观感描述，代码为本项目自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  float l = fxLuma(srcTex(uv).rgb);
  vec3 col = mix(deep, light, smoothstep(.05, .95, l));
  float border = min(min(uv.x, 1. - uv.x), min(uv.y, 1. - uv.y));
  float brush = smoothstep(edge * .3, edge, border + (fxFbm(uv * 18.) - .5) * edge * .8);
  col = mix(light * .96, col, brush);
  return vec4(col * (.94 + fxNoise(uv * uRes * .3) * .06), 1.);
}
