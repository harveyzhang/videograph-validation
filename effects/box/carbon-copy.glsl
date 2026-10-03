/*@effect
{
  "id": "carbon-copy",
  "name": "复写纸副本",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["carbon copy", "carbon paper", "duplicate", "typewriter", "form", "复写纸", "副本", "单据"],
  "summary": "像一张复写纸的第二联：蓝紫色的转印线条发虚、带压痕方向的拖尾，深浅随笔压不均，纸是略带黄的薄单据纸并有淡淡的横格。",
  "when": "档案、刑侦、旧时代办公室、单据与表格题材、冷战/间谍叙事、怀旧的“存档”镜头。",
  "avoid": "大面积暗部的画面（复写只转印线条，满版会糊）；色彩是重点的镜头。",
  "params": {
    "ink": { "type": "color", "default": "#3a3f9a", "label": "复写墨色" },
    "paper": { "type": "color", "default": "#f2efe0", "label": "单据纸色" },
    "pressure": { "type": "float", "default": 0.75, "min": 0.2, "max": 1.5, "label": "笔压" },
    "smear": { "type": "float", "default": 0.004, "min": 0, "max": 0.015, "label": "拖尾" },
    "rules": { "type": "float", "default": 0.25, "min": 0, "max": 1, "label": "横格线" }
  },
  "bindings": { "pressure": { "to": "kick", "amount": 0.35 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/halftone-dossier 与 spy-titles：档案感观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：复写纸夹在两张纸之间，上面写字/打字的压力把复写纸背面的蜡质颜料压到下面那张纸上。
// 所以副本只记录“有压力的地方”（线条和轮廓，而不是大面积色块），线条发虚、深浅随压力变化，
// 复写纸被纸张轻微带动时还会在同一方向留下拖尾；单据纸本身薄而偏黄，常印有横格。

vec4 effect(vec2 uv) {
  // ① 压力从哪来：写字/描图的笔只沿着轮廓与笔画走，大面积色块不会被“描”出来 →
  //    用亮度梯度（fxSobel，9 次采样）当压力分布。所以无论原图是黑底还是白底，副本都是白纸上的蓝线。
  float edge = fxSobel(uv);
  float press = clamp(edge * 2.4, 0., 1.) * pressure;

  // ② 拖尾：复写纸被纸张轻微带动 → 沿斜下方向错开 2 个“拖尾步长”再取一次，作为一道更淡的重影（见 ③ 的 ghost）。
  vec2 dir = normalize(vec2(1., -.35)) * smear;

  // ③ 颜料转印不均：复写纸用久了蜡层厚薄不一，用低频噪声调制转印量；纸纤维让线条边缘起毛。
  float wear = .55 + .45 * fxNoise(uv * vec2(6., 18.));
  float fuzz = fxNoise(uv * uRes * .6);
  float transfer = smoothstep(.15, .6, press * wear + (fuzz - .5) * .25);
  vec2 gq = uv - dir * 2., gp = 1.5 / uRes;    // 重影处的简化梯度（4 次采样，总计 13 次）
  float gEdge = abs(fxLuma(srcTex(gq + vec2(gp.x, 0.)).rgb) - fxLuma(srcTex(gq - vec2(gp.x, 0.)).rgb))
              + abs(fxLuma(srcTex(gq + vec2(0., gp.y)).rgb) - fxLuma(srcTex(gq - vec2(0., gp.y)).rgb));
  float ghost = smoothstep(.2, .7, gEdge * 2.4 * pressure * wear) * .3;
  // pressure 挂鼓点：鼓点那一下像打字机“咔”地敲下，转印更深。

  // ④ 单据纸：偏黄薄纸 + 淡蓝横格（每 22 像素一条）+ 左侧红色装订线。
  vec3 c = paper;
  float ruleY = abs(fract(uv.y * uRes.y / 22.) - .5) * 22.;
  c = mix(c, vec3(.62, .74, .86), smoothstep(1., 0., ruleY) * rules);
  c = mix(c, vec3(.85, .45, .45), smoothstep(1.2, 0., abs(uv.x * uRes.x - uRes.x * .08)) * rules);

  // ⑤ 转印：蓝紫色蜡颜料相乘到纸上（半透明），重影更淡。
  c = mix(c, c * ink * 1.6, clamp(transfer + ghost, 0., 1.) * .9);
  return vec4(c, 1.);
}
