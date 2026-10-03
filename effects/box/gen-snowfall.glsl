/*@effect
{
  "id": "gen-snowfall",
  "name": "飘雪",
  "kind": "post",
  "category": "生成层",
  "tags": ["snow", "particles", "winter", "overlay", "weather", "飘雪", "下雪", "粒子", "冬天"],
  "summary": "在画面上叠一层三景深的飘雪：近处大片雪花虚化、远处细雪密集，雪花随风左右飘摆、缓慢旋落；音乐越激烈风越大。",
  "when": "冬季、节日（圣诞/新年/春节）、温情回忆、安静的夜景与人像。",
  "avoid": "盛夏/热带画面；需要清楚看字的镜头（近景雪花会挡字，可调低 near）。",
  "params": {
    "density": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "雪量" },
    "wind": { "type": "float", "default": 0.15, "min": -1, "max": 1, "label": "风（正 = 向右）" },
    "speed": { "type": "float", "default": 0.12, "min": 0.02, "max": 0.5, "label": "下落速度（屏高/秒）" },
    "near": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "近景大雪花" },
    "gust": { "type": "float", "default": 0, "min": 0, "max": 1.5, "label": "阵风（通常由音乐能量驱动）" },
    "tint": { "type": "color", "default": "#f4f7ff", "label": "雪色" }
  },
  "bindings": { "gust": { "to": "energy", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：天气粒子层", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：雪花在空中沿风向漂移、自身左右摆动（翻转的雪片受空气阻力），离镜头近的雪花大且失焦（虚成光斑），
// 远处的雪花小而密。生成方式：把画面按景深分 3 层格子，每格最多一片雪，雪片位置 = 格子哈希 + 随时间下落与摆动；
// 每层只需检查自己所在的格子与上方一格（雪片可能跨格），无需采样画面。

// 一层雪：scale = 每屏高多少格，blur = 失焦程度，返回亮度
float snowLayer(vec2 p, float scale, float fall, float sway, float blur, float seed, float dens) {
  vec2 q = p * scale;
  q.y += uTime * fall * scale;                      // 整层下落
  q.x -= uTime * (wind + gust * .6) * fall * scale * 1.5;  // 风
  float acc = 0.;
  for (int j = 0; j < 2; j++) {
    vec2 id = floor(q) + vec2(0., float(j));
    float h = fxHash(id + seed);
    if (h > dens) continue;                          // 这一格没有雪
    vec2 c = id + vec2(fxHash(id + seed + 1.3), fxHash(id + seed + 2.7));
    c.x += sin(uTime * (.8 + h * 1.5) + h * 30.) * sway;   // 摆动
    float r = mix(.06, .16, fxHash(id + seed + 4.1));
    float d = length(q - c);
    acc += smoothstep(r + blur, r * (1. - blur * 2.), d) * mix(.55, 1., fxHash(id + 5.));
  }
  return acc;
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, 1. - uv.y);   // y 向下，按画面高度归一

  // ① 三层景深：远（小而密、慢）→ 中 → 近（大、快、虚化）。gust 挂音乐能量：激烈段落风更大，雪横着飞。
  float far = snowLayer(p, 26., speed * .55, .18, .02, 1., density * .9);
  float mid = snowLayer(p, 13., speed * .8, .25, .05, 7., density * .7);
  float nr = snowLayer(p, 5.5, speed * 1.3, .3, .2, 13., density * .45) * near;

  // ② 合成：雪是加光的（screen），远层更淡；近层大雪花有柔和的边。
  float snow = far * .5 + mid * .75 + nr * .6;
  vec3 c = 1. - (1. - src) * (1. - clamp(tint * snow, 0., 1.));
  // ③ 下雪天的空气更亮更灰：整体略微加一层冷色雾（随雪量）。
  c = mix(c, tint * .8, .04 * density);
  return vec4(c, 1.);
}
