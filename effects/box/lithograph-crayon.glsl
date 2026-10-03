/*@effect
{
  "id": "lithograph-crayon",
  "name": "石版画",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["lithograph", "litho crayon", "stone print", "grain", "石版画", "平版印刷", "蜡笔石印"],
  "summary": "用油性蜡笔在磨砂石板上作画再印出：暗部是颗粒状的蜡笔笔触，石板的砂目让灰阶变成大小不一的墨点，整体是暖调单色带一点套色。",
  "when": "19 世纪海报与插画感、博物馆/历史题材、旧书插图、复古演出海报。",
  "avoid": "需要干净锐利边缘的商业画面；纯黑或纯白大面积画面颗粒会显脏。",
  "params": {
    "ink": { "type": "color", "default": "#2b211c", "label": "主墨色" },
    "tintColor": { "type": "color", "default": "#c8643c", "label": "套色" },
    "paper": { "type": "color", "default": "#efe4cc", "label": "纸色" },
    "grain": { "type": "float", "default": 2.2, "min": 1, "max": 6, "label": "石板砂目（像素）" },
    "tint": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "套色比例" },
    "contrast": { "type": "float", "default": 1.2, "min": 0.6, "max": 2, "label": "反差" }
  },
  "bindings": { "tint": { "to": "bar", "amount": 0.25 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/engraving 与 woodcut：古典版画观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：石版画是在磨出细砂目的石灰石板上用油性蜡笔作画。蜡笔划过砂目时只附着在砂粒的“山顶”，
// 所以浅色笔触是稀疏的颗粒，用力处颗粒连成片；印刷时油墨只附着在蜡上，于是灰阶全部由“颗粒密度”表现。
// 套色石印再用第二块石板印一层颜色（常见暖红/土黄），两版之间对位稍有偏差。

vec4 effect(vec2 uv) {
  // ① 读原稿明暗并加大反差（画家会把明暗归纳成几个层次）。
  float l = fxLuma(srcTex(uv).rgb);
  l = clamp((l - .5) * contrast + .5, 0., 1.);

  // ② 石板砂目：砂粒的高低用多尺度噪声表示（单位 = 像素 × grain），静止不动（石板不会变）。
  vec2 g = uv * uRes / grain;
  float sand = fxNoise(g) * .55 + fxNoise(g * 2.3 + 7.) * .3 + fxHash(floor(g * 1.7)) * .15;

  // ③ 蜡笔附着：笔触越重（越暗），蜡能沉到越低的砂粒 → 颗粒越密。阈值比较 = 砂粒高于“笔压线”的地方有蜡。
  //    再叠一层斜向的笔触方向性（蜡笔是一笔一笔斜着排的）。
  float stroke = fxNoise(vec2(uv.x * uRes.x * .04 + uv.y * uRes.y * .1, uv.y * uRes.y * .015)) * .25;
  float wax = smoothstep(.04, -.04, l - (1. - sand) * .95 - stroke + .12);

  // ④ 套色版：第二块石板只印中间调（用模糊一点的明暗，色块边缘比主版柔和），对位偏 2 像素。
  //    tint 挂小节：每小节开头套色更饱满，然后慢慢回落，像整张画在“换气”。
  float l2 = fxLuma(srcTex(uv + vec2(2., -1.5) / uRes).rgb);
  float tintMask = smoothstep(.85, .45, l2) * smoothstep(.0, .25, l2) * tint;

  // ⑤ 印刷：纸 → 套色（半透明相乘）→ 主墨（不透明蜡墨）。
  vec3 c = paper;
  c = mix(c, c * tintColor * 1.15, tintMask);
  c = mix(c, ink, wax * .95);
  c *= .97 + .03 * fxNoise(uv * uRes * .2);   // 纸张的轻微不平
  return vec4(c, 1.);
}
