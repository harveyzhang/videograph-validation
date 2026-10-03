/*@effect
{
  "id": "colored-pencil",
  "name": "彩铅交叉排线",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["colored pencil", "crosshatch", "hatching", "illustration", "彩铅", "彩色铅笔", "排线"],
  "summary": "彩色铅笔按不同角度一层层交叉排线：浅处是稀疏的单色斜线、暗处交叉加深，白纸纹理透出，再用石墨铅笔勾轮廓；鼓点时下笔更重。",
  "when": "绘本、教育与儿童题材、温暖的品牌故事、旅行手账、产品手绘说明。",
  "avoid": "大面积纯黑或高饱和霓虹画面（彩铅叠不出那么深/那么艳）；快节奏动作场面。",
  "params": {
    "paper": { "type": "color", "default": "#fbf8f1", "label": "纸色" },
    "spacing": { "type": "float", "default": 5.5, "min": 2.5, "max": 10, "label": "排线间距（像素）" },
    "pressure": { "type": "float", "default": 0.85, "min": 0.3, "max": 1.6, "label": "下笔力度" },
    "contour": { "type": "float", "default": 0.7, "min": 0, "max": 1.5, "label": "石墨勾线" }
  },
  "bindings": { "pressure": { "to": "kick", "amount": 0.25 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/crayon-book 与 urban-sketch：手绘绘本观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：彩铅是半透明的蜡质色芯，一层压不满纸，画者挑接近的颜色排线铺底，再换更深的笔换方向交叉排线加深；
// 纸面的凹纹接不到铅芯，留下细小白点；最后用石墨铅笔沿轮廓勾一遍让形体清楚。

// 一层排线：amt = 这一层需要的颜色量（0..1），ang = 排线角度，seed = 让每层的笔触错开
float hatchLayer(vec2 p, float amt, float ang, float seed) {
  vec2 d = vec2(cos(ang), sin(ang));
  float u = dot(p, vec2(-d.y, d.x)) / spacing + fxNoise(p * .02 + seed) * 1.5;   // 手画的线不完全直
  float along = dot(p, d);
  float w = clamp(amt * pressure, 0., 1.) * .5;                                    // 越需要颜色，线越宽
  float taper = .65 + .35 * fxNoise(vec2(floor(u) + seed * 7., along * .025));     // 一笔里有轻有重
  float line = smoothstep(w * taper + .08, w * taper - .08, abs(fract(u) - .5));
  float tooth = smoothstep(.25, .6, fxNoise(p * .9 + seed * 3.));                   // 纸纹凹处接不到铅芯
  return line * mix(.55, 1., tooth) * min(amt * pressure * 1.6, 1.);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = uv * uRes;
  float l = fxLuma(src);

  // ① 选笔：画者会挑一支与局部颜色最接近的彩铅（比原色更纯一点，彩铅色芯颜色很“正”）。
  vec3 pencil = clamp(mix(vec3(l), src, 1.35) / max(l, .2) * .85, 0., 1.);
  pencil = mix(pencil, src, .35);

  // ② 第一层：用这支笔沿 30° 排线铺底色；越暗、越饱和的地方越用力（线越宽、越实）。
  float sat = max(max(src.r, src.g), src.b) - min(min(src.r, src.g), src.b);
  float need1 = clamp((1. - l) * .9 + sat * .6, 0., 1.);
  float h1 = hatchLayer(p, need1, .52, 1.);

  // ③ 第二层：中间调到暗部，换同色系更深的一支沿 −40° 交叉排线（交叉排线是彩铅加深的标准手法）。
  float h2 = hatchLayer(p, smoothstep(.65, .2, l), -.7, 2.);

  // ④ 第三层：最暗处用深棕/靛蓝收一遍（三层叠也达不到的深色），方向接近竖直。
  float h3 = hatchLayer(p, smoothstep(.45, .05, l), 1.48, 3.);

  // ⑤ 叠色：彩铅是半透明的蜡，每层“乘”到纸上（减色混合）。
  vec3 c = paper;
  c *= mix(vec3(1.), pencil, h1 * .9);
  c *= mix(vec3(1.), pencil * .55 + vec3(.05, .04, .08), h2 * .75);
  c *= mix(vec3(1.), vec3(.28, .22, .3), h3 * .7);

  // ⑥ 石墨勾线：沿轮廓（9 次采样）的细灰线，有一点断续。
  float e = smoothstep(.15, .5, fxSobel(uv)) * (.7 + .3 * fxNoise(p * .08));
  c = mix(c, vec3(.28, .28, .3), e * contour * .8);
  return vec4(c, 1.);
}
