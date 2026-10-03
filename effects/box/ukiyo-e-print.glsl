/*@effect
{
  "id": "ukiyo-e-print",
  "name": "浮世绘木版",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["ukiyo-e", "woodblock", "japanese print", "hokusai", "bokashi", "浮世绘", "木版画", "普鲁士蓝"],
  "summary": "日本木版画：画面压成几块平涂专色（普鲁士蓝、朱红、米色），墨线主版勾勒轮廓，天空是自上而下的蓝色晕染（bokashi），纸上透出木纹。",
  "when": "日式题材、和风品牌、古典叙事、海浪/山/城市天际线的风景镜头、节庆宣传。",
  "avoid": "需要写实肤色的近景；色彩复杂的现代场景（会被压成几种传统色，可能违和）。",
  "params": {
    "outline": { "type": "float", "default": 0.85, "min": 0, "max": 1.5, "label": "墨线主版" },
    "bokashi": { "type": "float", "default": 0.65, "min": 0, "max": 1, "label": "天空晕染" },
    "woodGrain": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "木纹" },
    "washi": { "type": "color", "default": "#efe3c8", "label": "和纸颜色" }
  },
  "bindings": { "bokashi": { "to": "bar", "amount": 0.25 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/ukiyoe", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：浮世绘是“绘师-雕师-摺师”分工：先刻一块只印黑线的主版（墨线），再按颜色各刻一块色版，
// 每块色版刷一种平涂颜色依次印在和纸上；摺师在版上用湿布把颜料抹出渐变，就是天空上那条著名的蓝色晕染（ぼかし）。
// 颜色是有限的传统色：普鲁士蓝（ベロ藍）、朱、黄土、墨、和纸本色。木版的木纹会印在大块平涂上。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 分色：每个像素归到最接近的传统色版（6 块色版，含和纸本色），按颜色距离挑选。
  vec3 pal[6] = vec3[6](washi, vec3(.13, .23, .42), vec3(.36, .55, .7), vec3(.8, .3, .2), vec3(.82, .67, .42), vec3(.12, .11, .1));
  vec3 s = clamp((src - .5) * 1.15 + .5, 0., 1.);
  vec3 col = pal[0];
  float best = 1e3;
  for (int i = 0; i < 6; i++) {
    vec3 d = s - pal[i];
    float dist = dot(d * d, vec3(.3, .59, .11)) + abs(fxLuma(s) - fxLuma(pal[i])) * .15;
    if (dist < best) { best = dist; col = pal[i]; }
  }

  // ② 晕染（ぼかし）：天空（画面上部、蓝色版区域）自上而下从深普鲁士蓝渐变到和纸色；
  //    bokashi 挂小节：每小节开头晕染更深，像摺师又刷了一遍，然后回落。
  float blueish = smoothstep(.0, .12, s.b - s.r);
  float grad = smoothstep(.45, 1., uv.y) * bokashi;
  col = mix(col, mix(col, vec3(.1, .2, .4), grad), blueish * step(.4, uv.y));

  // ③ 木纹：大块平涂上印出顺着木板方向（横向）的纹理，颜料在纹路上深浅不一。
  float grain = fxNoise(vec2(uv.x * uRes.x * .004, uv.y * uRes.y * .12)) * .6 + fxNoise(vec2(uv.x * uRes.x * .01, uv.y * uRes.y * .35)) * .4;
  col = mix(col, col * (.82 + .3 * grain), woodGrain);

  // ④ 主版墨线：沿轮廓（9 次采样）印一条墨线，线不完全实（木版吃墨不匀）。
  float e = smoothstep(.12, .35, fxSobel(uv)) * (.75 + .25 * fxNoise(uv * uRes * .3));
  col = mix(col, vec3(.1, .09, .09), e * outline * .9);

  // ⑤ 和纸：纸纤维让整体有细微的明暗（静止）。
  col *= .96 + .05 * fxNoise(uv * uRes * .7);
  return vec4(col, 1.);
}
