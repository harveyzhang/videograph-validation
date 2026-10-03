/*@effect
{
  "id": "blueprint-lines",
  "name": "工程蓝图",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["blueprint", "technical drawing", "schematic", "engineering", "grid", "蓝图", "工程图", "线稿", "设计图"],
  "summary": "画面变成一张工程蓝图：深蓝底、白色细格网，画面轮廓变成白色制图线，暗部用细斜线填充，角落带一个图框标题栏；线条随时间从左到右逐渐“画”出来。",
  "when": "建筑/工程/产品设计、科技与制造、“从构想到成品”的叙事、发明与创造。",
  "avoid": "需要颜色与真实感的镜头；画面轮廓极多时会很乱。",
  "params": {
    "paper": { "type": "color", "default": "#1a4c8b", "label": "蓝图底色" },
    "ink": { "type": "color", "default": "#e8f1ff", "label": "线色" },
    "grid": { "type": "float", "default": 0.05, "min": 0.01, "max": 0.2, "label": "格网间距（画面高度比例）" },
    "hatch": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "暗部斜线填充" },
    "drawEnd": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "画完于镜头进度（0 = 一开始就画好）" },
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 0.5, "label": "节拍线条亮度（通常由节拍驱动）" }
  },
  "bindings": { "pulse": { "to": "beat", "amount": 0.25 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/blueprint", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：蓝图是一种重氮复印工艺——把画在半透明纸上的原图压在感光纸上曝光，线条处不感光，冲洗后得到蓝底白线的图纸。
// 工程图有规范的细格网、剖面用细斜线（剖面线）填充、右下角有标题栏。

vec4 effect(vec2 uv) {
  vec3 c = paper * (.95 + .08 * fxNoise(uv * uRes * .2));
  float H = uRes.y;
  // ① 格网：主格 + 每 5 格一条粗线
  vec2 g = uv * uRes / (grid * H);
  vec2 gd = abs(fract(g + .5) - .5) * grid * H;
  float fine = (step(gd.x, .6) + step(gd.y, .6)) * .18;
  vec2 g5 = abs(fract(g / 5. + .5) - .5) * grid * H * 5.;
  float major = (step(g5.x, 1.) + step(g5.y, 1.)) * .3;
  // ② 制图线：画面轮廓（Sobel，9 次采样）
  float e = smoothstep(.12, .35, fxSobel(uv));
  // ③ 剖面线：暗部用 45° 细斜线填
  float l = fxLuma(srcTex(uv).rgb);
  float hl = step(abs(fract((uv.x * uRes.x + uv.y * uRes.y) / 7.) - .5), .08) * smoothstep(.45, .2, l) * hatch;
  // ④ 绘制进度：从左往右（带一点手绘的不齐），格网与标题栏一直在
  float drawn = drawEnd <= 0. ? 1. : step(uv.x + (fxNoise(uv * vec2(2., 20.)) - .5) * .05, uProgress / drawEnd * 1.1);
  float lines = clamp(max(e, hl * .7) * drawn, 0., 1.);
  c = mix(c, ink, min(fine + major, .5));
  c = mix(c, ink * (1. + pulse), lines);
  // ⑤ 图框与标题栏（右下）
  vec2 px = uv * uRes;
  float border = step(min(min(px.x, uRes.x - px.x), min(px.y, uRes.y - px.y)), H * .025) * (1. - step(min(min(px.x, uRes.x - px.x), min(px.y, uRes.y - px.y)), H * .022));
  vec2 tb = vec2(uRes.x - H * .025 - H * .45, H * .025);
  float inTB = step(tb.x, px.x) * step(px.x, uRes.x - H * .025) * step(tb.y, px.y) * step(px.y, tb.y + H * .12);
  float tbLines = inTB * (step(abs(px.y - (tb.y + H * .06)), 1.) + step(abs(px.x - (tb.x + H * .15)), 1.) + step(abs(px.x - tb.x), 1.) + step(abs(px.y - (tb.y + H * .12)), 1.));
  c = mix(c, ink, clamp(border + tbLines, 0., 1.) * .8);
  return vec4(c, 1.);
}
