/*@effect
{
  "id": "gen-bubbles",
  "name": "上升气泡",
  "kind": "post",
  "category": "生成层",
  "tags": ["bubbles", "underwater", "soda", "float", "refraction", "气泡", "水下", "汽水", "上升"],
  "summary": "大小不一的透明气泡从下往上浮起，边缘有一圈亮边、一侧有小高光，气泡里的画面被放大折射；每一拍冒出一串新的小气泡。",
  "when": "水下与海洋、汽水/啤酒/饮料广告、清新夏日、梦幻与童趣、护肤品。",
  "avoid": "干燥/火焰/沙漠题材；需要稳定观看文字的镜头。",
  "params": {
    "density": { "type": "float", "default": 0.28, "min": 0, "max": 1, "label": "气泡数量" },
    "size": { "type": "float", "default": 0.035, "min": 0.008, "max": 0.12, "label": "气泡大小（画面高度比例）" },
    "rise": { "type": "float", "default": 0.12, "min": 0.02, "max": 0.5, "label": "上升速度" },
    "lens": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "折射放大" },
    "fizz": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "随拍冒泡（通常由节拍驱动）" },
    "rim": { "type": "color", "default": "#e6fbff", "label": "亮边颜色" }
  },
  "bindings": { "fizz": { "to": "beat", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：上升粒子", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：水中的气泡是一个球形的“空气透镜”：边缘处光线发生全反射，所以轮廓是一圈亮边；
// 迎光的一侧有一个小小的高光点；透过气泡看到的东西被翻转/放大。气泡越大上升越快，并且左右摇摆。

vec4 effect(vec2 uv) {
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float cs = size * 3.;
  float dens = clamp(density + fizz * .3, 0., 1.);
  vec2 bestOff = vec2(0.);
  float ring = 0., spec = 0., inside = 0.;

  // ① 气泡：每格最多一个，整列上升（大气泡更快），左右摇摆；检查本格与下方一格（上升时会跨格）。
  for (int L = 0; L < 2; L++) {
    float sc = cs * (1. + float(L) * .8);
    vec2 q = p / sc;
    q.y -= uTime * rise * (1. + float(L) * .6) / sc;
    for (int j = 0; j < 2; j++) {
      vec2 id = floor(q) - vec2(0., float(j));
      float h = fxHash(id + float(L) * 9.);
      if (h > dens) continue;
      vec2 c = id + vec2(.25 + .5 * fxHash(id + 1.3), fxHash(id + 2.1));
      c.x += sin(uTime * 2. + h * 30. + q.y) * .12;
      float r = (.2 + .25 * fxHash(id + 3.7)) * (1. + float(L) * .3);
      vec2 d = q - c;
      float dl = length(d) / r;
      if (dl < 1.05) {
        // ② 折射：气泡内部按“球面透镜”放大（中心几乎不动，越靠边偏移越大），取最近的一个气泡。
        bestOff = -d / r * sqrt(max(1. - dl * dl, 0.)) * r * sc * lens * .5;
        inside = max(inside, smoothstep(1.02, .95, dl));
        // ③ 亮边与高光：边缘全反射的一圈 + 左上方的小高光
        ring = max(ring, smoothstep(.75, 1., dl) * smoothstep(1.05, .98, dl));
        spec = max(spec, smoothstep(.22, .05, length(d / r - vec2(-.38, .4))));
      }
    }
  }

  // ④ 合成：气泡内是折射后的画面（略亮略冷），叠亮边与高光；1 次额外采样。
  vec3 src = srcTex(uv).rgb;
  vec3 bent = srcTex(uv + bestOff / vec2(uRes.x / uRes.y, 1.)).rgb;
  vec3 c = mix(src, bent * 1.05 + vec3(.02, .04, .06), inside);
  c = 1. - (1. - c) * (1. - clamp(rim * (ring * .85 + spec), 0., 1.));
  return vec4(c, 1.);
}
