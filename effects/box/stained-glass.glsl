/*@effect
{
  "id": "stained-glass",
  "name": "彩色玻璃窗",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["stained glass", "church window", "lead lines", "mosaic", "gothic", "彩色玻璃", "花窗", "教堂", "铅条"],
  "summary": "画面变成教堂彩绘玻璃窗：不规则的玻璃块各填一种提纯的颜色，块与块之间是粗黑的铅条；玻璃有厚薄不匀的明暗与气泡纹，光从后面透过来时亮部会发光；每小节光线强弱变化一次。",
  "when": "宗教/史诗/中世纪题材、神圣与救赎的情绪、艺术与建筑、节日（圣诞）。",
  "avoid": "需要细节与写实的镜头；人脸特写（玻璃块会切碎五官，调小 cells）。",
  "params": {
    "cells": { "type": "float", "default": 14, "min": 4, "max": 40, "label": "玻璃块密度（每屏高）" },
    "lead": { "type": "float", "default": 0.06, "min": 0.01, "max": 0.2, "label": "铅条粗细" },
    "vivid": { "type": "float", "default": 1.5, "min": 1, "max": 2.5, "label": "颜色提纯" },
    "glow": { "type": "float", "default": 0.2, "min": 0, "max": 1, "label": "透光（通常由小节驱动）" }
  },
  "bindings": { "glow": { "to": "bar", "amount": 0.3 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/stained-glass", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：彩绘玻璃由一块块单色玻璃拼成，用 H 形截面的铅条把它们焊在一起；每块玻璃是手工吹制的，
// 厚薄不匀、带气泡，所以同一块里颜色有深浅变化；阳光从窗外照进来，玻璃本身就是光源，亮色玻璃会“发光”。

vec4 effect(vec2 uv) {
  float A = uRes.x / uRes.y;
  vec2 p = vec2(uv.x * A, uv.y) * cells;
  // ① 玻璃块：Voronoi（最近点所属的块），同时求到边界的距离（铅条）
  vec2 ip = floor(p);
  float d1 = 9., d2 = 9.;
  vec2 owner = vec2(0.), c1 = vec2(0.), c2 = vec2(0.);
  for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
    vec2 id = ip + vec2(float(i), float(j));
    vec2 c = id + .5 + .4 * (vec2(fxHash(id), fxHash(id + 9.)) - .5) * 2.;
    float d = length(p - c);
    if (d < d1) { d2 = d1; c2 = c1; d1 = d; c1 = c; owner = id; } else if (d < d2) { d2 = d; c2 = c; }
  }
  float edge = dot((c1 + c2) * .5 - p, normalize(c2 - c1));
  // ② 每块一色：取块中心的颜色并提纯（饱和度拉高、亮度略提）
  vec3 col = srcTex(vec2(c1.x / A, c1.y) / cells).rgb;
  float l = fxLuma(col);
  col = clamp(mix(vec3(l), col, vivid) * 1.1, 0., 1.);
  // ③ 玻璃厚薄与气泡：块内低频明暗 + 少量小圆斑
  vec2 lp = p - c1;
  col *= .8 + .35 * fxNoise(p * 3. + owner * 7.);
  col += step(.97, fxNoise(p * 25.)) * .15;
  // ④ 透光：亮的玻璃更亮（发光），glow 挂小节
  col += col * smoothstep(.4, 1., l) * glow;
  // ⑤ 铅条：边界附近的深灰条，带一点金属高光
  float leadM = smoothstep(lead + .02, lead, edge);
  vec3 leadC = vec3(.08, .08, .09) + .08 * smoothstep(lead * .6, 0., abs(edge - lead * .5));
  return vec4(mix(col, leadC, leadM), 1.);
}
