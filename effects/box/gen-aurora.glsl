/*@effect
{
  "id": "gen-aurora",
  "name": "极光",
  "kind": "post",
  "category": "生成层",
  "tags": ["aurora", "northern lights", "sky", "glow", "overlay", "极光", "北极光", "天空", "光幕"],
  "summary": "画面上部垂下几道青绿到紫色的极光光幕，光幕底边明亮、向上拉出竖直的细光束并缓慢波动；音乐能量越高极光越亮、摆动越大。",
  "when": "夜空/雪原/星空镜头、梦幻与奇迹时刻、北欧/冰岛题材、抒情高潮。",
  "avoid": "白天或室内画面（天空不存在时极光会显得假）；画面上部有重要文字时。",
  "params": {
    "intensity": { "type": "float", "default": 0.75, "min": 0, "max": 2, "label": "亮度" },
    "height": { "type": "float", "default": 0.55, "min": 0.2, "max": 0.95, "label": "光幕底边高度（从底部算）" },
    "drift": { "type": "float", "default": 0.08, "min": 0, "max": 0.5, "label": "漂移速度" },
    "surge": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量涌动（通常由音乐能量驱动）" },
    "lowColor": { "type": "color", "default": "#3dff9e", "label": "底边颜色" },
    "highColor": { "type": "color", "default": "#8a5bff", "label": "顶部颜色" }
  },
  "bindings": { "surge": { "to": "energy", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：天空生成层", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：极光是太阳风粒子沿地磁场线撞进高层大气，氧原子在约 100 公里高度发绿光、更高处发红紫光；
// 粒子沿磁力线下来，所以极光是一道道竖直的光柱组成的“光幕”，底边最亮且锐利，往上渐淡；
// 光幕本身像窗帘一样被高空风推着弯曲、缓慢波动。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float light = 0.;
  vec3 col = vec3(0.);

  // ① 三道光幕：每道的底边是一条随 x 与时间缓慢弯曲的曲线（低频噪声），高度错开。
  for (int k = 0; k < 3; k++) {
    float K = float(k);
    float t = uTime * drift * (1. + K * .3) + K * 7.;
    float base = height + K * .07 + (fxNoise(vec2(p.x * 1.2 + t, K * 3.)) - .5) * (.18 + surge * .1)
               + sin(p.x * 2.5 + t * 2.) * .03 * (1. + surge);
    float above = p.y - base;                      // 光幕底边之上的距离
    if (above < -.02) continue;

    // ② 竖直光束：沿 x 的高频噪声决定每一束的亮度（磁力线结构），并沿时间缓慢变化。
    float rays = fxNoise(vec2(p.x * 40. + t * 3., K)) * .6 + fxNoise(vec2(p.x * 9. - t, K + 9.)) * .4;
    // ③ 纵向亮度：底边锐利地亮起（2% 屏高），向上指数衰减（光幕高度随能量变化）。
    float prof = smoothstep(-.02, .0, above) * exp(-max(above, 0.) / (.12 + .08 * surge + K * .03));
    float a = prof * (.35 + rays) * (1. - K * .2);
    light += a;
    // ④ 颜色：底部绿（低空氧），往上过渡到紫（高空）。
    col += mix(lowColor, highColor, clamp(above / .25, 0., 1.)) * a;
  }

  // ⑤ 合成：极光是加在夜空上的光（screen），亮的地方（地面景物）基本不受影响。
  vec3 aur = col * intensity * (1. + surge * .5);
  vec3 c = 1. - (1. - src) * (1. - clamp(aur, 0., 1.));
  return vec4(c, 1.);
}
