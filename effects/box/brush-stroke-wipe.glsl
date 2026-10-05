/*@effect
{
  "id": "brush-stroke-wipe",
  "name": "笔刷涂抹转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["brush", "paint stroke", "wipe", "artistic", "handmade", "笔刷", "涂抹", "画笔", "手绘转场"],
  "summary": "几道粗犷的颜料笔刷从左到右一笔接一笔扫过画面，每一笔都带干笔飞白与毛糙边缘，笔刷扫过的地方露出下一个镜头；笔与笔之间上下错开、略带倾斜。",
  "when": "艺术/手作/绘画题材、旅行 vlog、潮流与运动品牌、活泼的段落衔接。",
  "avoid": "利落干净的商务风格。时长建议 0.6–1.2 秒。",
  "params": {
    "strokes": { "type": "float", "default": 4, "min": 1, "max": 10, "label": "笔数" },
    "rough": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "笔触毛糙" },
    "tilt": { "type": "float", "default": 0.08, "min": -0.4, "max": 0.4, "label": "笔触倾斜" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/urban-sketch 与 impasto：笔触", "note": "只参考风格名称与观感描述，代码为本项目自写；gl-transitions 无笔刷转场" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：用一把宽扁刷蘸颜料在画布上横扫，每一笔是一条有起笔、收笔的宽带，边缘毛糙（刷毛分叉），
// 颜料不足的地方露出底下（干笔飞白）。几笔叠在一起把画面盖满。这里每一笔扫过的地方“刷出”下一个镜头。

vec4 transition(vec2 uv) {
  vec3 a = getFromColor(uv).rgb, b = getToColor(uv).rgb;
  float n = floor(strokes + .5);
  float reveal = 0.;
  for (int i = 0; i < 10; i++) {
    float fi = float(i);
    if (fi >= n) break;
    // ① 第 i 笔：覆盖一条横带（略宽于 1/n，相邻带重叠），带中心 + 倾斜
    float h = 1.2 / n;
    float cy = (fi + .5) / n + (uv.x - .5) * tilt * (mod(fi, 2.) < 1. ? 1. : -1.);
    float dy = abs(uv.y - cy);
    // 边缘毛糙：刷毛（高频竖向噪声）+ 整体起伏
    float edgeN = (fxNoise(vec2(uv.x * 80., fi * 7.)) - .5) * .25 * rough + (fxNoise(vec2(uv.x * 4., fi)) - .5) * .2;
    float band = smoothstep(h * .5 + .02, h * .5 - .02, dy + edgeN * h);
    // ② 笔头进度：每笔依次开始，从左扫到右（奇数笔可从右往左），笔头处有圆钝的形状
    float t = clamp(progress * (n * .6 + 1.) - fi * .6, 0., 1.);
    float x = mod(fi, 2.) < 1. ? uv.x : 1. - uv.x;
    float head = t * 1.25 - .1 + sin(dy / h * 3.1416) * .04;
    float stroke = band * smoothstep(head + .01, head - .01, x);
    // ③ 干笔飞白：沿笔触方向的纤维噪声，靠近笔尾（起笔处）更少飞白
    float fiber = fxNoise(vec2(uv.x * 6., uv.y * 140. + fi * 13.));
    stroke *= 1. - step(fiber, rough * .35) * smoothstep(head - .3, head, x);
    reveal = max(reveal, stroke);
  }
  if (progress >= .999) reveal = 1.;
  return vec4(mix(a, b, reveal), 1.);
}
