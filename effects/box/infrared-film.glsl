/*@effect
{
  "id": "infrared-film",
  "name": "红外胶片",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["infrared", "aerochrome", "false color", "ir film", "红外", "假彩色", "粉色植物"],
  "summary": "彩色红外胶片的假彩色：植物与暖色变成粉红到品红，天空变成深青蓝，高光有红外光晕；整体像异世界的风景。",
  "when": "迷幻、梦境、异世界、摇滚与独立 MV、风景与自然的“非现实”重构。",
  "avoid": "需要真实色彩的镜头；人脸近景（肤色会变得很诡异，除非这正是你要的）。",
  "params": {
    "strength": { "type": "float", "default": 0.9, "min": 0, "max": 1, "label": "强度" },
    "foliage": { "type": "color", "default": "#ff4f8b", "label": "红外反射色（植物/暖色）" },
    "sky": { "type": "color", "default": "#1f5c8a", "label": "天空色" },
    "halation": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "红外光晕" }
  },
  "bindings": { "halation": { "to": "energy", "amount": 0.3 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：胶片调色", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：彩色红外胶片的三层乳剂分别感受“绿、红、红外”，冲出来却印成“蓝、绿、红”——每层颜色都往上挪了一档。
// 植物强烈反射红外 → 变成鲜艳的品红/粉红；红色物体变成黄色；蓝天几乎没有红外 → 变成深青蓝。
// 红外光穿透力强，会在高光周围的片基里散射，形成柔和的红色光晕（halation）。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 估计“红外反射量”：植物/暖色反射红外最多，蓝色几乎不反射。用 (绿 + 红) 相对蓝的多少近似。
  float ir = clamp((src.g * .9 + src.r * .6) - src.b * .7, 0., 1.);
  ir = smoothstep(.05, .7, ir);

  // ② 通道上移：新红 = 红外，新绿 = 原红，新蓝 = 原绿（这是彩红外胶片的物理映射）。
  vec3 shifted = vec3(ir * .9 + src.r * .2, src.r * .85, src.g * .9);

  // ③ 调色：红外强的地方推向 foliage 色，原本偏蓝的天空推向 sky 色（胶片的染料并不纯，这里用两种色拉开）。
  float blueish = smoothstep(.0, .25, src.b - max(src.r, src.g) * .9);
  vec3 c = mix(shifted, shifted * .4 + foliage * ir * .8, ir * .6);
  c = mix(c, sky * (.6 + fxLuma(src) * .6), blueish * .8);

  // ④ 红外光晕：高光周围红色的柔光（4 次采样的小圆周）。halation 挂音乐能量：越激烈的段落光晕越浓。
  vec3 h = vec3(0.);
  for (int i = 0; i < 4; i++) {
    float a = float(i) * 1.5708 + .4;
    h += max(srcTex(uv + vec2(cos(a), sin(a)) * 6. / uRes).rgb - .6, 0.);
  }
  c += vec3(1., .25, .3) * fxLuma(h) * halation * .9;

  // ⑤ 红外片的颗粒偏粗（静止颗粒）。
  c += (fxHash(floor(uv * uRes * .55)) - .5) * .035;
  return vec4(mix(src, clamp(c, 0., 1.), strength), 1.);
}
