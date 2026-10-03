/*@effect
{
  "id": "gen-petals",
  "name": "花瓣飘落",
  "kind": "post",
  "category": "生成层",
  "tags": ["petals", "sakura", "cherry blossom", "spring", "romance", "花瓣", "樱花", "春天", "浪漫"],
  "summary": "粉白的樱花花瓣斜着飘落，每片在空中翻转（时而正面时而侧面）、打着旋儿被风带走；每小节开头一阵风，花瓣变多、飘得更快。",
  "when": "春天、樱花、恋爱与婚礼、毕业与告别、日式/古风抒情、温柔的品牌故事。",
  "avoid": "冬季/科技/暗黑题材；需要清楚看字的镜头（可调低 density）。",
  "params": {
    "density": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "花瓣数量" },
    "size": { "type": "float", "default": 0.028, "min": 0.006, "max": 0.06, "label": "花瓣大小（画面高度比例）" },
    "wind": { "type": "float", "default": 0.25, "min": -1, "max": 1, "label": "风向（正 = 向右）" },
    "gust": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "阵风（通常由节拍驱动）" },
    "colorA": { "type": "color", "default": "#ffc2d4", "label": "花瓣色" },
    "colorB": { "type": "color", "default": "#fff1f5", "label": "花瓣背面色" }
  },
  "bindings": { "gust": { "to": "bar", "amount": 0.6 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/paper-lantern 与 ukiyoe：花瓣意象", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：樱花花瓣很轻，下落时像小纸片一样翻转、旋转，被风斜着带走；花瓣是一端带小缺口的椭圆，
// 正面粉、背面更白；翻到侧面时看起来只剩一条细线。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, 1. - uv.y);
  vec3 c = src;
  float dens = clamp(density + gust * .3, 0., 1.);
  float w = wind * (1. + gust * 1.5);

  // ① 两层（远小近大），每格一片花瓣；整层沿风向与重力方向移动。
  for (int L = 0; L < 2; L++) {
    float cs = size * 3. * (1. + float(L) * .7);
    vec2 q = p / cs;
    q -= vec2(w, .45) * uTime * (.18 + float(L) * .1) / cs * (1. + gust);
    for (int j = 0; j < 2; j++) {
      for (int i = 0; i < 2; i++) {
        vec2 id = floor(q) - vec2(float(i), float(j));
        float h = fxHash(id + float(L) * 13.);
        if (h > dens) continue;
        vec2 ctr = id + vec2(fxHash(id + 1.), fxHash(id + 2.));
        ctr += .3 * vec2(sin(uTime * 1.3 + h * 20.), cos(uTime * .9 + h * 30.));
        // ② 旋转 + 翻转：花瓣绕自身转（ang），翻面让短轴按 |cos| 缩放，正反面颜色不同
        vec2 d = (q - ctr) * cs / (size * (1. + float(L) * .5));
        d = fxRot(uTime * (1. + h * 2.) + h * 10.) * d;
        float flip = cos(uTime * (2. + h * 3.) + h * 7.);
        d.y /= max(abs(flip), .12);
        // ③ 花瓣形：一头尖一头带缺口的椭圆
        float e = length(d * vec2(1., 1.6)) - .5 + d.x * .15;
        float notch = smoothstep(.12, .05, length(d - vec2(.5, 0.)));
        float m = smoothstep(.04, -.02, e) * (1. - notch);
        vec3 col = mix(colorB, colorA, flip > 0. ? 1. : .3) * (.92 + .08 * d.x);
        c = mix(c, col, m * (.9 - float(L) * .1));
      }
    }
  }
  return vec4(c, 1.);
}
