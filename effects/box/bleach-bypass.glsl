/*@effect
{
  "id": "bleach-bypass",
  "name": "漂白跳过",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["bleach bypass", "skip bleach", "silver retention", "desaturated", "gritty", "漂白跳过", "留银", "冷硬"],
  "summary": "冲洗时跳过漂白，银粒留在片上叠在彩色上：画面低饱和、高反差、暗部更黑更硬，高光带金属感，颗粒明显；鼓点时银的密度一涨。",
  "when": "战争、犯罪、末日、冷硬动作片、严肃纪实与沉重主题；也适合工业/汽车广告的“钢铁感”。",
  "avoid": "温暖柔和的题材；儿童与节日；人像特写时肤色会显得发灰病态。",
  "params": {
    "silver": { "type": "float", "default": 0.65, "min": 0, "max": 1, "label": "留银量" },
    "contrast": { "type": "float", "default": 1.25, "min": 0.8, "max": 2, "label": "反差" },
    "grain": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "颗粒" },
    "tint": { "type": "color", "default": "#d6dde0", "label": "金属色调" }
  },
  "bindings": { "silver": { "to": "kick", "amount": 0.25 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：胶片调色", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：彩色胶片冲洗时，漂白步骤负责把显影出的金属银溶掉，只留下彩色染料。跳过（或部分跳过）漂白，
// 银就留在片上——相当于在彩色画面上又叠了一张同样的黑白画面：饱和度被黑白层“稀释”、暗部被银压得更深，
// 反差变硬，高光的银粒带一种冷灰的金属光泽，银粒也让颗粒更明显。

vec4 effect(vec2 uv) {
  vec3 col = srcTex(uv).rgb;

  // ① 彩色染料层：正常冲洗的颜色。
  // ② 银层：同一画面的黑白版本，反差更硬（银的显影曲线更陡）。
  float l = fxLuma(col);
  float silverL = clamp(.5 + (l - .5) * contrast, 0., 1.);
  silverL = silverL * silverL * (3. - 2. * silverL);

  // ③ 叠加：银层是“叠在上面挡光”的——在 multiply 与 overlay 之间（暗部乘深、亮部保留）。
  //    silver 挂鼓点：鼓点那一下留银更多，画面更冷更硬，然后回落。
  vec3 over = mix(2. * col * silverL, 1. - 2. * (1. - col) * (1. - silverL), step(.5, silverL));
  vec3 c = mix(col, over, silver);
  c = mix(c, vec3(fxLuma(c)), silver * .55);            // 饱和度被银层稀释

  // ④ 金属光泽：高光偏冷灰（银的反光），暗部不变黑得更纯。
  c = mix(c, c * tint * 1.08, smoothstep(.45, 1., l) * silver);

  // ⑤ 颗粒：银粒比染料云更“硬”，颗粒对比更高；按像素格取哈希，24 次/秒刷新但幅度小（不会整屏闪）。
  float g = fxHash(floor(uv * uRes * .7) + floor(uTime * 24.) * 3.1) - .5;
  c += g * grain * .09 * (1. - abs(l - .5));
  return vec4(clamp(c, 0., 1.), 1.);
}
