/*@effect
{
  "id": "gen-light-rays-top",
  "name": "天光丁达尔",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["light rays", "crepuscular", "forest light", "church", "heavenly", "天光", "丁达尔", "光柱", "神圣"],
  "summary": "从画面顶部斜照下来一排平行的光柱（像穿过树林或教堂高窗的阳光），光柱宽窄不一、缓慢摇曳，越往下越淡；音乐能量越高光越强。不依赖画面里有没有亮处。",
  "when": "森林/教堂/神圣与希望、清晨、救赎与觉醒的段落、给暗淡的画面加“天光”。",
  "avoid": "夜景或室内无窗的场景（光源不合理）；与 god-rays（从画面亮处放射）选一个即可。",
  "params": {
    "angle": { "type": "float", "default": 0.35, "min": -1, "max": 1, "label": "倾斜（弧度）" },
    "rays": { "type": "float", "default": 9, "min": 2, "max": 30, "label": "光柱数" },
    "intensity": { "type": "float", "default": 0.4, "min": 0, "max": 1.2, "label": "亮度" },
    "reach": { "type": "float", "default": 0.75, "min": 0.2, "max": 1.2, "label": "照射深度" },
    "tint": { "type": "color", "default": "#fff0c8", "label": "光色" },
    "swell": { "type": "float", "default": 0, "min": 0, "max": 0.6, "label": "能量增强（通常由音乐能量驱动）" }
  },
  "bindings": { "swell": { "to": "energy", "amount": 0.3 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：光柱", "note": "按思路自写；与 god-rays 不同：平行光柱从顶部射入，不取画面亮度" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：阳光从树冠缝隙或高窗射入有薄雾/灰尘的空间，形成一束束近乎平行的光柱（太阳很远，光线平行）；
// 光柱的宽窄由缝隙决定，树叶晃动时光柱也跟着轻轻摇曳；离入口越远光越弱。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 斜坐标：沿光柱方向的“横向位置”
  float across = uv.x + (1. - uv.y) * tan(angle);
  // ② 光柱：横向的一维噪声做出宽窄不一、明暗不一的条纹，随时间缓慢漂移（摇曳）
  float n = fxNoise(vec2(across * rays, uTime * .15)) * .6 + fxNoise(vec2(across * rays * 2.3 + 5., uTime * .25)) * .4;
  float beam = smoothstep(.45, .8, n);
  // ③ 深度衰减：从顶部往下渐淡；加一点雾的颗粒
  float fall = smoothstep(1. - reach, 1., uv.y);
  float dust = .85 + .15 * fxNoise(uv * uRes * .05 + uTime * .2);
  float L = beam * fall * dust * (intensity + swell);
  vec3 c = 1. - (1. - src) * (1. - clamp(tint * L, 0., 1.));
  return vec4(c, 1.);
}
