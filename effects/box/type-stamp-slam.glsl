/*@effect
{
  "id": "type-stamp-slam",
  "name": "印章砸字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "stamp", "slam", "impact", "rubber stamp", "文字动画", "盖章", "砸入", "冲击"],
  "summary": "文字像橡皮图章一样从很大、半透明的状态猛地砸到画面上：落下瞬间整个画面一震，字带上红色印泥质感（斑驳、边缘不齐、略微旋转），砸下处扬起一圈墨点。",
  "when": "“通过/驳回/机密/SOLD”式的结论、综艺花字、标题强调、重拍卡点。",
  "avoid": "柔和抒情的字幕；文字压在复杂背景上（原位用补底色）。",
  "params": {
    "hitAt": { "type": "float", "default": 0.12, "min": 0.01, "max": 0.9, "label": "砸下时刻（镜头进度）" },
    "ink": { "type": "color", "default": "#d4232b", "label": "印泥颜色" },
    "tilt": { "type": "float", "default": -0.08, "min": -0.5, "max": 0.5, "label": "印章歪斜（弧度）" },
    "wear": { "type": "float", "default": 0.45, "min": 0, "max": 1, "label": "印泥斑驳" },
    "shake": { "type": "float", "default": 0.012, "min": 0, "max": 0.04, "label": "落下震动" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" },
    "thump": { "type": "float", "default": 0, "min": 0, "max": 0.1, "label": "鼓点再砸（通常由节拍驱动）" }
  },
  "bindings": { "thump": { "to": "kick", "amount": 0.03 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：砸字冲击", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：盖章时印章从高处快速落下（离纸越远看起来越大、越虚），接触纸面的一刻压力最大，印泥被挤出；
// 印出来的字有斑驳的缺墨、边缘的毛刺，通常还有点歪。动态版本在落下瞬间让画面震一下。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float p = uProgress;
  float t = clamp(p / hitAt, 0., 1.);                       // 0 → 1：落下过程
  float after = max(p - hitAt, 0.);
  // ① 落下：缩放从 2.2 → 1（加速），透明度从 0 → 1
  float s = mix(2.2, 1., t * t) + thump;
  float alpha = smoothstep(0., .6, t);
  // ② 落地震动：落下后 0.05 进度内画面衰减抖动
  float sk = shake * exp(-after * 60.) * step(.999, t) * sin(after * 400.);
  vec2 uvS = uv + vec2(sk, sk * .6);
  vec3 base = srcTex(uvS).rgb;
  base = mix(base, bg, inkOf(base));
  // ③ 印章字：绕画面中心缩放 + 歪斜
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 q = fxRot(-tilt) * ((uvS - .5) * asp) / s / asp + .5;
  float m = inkOf(srcTex(q).rgb);
  // ④ 印泥质感：斑驳缺墨（噪声）、边缘毛刺；落地前半透明且偏虚
  float n = fxNoise(uv * uRes * .15) * .6 + fxNoise(uv * uRes * .5) * .4;
  float worn = smoothstep(wear * .55, wear * .55 + .15, n);
  m *= mix(1., worn, step(.999, t)) * alpha;
  vec3 c = mix(base, ink * (.85 + .15 * n), m);
  // ⑤ 墨点：落地瞬间在字周围溅出少量小点（落下后 0.1 进度内淡出）
  vec2 g = floor(uv * uRes / 3.);
  float spat = step(.993, fxHash(g)) * exp(-after * 25.) * step(.999, t) * step(length((uv - .5) * asp), .5);
  c = mix(c, ink, spat);
  return vec4(c, 1.);
}
