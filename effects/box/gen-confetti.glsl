/*@effect
{
  "id": "gen-confetti",
  "name": "彩纸飘落",
  "kind": "post",
  "category": "生成层",
  "tags": ["confetti", "celebration", "party", "particles", "overlay", "彩纸", "庆祝", "派对", "撒花"],
  "summary": "五彩的长方形彩纸片从上方飘落，每片都在空中翻转（宽度随翻面一缩一放、明暗交替）、左右摇摆；每个小节开头再撒下一把新的。",
  "when": "庆祝、颁奖、生日、发布会高潮、副歌爆点、“恭喜”字幕。",
  "avoid": "悲伤或严肃题材；画面已经非常花哨时（会乱成一片）。",
  "params": {
    "density": { "type": "float", "default": 0.75, "min": 0, "max": 1, "label": "彩纸数量" },
    "size": { "type": "float", "default": 0.022, "min": 0.005, "max": 0.06, "label": "纸片大小（画面高度比例）" },
    "fall": { "type": "float", "default": 0.18, "min": 0.03, "max": 0.6, "label": "下落速度" },
    "burst": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "小节撒花（通常由节拍驱动）" },
    "c1": { "type": "color", "default": "#ff4d6d", "label": "颜色 1" },
    "c2": { "type": "color", "default": "#ffd23f", "label": "颜色 2" },
    "c3": { "type": "color", "default": "#3bceac", "label": "颜色 3" },
    "c4": { "type": "color", "default": "#5b8cff", "label": "颜色 4" }
  },
  "bindings": { "burst": { "to": "bar", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：庆祝粒子", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：彩纸是薄而轻的小长方形，下落时不断翻转（看起来一会儿宽一会儿窄、正反面一亮一暗），
// 同时被气流带着左右飘。生成：画面分格，每格一片纸；位置 = 哈希起点 + 下落 + 摆动；
// 每片纸的旋转角和“翻面”相位各自不同。只检查本格与上方一格（纸片可能跨格）。

vec3 pal(float h) { return h < .25 ? c1 : h < .5 ? c2 : h < .75 ? c3 : c4; }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, 1. - uv.y);
  float cellSize = size * 4.;
  vec3 c = src;

  // ① 撒花强度：基础数量 + 每小节开头的一把（burst 挂小节），纸片数量随之增加。
  float dens = clamp(density * .55 + burst * .45, 0., 1.);
  for (int layer = 0; layer < 2; layer++) {
    float L = float(layer);
    float cs = cellSize * (1. + L * .6);
    vec2 q = p / cs;
    q.y -= uTime * fall * (1. + L * .4) / cs;
    for (int j = 0; j < 2; j++) {
      vec2 id = floor(q) + vec2(0., float(j));
      float h = fxHash(id + L * 17.);
      if (h > dens) continue;
      // ② 纸片位置与摆动
      vec2 ctr = id + vec2(fxHash(id + 1.1 + L), fxHash(id + 2.3 + L));
      ctr.x += sin(uTime * (1.2 + h * 2.) + h * 40.) * .35;
      vec2 d = (q - ctr) * cs / size;
      // ③ 旋转 + 翻面：纸片绕自身轴旋转（angle），翻面让宽度按 |cos| 缩放、正反面明暗不同
      float ang = uTime * (1. + h * 3.) + h * 20.;
      d = fxRot(ang) * d;
      float flip = cos(uTime * (3. + h * 4.) + h * 9.);
      vec2 hs = vec2(.5 * max(abs(flip), .08), .9);
      vec2 e = abs(d) - hs;
      float m = smoothstep(.08, -.02, max(e.x, e.y));
      vec3 col = pal(fxHash(id + 9.7 + L)) * (flip > 0. ? 1. : .7);
      c = mix(c, col, m * (.95 - L * .15));
    }
  }
  return vec4(c, 1.);
}
