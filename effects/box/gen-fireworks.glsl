/*@effect
{
  "id": "gen-fireworks",
  "name": "烟花",
  "kind": "post",
  "category": "生成层",
  "tags": ["fireworks", "celebration", "sparks", "night sky", "festival", "烟花", "庆典", "新年", "夜空"],
  "summary": "夜空中依次绽放的烟花：每隔一段时间（默认 2 秒，可设为一小节）在随机位置炸开一朵（颜色各异），火花向外飞散后受重力下坠、拖着尾迹渐暗熄灭；鼓点时火花更亮。",
  "when": "新年/春节/节日、庆典与颁奖、婚礼、副歌高潮、品牌周年。",
  "avoid": "白天画面；需要安静的段落。",
  "params": {
    "size": { "type": "float", "default": 0.22, "min": 0.05, "max": 0.5, "label": "绽放半径（画面高度比例）" },
    "skyTop": { "type": "float", "default": 0.85, "min": 0.4, "max": 1, "label": "绽放区域上沿" },
    "skyBottom": { "type": "float", "default": 0.45, "min": 0, "max": 0.9, "label": "绽放区域下沿" },
    "sparkle": { "type": "float", "default": 0.3, "min": 0, "max": 1.5, "label": "火花亮度增益（通常由节拍驱动）" },
    "gravity": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "重力" },
    "interval": { "type": "float", "default": 2, "min": 0.5, "max": 8, "label": "每朵间隔（秒；设为一小节时长即每小节一朵）" }
  },
  "bindings": { "sparkle": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：庆典粒子", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：烟花弹升到高空后爆炸，里面的“星”（发光药粒）以相近的速度向四面八方飞出，
// 空气阻力让它们减速、重力让轨迹下弯，药粒边烧边暗，最后熄灭；长曝光下每颗星拖出一条尾迹。
// 实现：同时活着的 3 朵烟花（每朵寿命约 2 小节，按小节错开）；每朵 36 颗星，位置由解析公式给出（无帧间状态）。

vec3 hue(float h) { return clamp(abs(fract(h + vec3(0., .667, .333)) * 6. - 3.) - 1., 0., 1.); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp;
  vec3 light = vec3(0.);

  // ① 烟花节奏：每 interval 秒在一个随机位置炸开一朵（默认 2 秒 = 120 BPM 的一小节），每朵活 1.5 个间隔；
  //    同时最多 3 朵。时间只取 uTime，所以同一时刻永远渲染出同一幅画面（无帧间状态）。
  float barIdx = floor(uTime / interval);
  for (int k = 0; k < 3; k++) {
    float idx = barIdx - float(k);                       // 这朵烟花在第 idx 小节炸开
    float age = (uTime - idx * interval) / interval;      // 0..1.5（单位：间隔）
    if (age < 0. || age > 1.5) continue;
    float h = fxHash(vec2(idx, 3.));
    vec2 ctr = vec2(.15 + .7 * fxHash(vec2(idx, 1.)), mix(skyBottom, skyTop, fxHash(vec2(idx, 2.)))) * asp;
    vec3 col = mix(hue(h), vec3(1.), .25);
    float R = size * (.7 + .5 * fxHash(vec2(idx, 4.)));

    // ② 每颗星：初速方向均匀分布，减速 = 1 - exp(-t)（空气阻力）；下坠 = gravity × t²。
    for (int s = 0; s < 36; s++) {
      float a = float(s) / 36. * 6.2832 + fxHash(vec2(idx, float(s))) * .2;
      float sp = R * (.75 + .25 * fxHash(vec2(float(s), idx)));
      float tt = age * 2.;                              // 归一化的飞行时间（与间隔长短无关，形状一致）
      vec2 pos = ctr + vec2(cos(a), sin(a)) * sp * (1. - exp(-tt * 2.2)) - vec2(0., gravity * .08 * tt * tt);
      // ③ 尾迹：沿速度反方向的短线（取上一时刻的位置），越老越暗
      vec2 prev = ctr + vec2(cos(a), sin(a)) * sp * (1. - exp(-(tt - .3) * 2.2)) - vec2(0., gravity * .08 * (tt - .3) * (tt - .3));
      vec2 pa = p - prev, ba = pos - prev;
      float hseg = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0., 1.);
      float d = length(pa - ba * hseg);
      float life = (1. - smoothstep(.4, 1.4, age)) * smoothstep(0., .03, age);
      float twinkle = .7 + .3 * sin(uTime * 40. + float(s) * 3.);    // 火花本身的闪动（单颗、很小）
      float w = 1.6 / uRes.y + .0012;                    // 线宽：至少约 1.6 像素（与分辨率无关地可见）
      light += col * (smoothstep(w, 0., d) + exp(-d / (w * 2.5)) * .35) * life * (.35 + hseg * .9) * twinkle * (1. + sparkle);
    }
    // ④ 爆炸瞬间中心的一团闪光（只在开头 0.1 小节内，局部，不是全屏）
    light += col * exp(-length(p - ctr) / (R * .25)) * exp(-age * 30.) * .8;
  }

  vec3 c = 1. - (1. - src) * (1. - clamp(light, 0., 1.));
  return vec4(c, 1.);
}
