/*@effect
{
  "id": "gen-clouds-drift",
  "name": "云层飘过",
  "kind": "post",
  "category": "生成层",
  "tags": ["clouds", "sky", "drift", "timelapse", "dreamy", "云", "天空", "延时", "梦幻"],
  "summary": "画面上部飘过一层蓬松的立体云（顶部受光亮、底部背光暗），云层横向漂移像延时摄影，云的边缘半透明；音乐能量越高云飘得越快。",
  "when": "空镜与风景、梦幻与天堂意象、时间流逝、抒情段落；给单调的天空加层次。",
  "avoid": "室内或夜景（云的受光会不对，可调 lit 颜色）；天空区域有重要文字时。",
  "params": {
    "cover": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "云量" },
    "height": { "type": "float", "default": 0.55, "min": 0, "max": 1, "label": "云层下沿（从底部算）" },
    "speed": { "type": "float", "default": 0.03, "min": 0, "max": 0.3, "label": "飘移速度" },
    "lit": { "type": "color", "default": "#fff4e6", "label": "受光色" },
    "shadow": { "type": "color", "default": "#8a8fa8", "label": "背光色" },
    "gust": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量加速（通常由音乐能量驱动）" }
  },
  "bindings": { "gust": { "to": "energy", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：天空生成层", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：积云是一团团蓬松的水汽，阳光从上方照下，云顶亮白、云底因为被上层遮挡而发灰；
// 云的边缘是渐变的半透明；延时摄影里云层匀速横向漂移，形状缓慢变化。
// 实现：分形噪声作“云密度”，用“往太阳方向偏移再取一次密度”估计自遮挡（偏移处密度越大越暗）。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float t = uTime * speed * (1. + gust * 2.);
  vec2 q = p * vec2(1.6, 2.4) - vec2(t, 0.);
  // ① 云密度：分形噪声，按云量阈值，并只在 height 以上出现（向上淡出到画面顶部）
  float d = fxFbm(q + fxFbm(q * .6 + t * .3));
  float cov = smoothstep(1. - cover * .7 - .15, 1. - cover * .7 + .2, d);
  cov *= smoothstep(height - .05, height + .15, uv.y);
  // ② 自遮挡：往上方（太阳方向）偏移再取一次密度，越密 → 本处越暗
  float above = fxFbm(q + vec2(0., .08) + fxFbm((q + vec2(0., .08)) * .6 + t * .3));
  float light = clamp(1. - (above - d) * 4. - .2, 0., 1.);
  vec3 cloud = mix(shadow, lit, light);
  return vec4(mix(src, cloud, cov * .92), 1.);
}
