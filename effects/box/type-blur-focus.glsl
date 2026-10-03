/*@effect
{
  "id": "type-blur-focus",
  "name": "模糊聚焦入场",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "blur in", "focus pull", "fade in", "cinematic title", "文字动画", "模糊入场", "对焦", "电影片名"],
  "summary": "文字从一团柔和的发光模糊中逐渐对焦清晰（同时略微从大变到正常），像电影片名浮现；结尾再失焦散开消失。背景保持清晰不动。",
  "when": "电影感片名、情绪化金句、回忆与梦境、慢节奏抒情段落的歌词。",
  "avoid": "文字压在复杂画面上（字周围的模糊光晕会盖住一点背景，原位用补底色）；快节奏卡点。",
  "params": {
    "inEnd": { "type": "float", "default": 0.35, "min": 0.05, "max": 0.9, "label": "清晰于镜头进度" },
    "outStart": { "type": "float", "default": 0.88, "min": 0.4, "max": 1, "label": "失焦开始（1 = 不消失）" },
    "blur": { "type": "float", "default": 0.025, "min": 0.005, "max": 0.08, "label": "最大模糊半径（画面高度比例）" },
    "grow": { "type": "float", "default": 0.08, "min": 0, "max": 0.3, "label": "入场缩放幅度" },
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 0.3, "label": "鼓点轻微失焦（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" }
  },
  "bindings": { "pulse": { "to": "kick", "amount": 0.12 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：片名浮现", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（拉焦）：摄影助理转动跟焦环，被摄字幕卡从焦外的柔光一团慢慢变成锐利的字；
// 焦外时字的亮部扩散成光晕、整体看起来更大一点（呼吸效应）。这里只对“字”做：原位擦掉，再画一个模糊 + 缩放版本。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 对焦进度：入场 0→1（缓出），出场 1→0；鼓点时轻微失焦（pulse 挂 kick）
  float p = uProgress;
  float f = 1. - pow(1. - clamp(p / inEnd, 0., 1.), 3.);
  if (outStart < .999) f *= 1. - clamp((p - outStart) / (1. - outStart), 0., 1.);
  float defocus = clamp(1. - f + pulse, 0., 1.);
  // ② 呼吸缩放：失焦时字略大（以画面中心为基准）
  float s = 1. + grow * defocus;
  vec2 q = (uv - .5) / s + .5;
  // ③ 焦外模糊：黄金角螺旋 12 次采样，只累计“字”的颜色与覆盖率
  float r = blur * defocus;
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  vec3 acc = vec3(0.); float cov = 0.;
  for (int i = 0; i < 12; i++) {
    float a = float(i) * 2.39996;
    vec2 o = vec2(cos(a), sin(a)) * r * sqrt((float(i) + .5) / 12.) * asp;
    vec3 sc = srcTex(q + o).rgb;
    float m = inkOf(sc);
    acc += sc * m; cov += m;
  }
  cov /= 12.;
  vec3 col = acc / max(cov * 12., 1e-3);
  // ④ 合成：原位的字擦掉 → 叠上模糊/清晰的字（覆盖率随对焦变淡变实，整体透明度跟着对焦淡入）
  vec3 c = mix(src, bg, inkOf(src));
  float alpha = clamp(cov * (1.3 + defocus), 0., 1.) * mix(.25, 1., f);
  c = mix(c, col * (1. + defocus * .4), alpha);
  return vec4(c, 1.);
}
