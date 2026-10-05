/*@effect
{
  "id": "gen-falling-leaves",
  "name": "落叶纷飞",
  "kind": "post",
  "category": "生成层",
  "tags": ["leaves", "autumn", "fall", "maple", "wind", "落叶", "秋天", "枫叶", "风"],
  "summary": "秋天的落叶（枫叶状，红橙黄棕）从上方旋转飘落，被风斜着吹，每片叶子都在翻转（正面亮、背面暗）并带叶脉；每小节起一阵风，叶子变多变快。",
  "when": "秋天/离别/怀旧/时间流逝、校园与毕业、温暖抒情、自然题材。",
  "avoid": "春夏或冬季场景；需要看清文字的镜头。",
  "params": {
    "density": { "type": "float", "default": 0.45, "min": 0, "max": 1, "label": "数量" },
    "size": { "type": "float", "default": 0.035, "min": 0.01, "max": 0.1, "label": "叶片大小（画面高度比例）" },
    "wind": { "type": "float", "default": 0.35, "min": -1, "max": 1, "label": "风向（正 = 向右）" },
    "gust": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "小节阵风（通常由小节驱动）" }
  },
  "bindings": { "gust": { "to": "bar", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：季节粒子", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：秋叶又轻又宽，下落时像小翅膀一样旋转、翻面，被风推着斜飞；颜色从红到黄到棕各不相同，叶片上有叶脉。
// 枫叶形用极坐标的半径函数做出 5 个尖角。

vec3 leafColor(float h) {
  return h < .3 ? vec3(.8, .18, .08) : h < .55 ? vec3(.95, .45, .08) : h < .8 ? vec3(.95, .72, .15) : vec3(.5, .28, .12);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, 1. - uv.y);
  vec3 c = src;
  float dens = clamp(density + gust * .3, 0., 1.);
  float w = wind * (1. + gust * 2.);
  for (int L = 0; L < 2; L++) {
    float cs = size * 3.5 * (1. + float(L) * .6);
    vec2 q = p / cs;
    q -= vec2(w * .25, .2) * uTime * (1. + float(L) * .5) * (1. + gust) / cs;
    for (int j = 0; j < 2; j++) for (int i = 0; i < 2; i++) {
      vec2 id = floor(q) - vec2(float(i), float(j));
      float h = fxHash(id + float(L) * 23.);
      if (h > dens) continue;
      vec2 ctr = id + vec2(fxHash(id + 1.), fxHash(id + 2.)) + .3 * vec2(sin(uTime * 1.1 + h * 40.), cos(uTime * .8 + h * 20.));
      // ① 旋转 + 翻面
      vec2 d = (q - ctr) * cs / (size * (1. + float(L) * .4));
      d = fxRot(uTime * (1. + h * 2.) + h * 9.) * d;
      float flip = cos(uTime * (1.5 + h * 2.) + h * 5.);
      d.x /= max(abs(flip), .15);
      // ② 枫叶形：5 个尖角的半径函数 + 叶柄
      float a = atan(d.x, d.y), r = length(d);
      float lobes = .5 + .18 * pow(abs(cos(a * 2.5)), 3.) - .12 * smoothstep(2.6, 3.14, abs(a));
      float m = smoothstep(lobes + .03, lobes - .03, r);
      m = max(m, smoothstep(.03, .0, abs(d.x)) * step(-.75, d.y) * step(d.y, -.3));
      // ③ 叶脉：从中心放射的几条细线
      float vein = smoothstep(.025, 0., abs(sin(a * 2.5)) * r) * step(r, lobes * .9);
      vec3 col = leafColor(fxHash(id + 9.)) * (flip > 0. ? 1. : .6);
      col = mix(col, col * .6, vein * .7);
      c = mix(c, col, m * (.95 - float(L) * .15));
    }
  }
  return vec4(c, 1.);
}
