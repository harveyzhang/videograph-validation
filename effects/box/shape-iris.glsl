/*@effect
{
  "id": "shape-iris",
  "name": "图形遮罩转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["iris", "shape mask", "star", "heart", "diamond", "match cut", "遮罩转场", "形状", "圈入圈出"],
  "summary": "下一个镜头从画面中心以一个图形（星形 / 菱形 / 圆角方 / 心形 / 六边形可选）向外放大揭开，图形边缘带一圈彩色描边并缓慢旋转；可选“先收后放”的经典圈入圈出。",
  "when": "综艺/儿童/复古卡通、可爱的品牌、节日（心形=情人节、星形=庆祝）、段落之间的趣味转换。",
  "avoid": "严肃叙事。时长建议 0.5–1 秒。",
  "params": {
    "shape": { "type": "float", "default": 0, "min": 0, "max": 4, "label": "形状：0 星形 / 1 菱形 / 2 圆角方 / 3 心形 / 4 六边形" },
    "spin": { "type": "float", "default": 0.6, "min": -3, "max": 3, "label": "旋转（弧度）" },
    "outline": { "type": "float", "default": 0.012, "min": 0, "max": 0.05, "label": "描边粗细" },
    "lineColor": { "type": "color", "default": "#ffd23f", "label": "描边颜色" },
    "closeFirst": { "type": "bool", "default": false, "label": "先收后放（旧镜头先收成图形再黑场，再放开新镜头）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：圈入圈出", "note": "按思路自写；gl-transitions 有 heart/StarWipe/circleopen 等单一形状，这里统一为可选形状 + 描边 + 旋转 + 先收后放" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（默片时代的“光圈转场”、卡通片的圈入圈出）：摄影机前的光圈收小成一个形状、黑场，再打开到下一个场景；
// 后来卡通片把圆换成了星形、心形等。实现：图形的有符号距离场，半径随进度变化，内部显示新镜头，边缘描一圈彩线。

float sdShape(vec2 p, float k) {
  int s = int(floor(k + .5));
  if (s == 0) {                                          // 五角星
    float a = atan(p.x, p.y), r = length(p);
    float seg = 6.2832 / 5.;
    float m = mod(a + seg * .5, seg) - seg * .5;
    return r - mix(.42, 1., pow(1. - abs(m) / (seg * .5), 1.6)) * .55;   // 角尖处半径大、凹处小
  }
  if (s == 1) return (abs(p.x) + abs(p.y)) * .72 - .5;  // 菱形
  if (s == 2) { vec2 q = abs(p) - .38; return length(max(q, 0.)) + min(max(q.x, q.y), 0.) - .12; }
  if (s == 3) {                                          // 心形
    p.y -= .1; p.x = abs(p.x);
    float a = atan(p.x, p.y) / 3.1416, r = length(p);
    float h = abs(a);
    float d = (13. * h - 22. * h * h + 10. * h * h * h) / (6. - 5. * h);
    return r - d * .32;
  }
  vec2 q = abs(p);                                       // 六边形
  return max(q.x * .866 + q.y * .5, q.y) - .5;
}

vec4 transition(vec2 uv) {
  vec3 a = getFromColor(uv).rgb, b = getToColor(uv).rgb;
  vec2 p = (uv - vec2(centerX, centerY)) * vec2(ratio, 1.);
  float pr = progress;
  // ① 半径：直接放开（0 → 能盖住全屏），或先收（旧镜头收成图形到 0）再放开
  float maxR = 2.6;
  float R; bool showNew;
  if (closeFirst) { showNew = pr > .5; float t = showNew ? (pr - .5) * 2. : 1. - pr * 2.; R = pow(t, 1.5) * maxR; }
  else { showNew = true; R = pow(pr, 1.6) * maxR; }
  // ② 旋转的图形距离场（按半径缩放）
  vec2 q = fxRot(spin * pr) * p / max(R, 1e-4);
  float d = sdShape(q, shape) * R;
  float inside = smoothstep(.002, -.002, d);
  vec3 outsideC = closeFirst ? vec3(0.) : a;
  vec3 insideC = closeFirst ? (showNew ? b : a) : b;
  vec3 c = mix(outsideC, insideC, inside);
  // ③ 描边
  float line = smoothstep(outline, outline * .5, abs(d)) * step(.001, R) * step(R, maxR * .98);
  c = mix(c, lineColor, line);
  return vec4(c, 1.);
}
