/*@effect
{
  "id": "gen-flow-lines",
  "name": "流场光丝",
  "kind": "post",
  "category": "生成层",
  "tags": ["flow field", "curl noise", "streamlines", "generative art", "silk", "流场", "生成艺术", "光丝", "丝绸"],
  "summary": "画面上流动着一层沿旋度噪声流场排列的细光丝，像风中的丝绸或磁感线；光丝取原画面的颜色，随时间沿流线滑动，鼓点时流速一冲。",
  "when": "科技/AI/数据主题、抽象 MV、能量感与“流动”的意象、产品背景的高级感纹理。",
  "avoid": "需要干净背景的文字/产品特写（可调低 opacity）；写实纪录风格。",
  "params": {
    "scale": { "type": "float", "default": 2.2, "min": 0.5, "max": 8, "label": "流场尺度" },
    "lines": { "type": "float", "default": 36, "min": 10, "max": 200, "label": "光丝密度" },
    "flow": { "type": "float", "default": 0.3, "min": 0, "max": 2, "label": "流速（通常由节拍驱动）" },
    "opacity": { "type": "float", "default": 0.55, "min": 0, "max": 1, "label": "光丝强度" },
    "useSource": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "取原画面颜色（0 = 用光丝色）" },
    "lineColor": { "type": "color", "default": "#8fd3ff", "label": "光丝色" }
  },
  "bindings": { "flow": { "to": "kick", "amount": 1.2 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：生成艺术/流场", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（生成艺术）：在平面上放一个“流场”（每一点都有一个方向），从很多起点出发沿方向走，画下轨迹——
// 得到一束束平滑、互不交叉的流线（像铁屑显示的磁感线、风中的丝）。旋度噪声（噪声的旋转梯度）保证流线不汇聚。
// 实现（逐像素）：从当前点沿流场“倒着走” 10 步，用起点的 ID 决定这条流线是否亮、亮在哪一段——相当于线积分卷积。

vec2 curl(vec2 p) {
  float e = .01;
  float n1 = fxNoise(p + vec2(0., e)), n2 = fxNoise(p - vec2(0., e));
  float n3 = fxNoise(p + vec2(e, 0.)), n4 = fxNoise(p - vec2(e, 0.));
  return normalize(vec2(n1 - n2, -(n3 - n4)) + 1e-5);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp * scale;
  float t = uTime * .05;

  // ① 沿流场往回追 10 步，累计弧长；最终位置附近的“横向坐标”（垂直于流向）决定这是第几条丝。
  vec2 q = p;
  for (int i = 0; i < 10; i++) q -= curl(q + t) * .02;
  vec2 dir = curl(q + t);
  float across = dot(q, vec2(-dir.y, dir.x)) * lines / scale;
  float lane = floor(across);

  // ② 一条丝的亮度：横向是细线（宽约 25% 车道），纵向是沿流动方向滑动的亮段（像光在丝上流过）。
  //    flow 挂鼓点：鼓点那一下光段滑得更快。
  float lw = max(fwidth(across) * 1.2, .06);              // 线宽：约 1 像素，且至少车道的 6%
  float w = smoothstep(lw, 0., abs(fract(across) - .5));
  float along = dot(q, dir) * 6. + uTime * flow * 2. + fxHash(vec2(lane, 3.)) * 10.;
  float seg = smoothstep(.0, .3, fract(along)) * smoothstep(1., .5, fract(along));
  float on = step(.55, fxHash(vec2(lane, 9.)));          // 只有一部分车道有丝（留出呼吸）
  float line = w * seg * on;

  // ③ 颜色：取原画面颜色（提亮）或固定光丝色；加光叠加。
  vec3 lc = mix(lineColor, clamp(src * 1.6 + .1, 0., 1.), useSource);
  vec3 c = 1. - (1. - src) * (1. - clamp(lc * line * opacity, 0., 1.));
  return vec4(c, 1.);
}
