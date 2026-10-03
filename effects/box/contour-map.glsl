/*@effect
{
  "id": "contour-map",
  "name": "等高线地形图",
  "kind": "post",
  "category": "几何与图形",
  "tags": ["contour", "topographic", "isoline", "map", "elevation", "等高线", "地形图"],
  "summary": "把画面的明暗当作海拔，画成纸上的等高线地图：细线每隔几条一根粗计曲线，按高度分层设色；线会随节拍缓缓“涨潮”。",
  "when": "地理、户外、探索、数据与科研主题；安静的叙事段、片头与章节卡；人像剪影会变成有趣的“山”。",
  "avoid": "需要辨认具体内容的镜头（只剩明暗结构）；明暗变化很小的平淡画面线会很稀。",
  "params": {
    "levels": { "type": "float", "default": 14, "min": 4, "max": 40, "label": "等高线条数" },
    "flow": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "海拔偏移（涨潮）" },
    "ink": { "type": "color", "default": "#7a4a2a", "label": "线色" },
    "paper": { "type": "color", "default": "#f1ead6", "label": "纸色" },
    "tintAmount": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "分层设色" }
  },
  "bindings": { "flow": { "to": "beat", "amount": 0.35 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/blueprint 与 dataviz：线稿与信息图观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：测绘员把地面高程按固定间隔（等高距）切片，每个切面与地面的交线画成一条线；每 5 条加粗一根
// “计曲线”方便读数；地图再按高度分层设色（低处绿、中间黄褐、高处浅）。这里把画面亮度当作高程。

vec4 effect(vec2 uv) {
  // ① 测高程：亮度 = 海拔。8 位画面的亮度是一级一级的台阶，直接切会得到锯齿线，所以先在较大半径内
  //    做 9 点模糊（10 像素半径）（真实测绘也是对离散高程点插值）；同时用左右/上下差分求坡度，供 ③ 固定线宽用。
  //    再加极低频的地形起伏，让平坦区域也有缓坡（真实地形没有完全平的地方）。
  vec2 o = 10. / uRes;
  float hc = fxLuma(srcTex(uv).rgb);
  float hl = fxLuma(srcTex(uv - vec2(o.x, 0.)).rgb), hr = fxLuma(srcTex(uv + vec2(o.x, 0.)).rgb);
  float hd = fxLuma(srcTex(uv - vec2(0., o.y)).rgb), hu = fxLuma(srcTex(uv + vec2(0., o.y)).rgb);
  float h1 = fxLuma(srcTex(uv + o).rgb), h2 = fxLuma(srcTex(uv - o).rgb);
  float h3 = fxLuma(srcTex(uv + vec2(o.x, -o.y)).rgb), h4 = fxLuma(srcTex(uv + vec2(-o.x, o.y)).rgb);
  float h = (hc * 4. + (hl + hr + hd + hu) * 2. + h1 + h2 + h3 + h4) / 16.;
  vec2 slope = vec2(hr - hl + (h1 + h3 - h2 - h4) * .5, hu - hd + (h1 + h4 - h2 - h3) * .5) / (20. * 2.);   // 每像素的高程变化
  // 低频起伏也要计入坡度（纯计算，不采样），否则平地上的线会时粗时断
  vec2 e = 1. / uRes;
  float relief = fxFbm(uv * 3.);
  slope += vec2(fxFbm((uv + vec2(e.x, 0.)) * 3.) - relief, fxFbm((uv + vec2(0., e.y)) * 3.) - relief) * .12;
  h += (relief - .5) * .12 + (fxNoise(uv * uRes / 30.) - .5) * .012;   // 细小的地表起伏，顺便打散 8 位亮度台阶

  // ② 切片：海拔 × 条数 的小数部分 = 在当前等高距里的位置。flow 挂每拍：所有线一起向高处推进一点再退回，
  //    像潮水一拍一拍涨落（只移动线的位置，不改变明暗，不会闪）。
  float v = h * levels + flow * 1.;
  float f = fract(v);

  // ③ 画线：线宽 = 到线的高程差 ÷ 每像素的高程变化（坡度），这样无论地形陡缓，线都约 1 像素粗；计曲线约 2 倍粗。
  //    坡度用 ① 的平滑差分而不是 fwidth（8 位台阶会让 fwidth 时有时无，线就断成虚线）。
  float w = (length(slope) + .0015) * levels;
  float dist = min(f, 1. - f) / max(w, 1e-4);
  float index = 1. - step(.5, mod(floor(v + .5), 5.));   // 每 5 条中的第 1 条是计曲线
  float lineW = mix(.9, 2., index);
  float line = smoothstep(lineW, lineW - 1., dist);

  // ④ 分层设色：按所在等高带取色（低→高：灰绿、草绿、土黄、浅褐、近白），与纸色混合。
  float band = floor(v) / levels;
  vec3 hyps = band < .2 ? vec3(.62, .72, .6) : band < .4 ? vec3(.74, .8, .6) : band < .6 ? vec3(.88, .82, .6) : band < .8 ? vec3(.86, .74, .6) : vec3(.95, .92, .88);
  vec3 col = mix(paper, paper * hyps * 1.05, tintAmount);

  // ⑤ 纸面：极淡的纤维纹（静止，不闪），线条按墨色叠上去。
  col *= .97 + .03 * fxNoise(uv * uRes * .25);
  col = mix(col, ink, line * mix(.75, 1., index));
  return vec4(col, 1.);
}
