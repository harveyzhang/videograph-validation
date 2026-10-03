/*@effect
{
  "id": "frosted-glass",
  "name": "磨砂玻璃",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["frosted glass", "blur", "privacy glass", "mist", "window", "磨砂玻璃", "雾面", "朦胧", "窗"],
  "summary": "隔着一块磨砂玻璃：画面被打散成细碎颗粒的朦胧模糊，中间有一块像被手擦干净的清晰窗口，窗口随拍一张一缩。",
  "when": "揭示/悬念（主体从朦胧中清晰）、浴室与雨窗、回忆与梦、隐私与距离感的叙事。",
  "avoid": "需要全画面清楚的信息镜头。",
  "params": {
    "frost": { "type": "float", "default": 0.012, "min": 0, "max": 0.04, "label": "磨砂程度（散射距离）" },
    "clearX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "擦拭窗口 X" },
    "clearY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "擦拭窗口 Y" },
    "clear": { "type": "float", "default": 0.18, "min": 0, "max": 0.6, "label": "清晰窗口大小（通常由节拍驱动）" },
    "tint": { "type": "color", "default": "#e6eef2", "label": "玻璃色" }
  },
  "bindings": { "clear": { "to": "beat", "amount": 0.04 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：模糊与揭示", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：磨砂玻璃表面是无数微小的凹凸，每一点把身后的光随机散射到周围，所以画面是“颗粒状”的模糊而不是平滑模糊；
// 用手擦过的地方凹凸被水汽填平，变回透明；玻璃本身带一点白（散射的环境光）。

vec4 effect(vec2 uv) {
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  // ① 擦拭窗口：椭圆形，边缘不规则（手擦的痕迹），清晰度从中心向外过渡
  vec2 d = (uv - vec2(clearX, clearY)) / asp;
  float edgeN = (fxNoise(uv * 12.) - .5) * .06;
  float wiped = smoothstep(clear + .04, clear - .02, length(d * vec2(.8, 1.)) + edgeN);

  // ② 散射：8 个随机方向的采样（每个像素的随机旋转不同 → 颗粒感），在窗口内散射为 0
  float r = frost * (1. - wiped);
  float rot = fxHash(floor(uv * uRes)) * 6.2832;
  vec3 acc = vec3(0.);
  for (int i = 0; i < 8; i++) {
    float a = rot + float(i) * 2.39996;
    float rr = r * sqrt((float(i) + .5) / 8.);
    acc += srcTex(uv + vec2(cos(a), sin(a)) * rr * asp).rgb;
  }
  vec3 c = acc / 8.;

  // ③ 玻璃的白：磨砂区域蒙一层浅色（散射的环境光），窗口内不蒙
  c = mix(c, tint, .18 * (1. - wiped));
  return vec4(c, 1.);
}
