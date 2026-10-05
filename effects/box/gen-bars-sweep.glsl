/*@effect
{
  "id": "gen-bars-sweep",
  "name": "动感色条扫过",
  "kind": "post",
  "category": "生成层",
  "tags": ["motion graphics", "bars", "stripes", "sweep", "promo", "色条", "动态图形", "扫屏", "宣传片"],
  "summary": "几条不同颜色、不同粗细的斜向色条按小节依次快速扫过画面（类似 MG 动画的过渡色块），色条之间留白透出画面；可作为两段内容之间的装饰性冲击。",
  "when": "宣传片/促销/体育/综艺的节奏段落、标题出现前的“开场色条”、MG 动画风格的包装。",
  "avoid": "安静叙事；需要持续看清画面的镜头（色条会周期性盖住画面）。",
  "params": {
    "bars": { "type": "float", "default": 4, "min": 1, "max": 8, "label": "色条数" },
    "angle": { "type": "float", "default": 0.4, "min": -1.2, "max": 1.2, "label": "倾斜（弧度）" },
    "width": { "type": "float", "default": 0.12, "min": 0.02, "max": 0.4, "label": "色条宽度" },
    "c1": { "type": "color", "default": "#ff4d12", "label": "颜色 1" },
    "c2": { "type": "color", "default": "#ffd23f", "label": "颜色 2" },
    "c3": { "type": "color", "default": "#1e1e24", "label": "颜色 3" },
    "every": { "type": "float", "default": 1, "min": 0.25, "max": 4, "label": "每几个小节扫一次" },
    "barSeconds": { "type": "float", "default": 2, "min": 0.5, "max": 8, "label": "小节时长（秒，= 240 / BPM；扫动周期 = 小节时长 × every）" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：MG 色块过渡", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（MG 动画的“色块扫屏”）：设计师在段落之间放几条品牌色的斜色条，先后从画面一侧飞到另一侧，
// 速度快、带强缓动，制造节奏感与“翻篇”的感觉。节拍：扫动由小节相位直接驱动（每 every 个小节一次），本质上就是卡在小节线上，
// 因此不需要额外的节拍绑定参数。

vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = (uv - .5) * asp;
  float s = dot(p, vec2(cos(angle), sin(angle)));          // 色条法线方向坐标
  float along = dot(p, vec2(-sin(angle), cos(angle)));
  // ① 扫动相位：每 every 个小节扫一次（周期 = 小节时长 × every，与歌曲时间对齐），扫动占周期的大部分（色条持续在画面里穿行）
  float ph = fract(uTime / (max(barSeconds, .1) * every));
  float n = floor(bars + .5);
  for (int i = 0; i < 8; i++) {
    float fi = float(i);
    if (fi >= n) break;
    // ② 每条错开一点出发，强缓出（快进快出），从 -1.5 扫到 +1.5（屏外到屏外）
    float t = clamp((ph - fi * .04) / .8, 0., 1.);
    float e = mix(t, t * t * (3. - 2. * t), .6);         // 中段略快、两端略缓，色条在画面里停留更久
    float pos = mix(-1.2, 1.2, e) + (fi - n * .5) * width * .3;
    float w = width * (.5 + .9 * fxHash(vec2(fi, 4.)));
    float m = smoothstep(w * .5 + .002, w * .5, abs(s - pos * 1.2));            // 色条沿法线方向（垂直于条身）移动
    vec3 col = mod(fi, 3.) < 1. ? c1 : mod(fi, 3.) < 2. ? c2 : c3;
    c = mix(c, col, m * step(.001, t) * step(t, .999));
  }
  return vec4(c, 1.);
}
