/*@effect
{
  "id": "glass-shatter",
  "name": "玻璃碎裂转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["shatter", "glass break", "explode", "shards", "impact", "碎裂", "玻璃破碎", "爆开", "冲击转场"],
  "summary": "上一个镜头像一块玻璃被击碎：先出现放射状裂纹，然后碎片带着各自的旋转与下坠向外飞散、逐渐变小变暗，露出后面的下一个镜头。",
  "when": "冲击/反转/打破常规的时刻、动作与摇滚、副歌爆点的段落切换、“打破第四面墙”。",
  "avoid": "温柔抒情的衔接。时长建议 0.8–1.4 秒。",
  "params": {
    "cells": { "type": "float", "default": 9, "min": 4, "max": 25, "label": "碎片密度" },
    "impactX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "撞击点 X" },
    "impactY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "撞击点 Y" },
    "force": { "type": "float", "default": 1, "min": 0.2, "max": 2, "label": "飞散力度" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：碎裂转场", "note": "按思路自写；gl-transitions 无同类碎片物理转场" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：玻璃被击中时，裂纹从撞击点向外放射（Voronoi 状的碎块，靠近撞击点碎得更细），
// 随后每块碎片带着自己的速度向外飞、受重力下坠并旋转。实现（逆向）：对每个像素，检查附近的碎片在此刻飞到了哪里。

vec4 transition(vec2 uv) {
  float A = ratio;
  vec2 I = vec2(impactX, impactY);
  float p = progress;
  float crack = smoothstep(0., .18, p);                   // 前 18%：只出现裂纹
  float fly = clamp((p - .15) / .85, 0., 1.);             // 之后：碎片飞散
  vec3 col = getToColor(uv).rgb;
  // ① 碎片：在“碎片原位坐标”里做 Voronoi；当前像素可能看到的是从附近飞来的碎片 → 检查 3×3 个碎片的当前位置
  vec2 p0 = (uv - I) * vec2(A, 1.);
  vec2 g = p0 * cells;
  vec2 base = floor(g);
  float found = 0.;
  for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
    vec2 id = base + vec2(float(i), float(j));
    vec2 ctr = id + .5 + .35 * (vec2(fxHash(id), fxHash(id + 7.)) - .5) * 2.;
    // ② 碎片运动：沿离开撞击点的方向飞出（近处更快），重力下坠，绕自身中心旋转并缩小
    vec2 dirv = normalize(ctr + 1e-3);
    float h = fxHash(id + 3.);
    vec2 vel = dirv * (1.2 + h) * force / (1. + length(ctr) * .15);
    vec2 disp = vel * fly + vec2(0., -1.6 * fly * fly) * force;
    float rot = (h - .5) * 6. * fly;
    float sc = 1. - fly * .6;
    // 当前像素在该碎片的局部坐标（逆变换）
    vec2 local = fxRot(-rot) * (g - ctr - disp * cells * .25) / max(sc, .01);
    vec2 orig = ctr + local;                              // 对应的原始位置（碎片坐标）
    // 判断 orig 是否属于碎片 id（最近中心是它）
    float dmin = 9.; vec2 own = vec2(0.);
    for (int b = -1; b <= 1; b++) for (int a = -1; a <= 1; a++) {
      vec2 nid = floor(orig) + vec2(float(a), float(b));
      vec2 nc = nid + .5 + .35 * (vec2(fxHash(nid), fxHash(nid + 7.)) - .5) * 2.;
      float dd = length(orig - nc);
      if (dd < dmin) { dmin = dd; own = nid; }
    }
    if (found < .5 && own == id) {
      vec2 ouv = orig / cells / vec2(A, 1.) + I;
      if (ouv.x >= 0. && ouv.x <= 1. && ouv.y >= 0. && ouv.y <= 1.) {
        col = getFromColor(ouv).rgb * (1. - fly * .5) * (.85 + .3 * h);
        found = 1.;
      }
    }
  }
  // ③ 裂纹：飞散前，碎片边界亮线逐渐出现（从撞击点向外蔓延）
  if (fly <= 0.) {
    vec2 ip = floor(g); float d1 = 9., d2 = 9.;
    for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
      vec2 id = ip + vec2(float(i), float(j));
      vec2 c = id + .5 + .35 * (vec2(fxHash(id), fxHash(id + 7.)) - .5) * 2.;
      float d = length(g - c); if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
    }
    float reach = crack * 1.2;
    float line = smoothstep(.06, 0., d2 - d1) * step(length(p0), reach);
    col = mix(getFromColor(uv).rgb, vec3(1.), line * .8);
  }
  return vec4(col, 1.);
}
