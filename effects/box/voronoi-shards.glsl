/*@effect
{
  "id": "voronoi-shards",
  "name": "Voronoi 碎玻璃",
  "kind": "post",
  "category": "几何与图形",
  "tags": ["voronoi", "shatter", "shards", "broken glass", "cells", "碎片", "碎玻璃", "泰森多边形"],
  "summary": "画面像透过一块碎裂的玻璃看：不规则多边形碎片各自轻微错位、偏色，裂缝发亮；鼓点时碎片被震开。",
  "when": "冲击、崩溃、反转剧情、摇滚与电子乐的副歌、“打破常规”的口号镜头。",
  "avoid": "需要完整阅读的文字；温柔抒情段落；碎片过大时像故障而不像玻璃。",
  "params": {
    "cells": { "type": "float", "default": 9, "min": 3, "max": 30, "label": "碎片密度（横向个数）" },
    "displace": { "type": "float", "default": 0.012, "min": 0, "max": 0.05, "label": "碎片错位" },
    "crack": { "type": "float", "default": 0.55, "min": 0, "max": 1.5, "label": "裂缝亮度" },
    "tilt": { "type": "float", "default": 0.12, "min": 0, "max": 0.3, "label": "碎片明暗差" }
  },
  "bindings": { "displace": { "to": "kick", "amount": 0.02 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：碎裂/冲击转场", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：钢化玻璃受冲击后从无数个应力点同时开裂，裂纹把玻璃分成一块块凸多边形（近似 Voronoi 图：
// 每块属于离它最近的那个应力点）。每块碎片的倾角略不同，所以透过它看到的画面各自偏移一点、反光强弱不同；
// 裂缝本身是断面，会把光反射进眼睛，看起来是一道道亮线。

vec4 effect(vec2 uv) {
  float asp = uRes.x / uRes.y;
  // 冲击点在画面中心偏上：越靠近冲击点碎片越小（坐标往中心压缩），远处碎片大——真实碎玻璃的放射状分布。
  vec2 q = vec2(uv.x * asp, uv.y) - vec2(.5 * asp, .55);
  q *= 1. + 1.2 / (1. + length(q) * 6.);
  vec2 p = q * cells / asp;

  // ① 应力点：每个格子一个随机点；找最近点（属于哪块碎片）和次近点（离裂缝多远）。3×3 邻格。
  vec2 ip = floor(p);
  float d1 = 9., d2 = 9.;
  vec2 owner = vec2(0.), c1 = vec2(0.), c2 = vec2(0.);
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = ip + vec2(float(i), float(j));
      vec2 c = id + vec2(fxHash(id), fxHash(id + 13.7));
      float d = length(p - c);
      if (d < d1) { d2 = d1; c2 = c1; d1 = d; c1 = c; owner = id; }
      else if (d < d2) { d2 = d; c2 = c; }
    }
  }

  // ② 裂缝距离：到两块碎片分界线（两个中心的中垂线）的真实距离，比 d2-d1 更均匀。
  float crackD = dot((c1 + c2) * .5 - p, normalize(c2 - c1));

  // ③ 碎片倾角：每块碎片有自己的随机倾斜方向 → 透过它看到的画面整体平移一点（折射）。
  //    displace 挂鼓点：鼓点那一下碎片被震开，随后回落。
  float ang = fxHash(owner + 5.3) * 6.2832;
  vec2 shift = vec2(cos(ang), sin(ang)) * displace * (.4 + fxHash(owner + 2.2));
  vec3 col = srcTex(uv + shift).rgb;

  // ④ 碎片反光：倾角不同 → 每块明暗、冷暖略不同（玻璃边缘带一点青绿色）；
  //    同一块碎片上还有一道沿倾斜方向的线性光泽（平面玻璃反射天空的渐变），这是“玻璃”而不是“瓷砖”的关键。
  float bright = (fxHash(owner + 8.8) - .5) * 2. * tilt;
  float sheen = dot(p - c1, vec2(cos(ang), sin(ang))) * 1.6;
  col = col * (1. + bright) + vec3(.6, .9, .85) * max(bright, 0.) * .3;
  col += vec3(.85, .95, 1.) * smoothstep(.1, .5, sheen) * tilt * .9;

  // ⑤ 裂缝：断面反光 = 一道细亮线（宽度按像素换算），旁边一圈很窄的暗边（断面挡光）。
  float pxw = cells / asp / uRes.y * (1. + 1.2 / (1. + length(q) * 6.));   // 一个像素在碎片坐标中的大小
  float line = smoothstep(pxw * 1.1, 0., crackD);
  float shadow = smoothstep(pxw * 3.5, pxw * 1.1, crackD) - line;
  col = col * (1. - shadow * .35) + vec3(.95, 1., 1.) * line * crack;
  return vec4(col, 1.);
}
