/*@effect
{
  "id": "gen-fog-drift",
  "name": "低空雾气",
  "kind": "post",
  "category": "生成层",
  "tags": ["fog", "mist", "haze", "atmosphere", "smoke", "雾", "薄雾", "氛围", "烟雾"],
  "summary": "两到三层贴着画面下部缓缓横向飘动的雾带，远层淡、近层浓，雾里的景物被柔化压淡；音乐越激烈雾越浓、飘得越快。",
  "when": "清晨山林、湖面、恐怖与悬疑、舞台干冰效果、梦境与回忆、给空镜加氛围。",
  "avoid": "需要清晰看见画面下部内容的镜头；晴朗干净的商业产品画面。",
  "params": {
    "density": { "type": "float", "default": 0.55, "min": 0, "max": 1, "label": "浓度" },
    "height": { "type": "float", "default": 0.4, "min": 0.05, "max": 1, "label": "雾层高度（从底部算）" },
    "speed": { "type": "float", "default": 0.04, "min": 0, "max": 0.3, "label": "飘移速度" },
    "swell": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量变浓（通常由音乐能量驱动）" },
    "color": { "type": "color", "default": "#c9d2dc", "label": "雾色" }
  },
  "bindings": { "swell": { "to": "energy", "amount": 0.4 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：氛围生成层", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：辐射雾/干冰雾比空气重，贴着地面成层流动；雾是散射光的微小水滴，所以雾里的东西对比度下降、
// 颜色被雾色“替代”，越远（越深的雾）替代得越多。雾的边缘被空气扰动成卷曲的形状，缓慢横向飘。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float fog = 0.;

  // ① 三层雾带：每层是横向拉长的分形噪声，顶部边缘随噪声起伏；层越近越浓、飘得越快。
  for (int k = 0; k < 3; k++) {
    float K = float(k);
    float sp = speed * (1. + K * .8) * (1. + swell);
    vec2 q = vec2(p.x * (1.5 + K * .6) - uTime * sp, p.y * (3. + K) + K * 4.);
    float n = fxFbm(q + vec2(fxNoise(q * .5 + uTime * .05), 0.));
    float top = height * (.6 + K * .25) + (n - .5) * .15;
    float layer = smoothstep(top, top - .18, p.y) * (.4 + .6 * n);
    fog += layer * (.35 + K * .25);
  }

  // ② 浓度：swell 挂音乐能量——激烈段落雾更浓（像舞台加大干冰）。
  float a = clamp(fog * (density + swell * .3), 0., .92);

  // ③ 散射：雾里的景物对比度下降并被雾色替代；雾本身在亮处略亮（被光照着）。
  vec3 foggy = mix(src, color * (.85 + .3 * fxLuma(src)), a);
  return vec4(foggy, 1.);
}
