/*@effect
{
  "id": "type-chrome",
  "name": "Y2K 镀铬字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "chrome", "y2k", "metal", "liquid metal", "文字", "镀铬", "千禧", "液态金属"],
  "summary": "亮色文字变成千禧年风格的镀铬金属：上半反射蓝天、下半反射深色地面、中间一条锐利的地平线高光，边缘带一点彩虹色散；镀铬反射随时间缓慢晃动，鼓点时高光一闪。",
  "when": "Y2K/千禧/赛博复古、嘻哈与电子乐标题、潮牌、游戏与科技感 Logo。",
  "avoid": "温柔手作/自然题材；细小的字。",
  "params": {
    "sky": { "type": "color", "default": "#9fd2ff", "label": "天空反射色" },
    "ground": { "type": "color", "default": "#2b2440", "label": "地面反射色" },
    "horizon": { "type": "float", "default": 0.5, "min": 0.2, "max": 0.8, "label": "反射地平线位置（字内）" },
    "shine": { "type": "float", "default": 0.4, "min": 0, "max": 1.5, "label": "高光（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "shine": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：金属字效", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：镀铬是近乎完美的镜面，它“没有颜色”，只反射环境：上半部分映出天空（亮、偏蓝），下半部分映出地面（暗），
// 两者交界是一条非常锐利的亮线（地平线）。字的弧形边缘会把环境扭曲，所以反射图案顺着笔画弯曲；边缘有一点色散。
// 实现：用字的局部“高度”（字内到上下边缘的位置）当作反射方向，查一张 天空-地平线-地面 的渐变。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkAt(uv);
  if (ink <= 0.) return vec4(src, 1.);
  // ① 估计笔画内的竖直位置：向上/向下各探 4 步，找到离上下边缘的距离（8 次采样）→ 0（底边）..1（顶边）
  float st = 4. / uRes.y;
  float up = 0., dn = 0.;
  for (int i = 1; i <= 4; i++) {
    up += inkAt(uv + vec2(0., st * float(i) * 2.));
    dn += inkAt(uv - vec2(0., st * float(i) * 2.));
  }
  float h = (dn + .5) / (up + dn + 1.);              // 越靠上 h 越大
  // ② 环境扭曲：反射方向随横向位置与时间轻微摆动（像镜面在晃）
  h += sin(uv.x * 30. + uTime * 1.3) * .04 + (fxNoise(uv * 20.) - .5) * .05;
  // ③ 查环境：天空（上，越高越亮）—地平线高光—地面（下，带一点反光）
  vec3 col = h > horizon ? mix(sky * .8, vec3(1.), smoothstep(horizon + .3, 1., h) * .6) : mix(ground, ground * 2.2 + .05, smoothstep(0., horizon, h));
  float line = exp(-pow((h - horizon) * 40., 2.));
  col += vec3(1.) * line * (.9 + shine);
  // ④ 边缘色散：笔画边缘（上下都靠边）带一点彩虹偏色
  float rim = 1. - smoothstep(0., 2., min(up, dn));
  col += vec3(.25, -.05, .3) * rim * sin(uv.x * 80.) * .5;
  return vec4(mix(src, col, ink), 1.);
}
