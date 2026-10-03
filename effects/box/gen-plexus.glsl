/*@effect
{
  "id": "gen-plexus",
  "name": "网络连线",
  "kind": "post",
  "category": "生成层",
  "tags": ["plexus", "network", "nodes", "connections", "tech", "data", "网络", "节点连线", "科技感", "数据"],
  "summary": "画面上漂浮着一层发光节点，彼此距离近的节点之间自动连上细线（越近越亮），整张网络缓慢流动变形；鼓点时节点亮一下、连线范围扩大。",
  "when": "科技/互联网/AI/区块链/社交网络主题、数据可视化开场、企业宣传片的背景纹理。",
  "avoid": "温暖手作/自然题材；画面本身已经很复杂时（网络会让画面更乱）。",
  "params": {
    "density": { "type": "float", "default": 7, "min": 3, "max": 25, "label": "节点密度（每屏高格数）" },
    "reach": { "type": "float", "default": 1.1, "min": 0.4, "max": 1.6, "label": "连线距离（格）" },
    "drift": { "type": "float", "default": 0.25, "min": 0, "max": 1.5, "label": "漂移速度" },
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点脉冲（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#5fd0ff", "label": "颜色" },
    "dim": { "type": "float", "default": 0.1, "min": 0, "max": 0.8, "label": "原画面压暗" }
  },
  "bindings": { "pulse": { "to": "kick", "amount": 0.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：节点网络背景", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（“Plexus”动态设计插件的典型画面）：一群缓慢漂浮的点，任意两点距离小于阈值就连一条线，
// 线的透明度随距离增大而淡出——形成不断重组的网。实现：每格一个节点，像素只看 3×3 邻格的 9 个节点，
// 画出节点光点与这 9 个节点两两之间（只取相邻格的组合）的线段。纯计算，不采样。

vec2 node(vec2 id) {
  float h = fxHash(id);
  return id + .5 + .38 * vec2(sin(uTime * drift * (.6 + h) + h * 40.), cos(uTime * drift * (.5 + h * .8) + h * 70.));
}

float segDist(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
  return length(pa - ba * h);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 g = vec2(uv.x * uRes.x / uRes.y, uv.y) * density;
  vec2 base = floor(g);
  float px = density / uRes.y;                 // 一个像素在格坐标里的大小
  float lines = 0., dots = 0.;

  // ① 9 个候选节点。
  vec2 pts[9];
  for (int j = 0; j < 3; j++) for (int i = 0; i < 3; i++) pts[j * 3 + i] = node(base + vec2(float(i - 1), float(j - 1)));

  // ② 连线：9 个节点两两之间（36 对），距离 < reach 才连，越近越亮；线宽约 1 像素。pulse 挂鼓点：鼓点时连线距离变大。
  float R = reach * (1. + pulse * .25);
  for (int a = 0; a < 9; a++) {
    for (int b = a + 1; b < 9; b++) {
      float L = length(pts[a] - pts[b]);
      if (L > R) continue;
      float d = segDist(g, pts[a], pts[b]);
      lines += smoothstep(max(px * 1.8, .014), 0., d) * (1. - L / R);
    }
    // ③ 节点：小亮点 + 光晕，鼓点时更亮
    float dn = length(g - pts[a]);
    float dr = max(px * 2.5, .03);                      // 点半径：约 2.5 像素，低分辨率下不小于 0.03 格
    dots += smoothstep(dr, dr * .3, dn) + exp(-dn / .06) * .12 * (1. + pulse);
  }

  // ④ 合成：原画面略压暗，网络加光叠加。
  vec3 c = src * (1. - dim);
  c = 1. - (1. - c) * (1. - clamp(color * (min(lines, 1.2) * .85 + dots * .9), 0., 1.));
  return vec4(c, 1.);
}
