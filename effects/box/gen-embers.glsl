/*@effect
{
  "id": "gen-embers",
  "name": "火星余烬",
  "kind": "post",
  "category": "生成层",
  "tags": ["embers", "sparks", "fire", "particles", "ash", "火星", "余烬", "火花", "篝火"],
  "summary": "一颗颗橙红的火星从画面下方随热气流升起，边升边左右飘、边冷却变暗，少数火星拖出短尾；鼓点时火星一齐亮一下。",
  "when": "篝火/战争/末日/史诗与奇幻、热血燃向的副歌、铁匠与工业、悼念与烛光。",
  "avoid": "清凉/水/冬季题材；明亮的白天画面（火星看不清）。",
  "params": {
    "density": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "数量" },
    "size": { "type": "float", "default": 0.004, "min": 0.0015, "max": 0.015, "label": "火星大小（画面高度比例）" },
    "rise": { "type": "float", "default": 0.12, "min": 0.02, "max": 0.5, "label": "上升速度" },
    "heat": { "type": "float", "default": 0, "min": 0, "max": 1.5, "label": "鼓点增亮（通常由节拍驱动）" },
    "hot": { "type": "color", "default": "#ffd27a", "label": "炽热色" },
    "cool": { "type": "color", "default": "#ff3d12", "label": "冷却色" }
  },
  "bindings": { "heat": { "to": "kick", "amount": 0.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：发光粒子", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：篝火里蹦出的炭屑被热空气托着往上飞，路线被湍流扰乱左右飘；炭屑在空气里迅速冷却，
// 颜色从炽热的黄白变成橙红再熄灭（黑体辐射）。镜头快门让快速运动的火星拉出一点短尾。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  vec3 light = vec3(0.);

  // ① 两层火星（远小近大），每格一颗；一颗火星的“寿命”= 从底部升到某高度的过程，按格子哈希错开相位。
  for (int L = 0; L < 2; L++) {
    float cs = .07 * (1. + float(L) * .7);
    vec2 q = p / cs;
    float spd = rise * (1. + float(L) * .5) / cs;
    float col = floor(q.x);
    for (int j = -1; j <= 1; j++) {
      vec2 id = vec2(col + float(j), float(L) * 31.);
      float h = fxHash(id);
      if (h > density) continue;
      // ② 生命周期：每颗火星周期性重生（周期 2–4 秒），age 0→1 从底部升到 70–100% 屏高
      float period = 2. + 2. * fxHash(id + 1.);
      float age = fract(uTime / period + fxHash(id + 2.));
      float y = age * (.7 + .3 * fxHash(id + 3.)) / cs;
      // ③ 湍流：横向位移随高度与时间扰动（两个频率的正弦叠加）
      float x = col + float(j) + .5 + .6 * sin(age * 7. + h * 30.) * age + .25 * sin(uTime * 3. + h * 50.);
      vec2 c = vec2(x, y);
      vec2 vel = vec2(.6 * 7. * cos(age * 7. + h * 30.) * age / period, (.7 + .3 * fxHash(id + 3.)) / cs / period);
      // 短尾：沿速度反方向的线段
      vec2 tail = c - normalize(vel) * .25;
      vec2 pa = q - tail, ba = c - tail;
      float hs = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
      float d = length(pa - ba * hs) * cs;
      float r = max(size * (1. + float(L) * .6), 1.4 / uRes.y);
      // ④ 冷却：颜色由炽热色过渡到冷却色，亮度随 age 熄灭；heat 挂鼓点
      float life = smoothstep(0., .08, age) * (1. - smoothstep(.55, 1., age));
      vec3 col3 = mix(hot, cool, smoothstep(.1, .8, age));
      light += col3 * (smoothstep(r, r * .2, d) * (.4 + .6 * hs) + exp(-d / (r * 4.)) * .25) * life * (1. + heat);
    }
  }
  vec3 c = 1. - (1. - src) * (1. - clamp(light, 0., 1.));
  return vec4(c, 1.);
}
