/*@effect
{
  "id": "cube-spin",
  "name": "立方体翻转转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["cube", "3d rotate", "box", "spin", "flip", "立方体", "3D 翻转", "旋转", "盒子"],
  "summary": "两个镜头贴在一个立方体相邻的两个面上，立方体带透视绕竖轴转 90°：旧镜头转向侧面并变暗、新镜头从另一侧转到正面；转动时整体略微后退，边缘有一道棱线高光。",
  "when": "多场景/多产品切换、App 与科技演示、综艺与游戏、轻松的段落切换。",
  "avoid": "电影感叙事。时长建议 0.5–1 秒。",
  "params": {
    "persp": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "透视强度" },
    "pull": { "type": "float", "default": 0.12, "min": 0, "max": 0.4, "label": "转动时后退" },
    "toLeft": { "type": "bool", "default": true, "label": "向左转（关 = 向右）" },
    "bg": { "type": "color", "default": "#0b0b0f", "label": "背景色" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：立方体转场", "note": "按思路自写；实现为两面透视投影 + 后退 + 棱线高光，与 gl-transitions 的 cube 机制不同" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（立方体转场）：把两张画面贴在一个盒子相邻的两面，盒子转动 90° 时，原来的正面转向侧面（透视压缩、变暗），
// 侧面转到正面。实现：对两个面分别做“反向投影”——从屏幕点求它落在该面的哪个位置（带透视除法），在前面的面优先。

vec4 transition(vec2 uv) {
  float p = progress;
  float e = p * p * (3. - 2. * p);
  float ang = e * 1.5708 * (toLeft ? 1. : -1.);
  float back = 1. + pull * sin(p * 3.1416);
  vec2 s = (uv - .5) * 2. * back;                         // 屏幕坐标 -1..1（后退时放大取样范围 = 画面变小）
  vec3 col = bg;
  float best = -1e3;
  // ① 两个面：面 0（旧镜头）法线初始朝向观众，面 1（新镜头）在侧面；绕 y 轴转 ang
  for (int f = 0; f < 2; f++) {
    float fa = ang - float(f) * 1.5708 * (toLeft ? 1. : -1.);
    // 面上的点 (u, v) ∈ [-1,1]² 在立方体坐标：中心在 (sin fa, 0, cos fa)，沿 (cos fa, 0, -sin fa) 展开
    // 透视：屏幕 x = X / (1 + Z_back * persp)，这里用近似：先求面在屏幕上的投影宽度
    float cz = cos(fa), sz = sin(fa);
    if (cz <= .01) continue;                              // 背面不可见
    // 解：屏幕 x = (sz + u * cz) / (1 + persp * (1 - (cz - u * sz)) * .5)
    float k = persp * .5;
    // 线性化求 u：s.x * (1 + k * (1 - cz + u * sz)) = sz + u * cz
    float u = (s.x * (1. + k * (1. - cz)) - sz) / (cz - s.x * k * sz);
    float depth = 1. + k * (1. - cz + u * sz);
    float v = s.y * depth;
    if (abs(u) <= 1. && abs(v) <= 1.) {
      float z = cz - u * sz;                              // 越大越靠近观众
      if (z > best) {
        best = z;
        vec2 q = vec2(u, v) * .5 + .5;
        vec3 c = f == 0 ? getFromColor(q).rgb : getToColor(q).rgb;
        // ② 受光：转离正面越多越暗；棱线（面边缘）高光
        c *= .45 + .55 * cz;
        c += smoothstep(.985, 1., abs(u)) * .25 * sin(p * 3.1416);
        col = c;
      }
    }
  }
  return vec4(col, 1.);
}
