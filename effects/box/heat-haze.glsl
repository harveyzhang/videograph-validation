/*@effect
{
  "id": "heat-haze",
  "name": "热浪扭曲",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["heat haze", "mirage", "shimmer", "desert", "heat distortion", "热浪", "蜃景", "空气扭曲", "沙漠"],
  "summary": "像隔着灼热的空气看：画面下部（热源附近）不停地细碎抖动、向上流动，越往上越弱；音乐能量越高热浪越猛。",
  "when": "沙漠/公路/夏天正午、火焰与引擎尾气旁、焦躁与压迫的情绪、西部片。",
  "avoid": "清凉/冬季画面；需要锐利文字的镜头。",
  "params": {
    "strength": { "type": "float", "default": 0.014, "min": 0, "max": 0.04, "label": "扭曲强度" },
    "height": { "type": "float", "default": 0.75, "min": 0.1, "max": 1, "label": "影响高度（从底部算）" },
    "rise": { "type": "float", "default": 0.6, "min": 0, "max": 3, "label": "上升速度" },
    "boil": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量加剧（通常由音乐能量驱动）" }
  },
  "bindings": { "boil": { "to": "energy", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：扭曲与空气感", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：热的空气密度低、折射率小，地面上方冷热空气混合成不断上升的湍流团，光穿过时方向被反复改变——
// 远处景物看起来在抖动、流动（蜃景）；越靠近热源扰动越强。

vec4 effect(vec2 uv) {
  // ① 强度随高度衰减：画面底部最强，height 以上无扰动
  float w = smoothstep(height, 0., uv.y) * (1. + boil * 1.5);
  // ② 湍流：两层向上流动的噪声（细 + 粗），给出横向为主、纵向为辅的位移
  float t = uTime * rise * (1. + boil);
  vec2 q = uv * vec2(uRes.x / uRes.y, 1.);
  float n1 = fxNoise(q * vec2(30., 14.) - vec2(0., t * 3.)) - .5;
  float n2 = fxNoise(q * vec2(9., 5.) - vec2(t * .3, t * 1.2) + 7.) - .5;
  vec2 off = vec2(n1 * .8 + n2 * .5, (n2 - n1) * .35) * strength * w;
  // ③ 取样 + 极轻的亮度起伏（空气团的透镜聚光）
  vec3 c = srcTex(uv + off).rgb * (1. + n1 * .04 * w);
  // ④ 热空气里的灰尘与水汽让底部略偏暖、反差略降（随强度）
  c = mix(c, c * vec3(1.1, 1., .85) + .05, .45 * min(w, 1.));
  return vec4(c, 1.);
}
