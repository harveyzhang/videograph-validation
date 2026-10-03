/*@effect
{
  "id": "split-screen",
  "name": "分屏",
  "kind": "post",
  "category": "画面版式",
  "tags": ["split screen", "multi panel", "triptych", "layout", "分屏", "多分格", "三联屏", "并列"],
  "summary": "把画面竖着分成 2–4 格，每格显示同一画面的不同局部（像多机位并列），格间有细缝；每格依次从上方滑入，鼓点时高亮的那一格轮换。",
  "when": "多人物/多场景并列、对比（前后/左右）、节奏感强的时尚与音乐片段、“同一时刻不同地点”。",
  "avoid": "画面主体只有一个且需要完整看到时。",
  "params": {
    "panels": { "type": "float", "default": 3, "min": 2, "max": 4, "label": "分格数" },
    "gap": { "type": "float", "default": 0.008, "min": 0, "max": 0.04, "label": "格缝宽度" },
    "spread": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "各格取景差异" },
    "inEnd": { "type": "float", "default": 0.25, "min": 0, "max": 0.8, "label": "滑入完成于镜头进度" },
    "focus": { "type": "float", "default": 0, "min": 0, "max": 0.5, "label": "鼓点高亮（通常由节拍驱动）" },
    "gapColor": { "type": "color", "default": "#0a0a0b", "label": "格缝颜色" }
  },
  "bindings": { "focus": { "to": "kick", "amount": 0.3 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/spy-titles 与 swiss-motion：分屏版式", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（60 年代电影与现代 MV 的分屏）：把几个机位的画面并排放在一帧里，观众同时看到几个视角；
// 这里没有多机位素材，就用同一画面的不同取景（平移）来模拟，每格依次入场。

vec4 effect(vec2 uv) {
  float n = floor(panels + .5);
  float k = floor(uv.x * n);
  float fx = fract(uv.x * n);
  // ① 每格的取景：每格是原画面中心区域的一个竖条“窗口”，窗口中心按格序号在 [0.5 - spread/2, 0.5 + spread/2] 间分布，
  //    窗口宽度 = 1/n（与格宽一致，不变形）；相邻格看到的是彼此错开的画面（像几个机位）。
  float center = .5 + ((k + .5) / n - .5) * spread;
  // 每格还按自己的节奏轻微推拉，让几格不像同一画面的切片
  float zoom = 1. + .08 * sin(uTime * .7 + k * 2.1);
  // ② 依次滑入：第 k 格从上方滑下（强缓出）
  float t = inEnd <= 0. ? 1. : clamp((uProgress / inEnd - k / n * .5) / .5, 0., 1.);
  float yoff = pow(1. - t, 3.);
  float y = uv.y - yoff;
  if (y < 0.) return vec4(gapColor, 1.);
  vec2 q = vec2(center + (fx - .5) / n / zoom, .5 + (y - .5) / zoom);
  vec3 c = srcTex(q).rgb;
  // ③ 鼓点高亮：当前拍对应的那一格提亮，其余略暗（focus 挂 kick）
  float lit = step(abs(mod(floor(uBar * 4.), n) - k), .5);
  c *= 1. + focus * (lit * 1. - (1. - lit) * .6);
  // ④ 格缝
  float g = gap * n * .5;
  float inGap = step(fx, g) * step(.5, k) + step(1. - g, fx) * step(k, n - 1.5);
  return vec4(mix(c, gapColor, inGap), 1.);
}
