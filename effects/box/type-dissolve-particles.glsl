/*@effect
{
  "id": "type-dissolve-particles",
  "name": "文字粒子聚散",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "disintegrate", "particles", "dust", "thanos", "文字动画", "消散", "灰飞烟灭", "粒子"],
  "summary": "文字从右向左一点点碎成细小的粒子，粒子被一阵风吹向右上方、边飘边变小变淡，最后整行消失；默认是反向的入场：粒子从右上方飞回聚拢成字。关掉 gather 并把时间设到镜头末尾就是出场消散。",
  "when": "告别/失去/遗忘的歌词、片尾消失、科幻与魔法、“化为乌有”的叙事。",
  "avoid": "文字压在复杂背景上（原位用补底色）；需要文字长时间停留的镜头（把时间设到镜头末尾）。",
  "params": {
    "start": { "type": "float", "default": 0.02, "min": 0, "max": 0.95, "label": "开始消散（镜头进度）" },
    "end": { "type": "float", "default": 0.5, "min": 0.05, "max": 1, "label": "完全消失（镜头进度）" },
    "gather": { "type": "bool", "default": true, "label": "聚拢成字（开，默认入场）/ 吹散消失（关，出场）" },
    "grain": { "type": "float", "default": 0.004, "min": 0.0015, "max": 0.015, "label": "粒子大小（画面高度比例）" },
    "wind": { "type": "float", "default": 0.25, "min": 0.02, "max": 0.6, "label": "吹散距离" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" },
    "gust": { "type": "float", "default": 0, "min": 0, "max": 0.2, "label": "鼓点阵风（通常由节拍驱动）" }
  },
  "bindings": { "gust": { "to": "kick", "amount": 0.05 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：粒子消散", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（电影里的“化成灰”）：物体从一侧开始崩解成细小的灰尘颗粒，颗粒被风带走、逐渐飘散变淡。
// 实现（逆向，无帧间状态）：每个粒子的起点是字上的一个小格子，出发时刻按 x 从右到左排列；
// 当前像素检查 3 行 × 若干列可能飘到这里的粒子——位移主要是向右上方，所以只需回看左下方的格子。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float gpx = grain * uRes.y;
  vec2 g = uv * uRes / gpx;
  float p = clamp((uProgress - start) / max(end - start, .01), 0., 1.);
  if (gather) p = 1. - p;
  // ① 还在原位的字：出发时刻 = 1 - x（右边先走）+ 噪声；还没出发的格子保持原样
  vec2 cell0 = floor(g);
  float depart0 = (1. - uv.x) * .7 + fxNoise(uv * 20.) * .3;
  float stay = step(p * 1.05, depart0);
  vec3 c = mix(mix(src, bg, inkOf(src)), src, stay);
  // ② 飞行中的粒子：回看左下方 6 个候选格子（飞行方向右上），看谁此刻在这里
  float W = wind + gust;
  for (int i = 0; i < 6; i++) {
    float k = float(i);
    float age = 0.;
    // 候选：向左下回溯 k 段（每段对应粒子飞了一段时间）
    vec2 back = vec2(k * 2.2, k * 1.1) * (W / .25);
    vec2 id = floor(g - back);
    vec2 home = (id + .5) * gpx / uRes;
    vec3 sc = srcTex(home).rgb;
    if (inkOf(sc) < .5) continue;
    float dep = (1. - home.x) * .7 + fxNoise(home * 20.) * .3;
    age = p * 1.05 - dep;
    if (age <= 0.) continue;
    float h = fxHash(id);
    vec2 drift = vec2(1., .55 + .5 * (h - .5)) * age * W * (1. + h) + vec2(0., sin(age * 8. + h * 20.) * .01);
    vec2 pos = home + drift;
    float sz = gpx * (1. - age * .8) * .5;
    vec2 d = (uv - pos) * uRes;
    if (abs(d.x) < sz && abs(d.y) < sz && sz > .3) c = mix(c, sc * (1. + age), clamp(1. - age * 1.2, 0., 1.));
  }
  return vec4(c, 1.);
}
