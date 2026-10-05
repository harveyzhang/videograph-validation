/*@effect
{
  "id": "mosaic-zoom-cut",
  "name": "马赛克放大切换",
  "kind": "transition",
  "category": "转场",
  "tags": ["mosaic", "tiles", "zoom", "grid", "photo wall", "马赛克", "拼图", "放大", "照片墙"],
  "summary": "旧镜头先缩小成一面由许多小图组成的照片墙（每格都是旧镜头的缩影），镜头随即冲向其中一格并放大，那一格变成下一个镜头铺满画面。",
  "when": "合集与回顾、社交媒体与“万里挑一”的意象、从全景聚焦到一个故事、照片与作品展示。",
  "avoid": "需要安静过渡的抒情段落。时长建议 0.8–1.4 秒。",
  "params": {
    "grid": { "type": "float", "default": 5, "min": 3, "max": 12, "label": "照片墙格数（每边）" },
    "targetX": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "放大目标格 X" },
    "targetY": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "放大目标格 Y" },
    "gap": { "type": "float", "default": 0.06, "min": 0, "max": 0.2, "label": "格缝" },
    "bg": { "type": "color", "default": "#0b0b0f", "label": "格缝颜色" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：照片墙聚焦", "note": "按思路自写；gl-transitions 无照片墙聚焦转场" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（合集类视频的经典镜头）：画面拉远成一面由许多小照片组成的墙，镜头再冲向墙上的某一张照片，那张照片放大占满屏幕——
// 观众被带进了这个具体的故事。

vec4 transition(vec2 uv) {
  float p = progress;
  float n = floor(grid + .5);
  // ① 目标格的中心（格坐标对齐）
  vec2 tc = (floor(vec2(targetX, targetY) * n) + .5) / n;
  // ② 缩放：0–0.4 从 1 缩到“整面墙”（每格 = 1/n 屏），0.4–1 冲向目标格（放大 n 倍），用对数插值让推进匀速
  float zoomOut = smoothstep(0., .4, p);
  float zoomIn = smoothstep(.4, 1., p);
  float s = mix(1., 1. / n, zoomOut);                     // 屏幕上一格的大小（相对全屏）
  s = mix(s, 1., zoomIn * zoomIn);
  vec2 focus = mix(vec2(.5), tc, zoomIn);                 // 推进时把目标格移到画面中心
  // 屏幕点 → 墙坐标（墙在 [0,1]，每格大小 1/n）
  float wallScale = s * n;                                // 墙在屏幕上的放大倍数
  vec2 w = (uv - .5) / wallScale + focus;
  vec2 cell = floor(w * n), f = fract(w * n);
  // ③ 每格内容：旧镜头缩影；目标格在推进阶段换成新镜头
  bool isTarget = all(equal(cell, floor(tc * n)));
  vec3 c = (isTarget && p > .4) ? getToColor(f).rgb : getFromColor(f).rgb;
  // 整面墙出现之前（刚开始缩小），格缝逐渐出现
  float g = gap * .5 * zoomOut * (1. - smoothstep(.75, 1., p));
  float inGap = step(f.x, g) + step(1. - g, f.x) + step(f.y, g) + step(1. - g, f.y);
  if (w.x < 0. || w.x > 1. || w.y < 0. || w.y > 1.) inGap = 1.;
  c = mix(c, bg, min(inGap, 1.));
  if (p >= .999) c = getToColor(uv).rgb;
  return vec4(c, 1.);
}
