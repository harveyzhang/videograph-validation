/*@effect
{
  "id": "night-city-bokeh",
  "name": "夜城光斑雨窗",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["rain window", "bokeh", "night city", "raindrops", "melancholy", "雨窗", "光斑", "夜城", "雨滴"],
  "summary": "隔着下雨的车窗看夜景：背景被虚化成一颗颗彩色圆形光斑，玻璃上挂着大小不一的雨滴（雨滴里折射出清晰一点的倒影）、偶尔有水珠顺着玻璃滑下留下水痕；音乐能量越高雨越多。",
  "when": "雨夜/城市孤独/失恋与思念、Lo-fi 与 R&B、出租车与通勤、回忆。",
  "avoid": "白天晴朗场景；需要清楚看到背景细节的镜头。",
  "params": {
    "blur": { "type": "float", "default": 0.025, "min": 0, "max": 0.06, "label": "背景虚化" },
    "drops": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "雨滴数量" },
    "dropSize": { "type": "float", "default": 0.03, "min": 0.01, "max": 0.08, "label": "雨滴大小（画面高度比例）" },
    "streaks": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "滑落水痕" },
    "rain": { "type": "float", "default": 0, "min": 0, "max": 0.5, "label": "能量加雨（通常由音乐能量驱动）" }
  },
  "bindings": { "rain": { "to": "energy", "amount": 0.3 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：雨窗", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：隔着玻璃对焦在玻璃上的雨滴时，窗外的灯光全部失焦成圆形光斑；每颗雨滴是一个小凸透镜，
// 里面映出窗外景物的倒置缩影（比背景清楚）；大水珠积累到一定重量会顺着玻璃滑下，身后留下一道干净的水痕。

vec4 effect(vec2 uv) {
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  // ① 背景虚化：8 次环形采样 + 亮部加权（光斑更圆更亮）
  vec3 acc = vec3(0.); float ws = 0.;
  for (int i = 0; i < 8; i++) {
    float a = float(i) * .7854;
    vec3 s = srcTex(uv + vec2(cos(a), sin(a)) * blur * asp).rgb;
    float w = 1. + 4. * pow(fxLuma(s), 3.);
    acc += s * w; ws += w;
  }
  vec3 c = acc / ws;
  // ② 雨滴：分格，每格一颗（按数量概率），雨滴内部是轻度折射、更清楚的画面（1 次采样）
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float cs = dropSize * 2.5;
  vec2 id = floor(p / cs), f = fract(p / cs) - .5;
  float h = fxHash(id);
  float has = step(h, drops + rain);
  vec2 o = (vec2(fxHash(id + 1.), fxHash(id + 2.)) - .5) * .5;
  float r = (.15 + .25 * fxHash(id + 3.));
  vec2 dq = (f - o) / r;
  float dl = length(dq * vec2(1., .85));
  if (has > .5 && dl < 1.) {
    vec3 inside = srcTex(uv - dq * dropSize * .6 * asp).rgb;    // 凸透镜：倒置缩影
    c = mix(c, inside * 1.05, smoothstep(1., .85, dl));
    c += smoothstep(.35, .1, length(dq - vec2(-.3, .35))) * .4;  // 高光
    c *= 1. - smoothstep(.75, 1., dl) * .35;                      // 边缘暗
  }
  // ③ 滑落水痕：少数列有一道从上往下滑的水珠，身后是更清楚的竖条（水痕把雾擦干净了）
  float col = floor(uv.x * 40.);
  float sh = fxHash(vec2(col, 5.));
  if (sh < streaks * .3) {
    float yHead = 1. - fract(uTime * (.08 + .1 * fxHash(vec2(col, 6.))) + sh * 10.);
    float cx = (col + .5) / 40. + sin(uv.y * 20. + col) * .002;
    float dx = abs(uv.x - cx) * uRes.x;
    float trail = smoothstep(3., 0., dx) * step(yHead, uv.y);
    c = mix(c, srcTex(uv).rgb, trail * .7);
    float head = smoothstep(dropSize * .5, 0., length(vec2((uv.x - cx) * uRes.x / uRes.y, uv.y - yHead)));
    c += head * .4;
  }
  return vec4(c, 1.);
}
