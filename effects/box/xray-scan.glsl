/*@effect
{
  "id": "xray-scan",
  "name": "X 光透视",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["x-ray", "radiograph", "medical", "scan", "inverted", "X 光", "透视", "医学影像", "扫描"],
  "summary": "画面变成一张 X 光片：明暗反转为蓝灰色调，轮廓处像骨骼一样发亮、内部半透明；一道扫描光带自上而下扫过，被扫到的地方短暂更清晰；鼓点时片子轻微闪亮。",
  "when": "医疗/科学/安检题材、“看穿表象”的意象、悬疑与科幻、产品“内部结构”的展示。",
  "avoid": "需要正常颜色与观感的镜头。",
  "params": {
    "tint": { "type": "color", "default": "#a8d8ff", "label": "片子色调" },
    "bone": { "type": "float", "default": 0.8, "min": 0, "max": 2, "label": "轮廓（骨骼）亮度" },
    "scanSpeed": { "type": "float", "default": 0.3, "min": 0, "max": 2, "label": "扫描速度（次/秒）" },
    "flash": { "type": "float", "default": 0, "min": 0, "max": 0.4, "label": "鼓点闪亮（通常由节拍驱动）" }
  },
  "bindings": { "flash": { "to": "kick", "amount": 0.15 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：扫描与透视", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：X 光片上，密度高的东西（骨骼、金属）挡住射线，底片在那里不感光而显得亮白；软组织半透明呈灰色，空气处最黑。
// 胶片放在灯箱上看是冷蓝灰色调。这里把画面亮度反转（亮→暗）并让轮廓（密度变化处）发亮，模拟骨骼的边缘。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float l = fxLuma(src);
  // ① 反转：亮 → 暗（像穿透多的地方）
  float inv = 1. - l;
  // ② 骨骼边缘：轮廓发亮（Sobel，9 次采样）
  float e = fxSobel(uv);
  float v = inv * .55 + smoothstep(.05, .4, e) * bone;
  // ③ 扫描光带：自上而下，光带经过处更亮更清楚
  float pos = 1. - fract(uTime * scanSpeed);
  float band = exp(-pow((uv.y - pos) * 18., 2.));
  v += band * .25 + flash;
  // ④ 胶片：蓝灰色调 + 轻微颗粒 + 暗角
  vec3 c = tint * v + (fxHash(floor(uv * uRes / 2.)) - .5) * .03;
  c *= 1. - .35 * smoothstep(.4, 1.1, length((uv - .5) * vec2(uRes.x / uRes.y, 1.)));
  return vec4(c, 1.);
}
