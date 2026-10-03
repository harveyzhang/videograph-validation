/*@effect
{
  "id": "gen-ink-drops",
  "name": "水中墨滴",
  "kind": "post",
  "category": "生成层",
  "tags": ["ink in water", "ink drop", "smoke ink", "fluid", "abstract", "墨滴", "水墨", "流体", "晕染"],
  "summary": "一滴滴彩墨落进清水般的画面：墨从落点向下沉、同时翻卷成蘑菇云状的烟丝并缓慢扩散；每个小节开头落下新的一滴，颜色轮换。",
  "when": "艺术与高端品牌、香水/化妆品、抽象 MV 段落、转场前的“晕开”、情绪与灵感的意象。",
  "avoid": "需要看清画面内容的镜头（墨会盖住画面，调 opacity）。",
  "params": {
    "opacity": { "type": "float", "default": 0.9, "min": 0, "max": 1, "label": "墨的浓度" },
    "spread": { "type": "float", "default": 0.35, "min": 0.1, "max": 0.8, "label": "扩散范围" },
    "barSeconds": { "type": "float", "default": 2, "min": 0.5, "max": 8, "label": "每滴间隔（秒，设为一小节时长即每小节一滴）" },
    "c1": { "type": "color", "default": "#1b2a8a", "label": "墨色 1" },
    "c2": { "type": "color", "default": "#c2185b", "label": "墨色 2" },
    "c3": { "type": "color", "default": "#0a0a0b", "label": "墨色 3" },
    "churn": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量翻腾（通常由音乐能量驱动）" }
  },
  "bindings": { "churn": { "to": "energy", "amount": 0.5 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/ink-wash：水墨意象", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（广告摄影的“水中墨”）：墨水比水重，滴进水里后向下沉，下沉的前端被水的阻力翻卷成蘑菇云状的涡环，
// 尾部拉出细丝；随着扩散墨越来越淡。实现：每滴墨 = 一个随时间下沉、变大的“蘑菇”形密度场，用旋转扭曲的噪声切出烟丝。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp;
  vec3 c = src;
  float idx0 = floor(uTime / barSeconds);
  // ① 同时活着的 3 滴墨（每滴活 3 个间隔）
  for (int k = 0; k < 3; k++) {
    float idx = idx0 - float(k);
    float age = (uTime - idx * barSeconds) / barSeconds;   // 0..3
    if (age < 0.) continue;
    vec2 drop = vec2(.2 + .6 * fxHash(vec2(idx, 1.)), .8) * asp;
    // ② 下沉与扩散：中心随时间下降（减速），半径随时间增大
    float sink = (1. - exp(-age * .9)) * .55;
    vec2 ctr = drop - vec2(0., sink);
    float R = spread * (.25 + .45 * (1. - exp(-age * .7)));
    vec2 d = p - ctr;
    // ③ 涡环翻卷：用随时间旋转的噪声扭曲坐标，切出烟丝
    vec2 w = d + (vec2(fxFbm(d * 6. + idx + age * .4), fxFbm(d * 6. - idx * 2. - age * .3)) - .5) * R * (1.2 + churn);
    float mush = length(w * vec2(1., 1.6)) / R;                       // 蘑菇头（扁）
    float stem = abs(w.x) / (R * .15) + max(w.y, 0.) / (R * 2.5);     // 上方拖出的细茎
    float dens = max(smoothstep(1., .2, mush), smoothstep(1., .0, stem) * step(0., w.y) * .6);
    dens = clamp(dens * (.5 + 1. * fxFbm(w / R * 3. + age)), 0., 1.);
    float fade = smoothstep(3., 1.5, age) * smoothstep(0., .05, age);
    vec3 ink = mod(idx, 3.) < 1. ? c1 : mod(idx, 3.) < 2. ? c2 : c3;
    // ④ 合成：墨是吸光的（减色）——在画面上相乘变暗并带墨色
    //    浅色画面上墨是“压暗 + 染色”，深色画面上墨本身的颜色要看得见：两者取亮度适配的混合
    vec3 inked = mix(c * ink * 1.4, ink * 1.3 + .05, .55);
    c = mix(c, inked, clamp(dens * fade * opacity * 1.3, 0., 1.));
  }
  return vec4(c, 1.);
}
