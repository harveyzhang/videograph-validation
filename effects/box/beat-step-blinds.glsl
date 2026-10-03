/*@effect
{
  "id": "beat-step-blinds",
  "name": "节拍阶梯百叶窗",
  "kind": "transition",
  "category": "转场",
  "tags": ["blinds", "slats", "stagger", "beat", "louver", "百叶窗", "错落", "卡点转场"],
  "summary": "画面被切成一排斜向叶片，叶片从一侧到另一侧依次翻转成下一个镜头；翻转是“一下一下”分阶段推进的，每一阶都踩在节拍上，翻转中的叶片有立体明暗。",
  "when": "卡点剪辑、节奏强的段落切换、时尚/潮流/产品发布的多画面轮换。",
  "avoid": "柔和抒情的过渡；转场时长很短（<0.5 秒）时阶梯感出不来。",
  "params": {
    "slats": { "type": "float", "default": 10, "min": 3, "max": 30, "label": "叶片数" },
    "steps": { "type": "float", "default": 4, "min": 1, "max": 8, "label": "分几阶推进（建议 = 转场覆盖的拍数）" },
    "tilt": { "type": "float", "default": 0.35, "min": -1, "max": 1, "label": "叶片倾斜" },
    "punch": { "type": "float", "default": 0, "min": 0, "max": 0.5, "label": "鼓点提亮（通常由节拍驱动）" }
  },
  "bindings": { "punch": { "to": "kick", "amount": 0.18 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：分段揭示", "note": "按思路自写；与 gl-transitions 的 windowblinds（统一同时开合）不同：这里叶片按顺序分阶段、带 3D 翻转明暗" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（舞台/橱窗）：翻转广告牌由一排三棱柱叶片组成，电机一格一格地转，每转一格叶片翻过一个面；
// 让叶片从一侧到另一侧依次翻，就形成波浪式的揭示。把“一格一格”的阶梯对齐到节拍上，就是卡点转场。
// 节拍：punch 挂鼓点，每次鼓点叶片翻面时整体略微提亮；阶梯数 steps 由剪辑师按转场覆盖的拍数设置。

vec4 transition(vec2 uv) {
  // ① 阶梯化的进度：把连续进度量化成 steps 阶，每阶内用快速缓动推进（像电机一下一下转），不是匀速。
  float sp = progress * steps;
  float k = floor(sp), f = fract(sp);
  float stepped = (k + smoothstep(0., .35, f)) / steps;
  stepped = progress >= 1. ? 1. : stepped;

  // ② 叶片：沿倾斜方向切成 slats 条；每条叶片的翻转时刻按位置先后错开（从左到右的波）。
  float along = uv.x + (uv.y - .5) * tilt;
  float s = along * slats;
  float id = floor(s);
  float local = fract(s);
  float delay = clamp((id + .5) / slats, 0., 1.) * .75;
  float t = clamp((stepped - delay) / .25, 0., 1.);      // 这条叶片自己的翻转进度 0..1（翻得快，同时在翻的叶片少）

  // ③ 翻转几何：叶片绕自身中线转 180°——前半程显示旧画面（被压窄），后半程显示新画面（展开）。
  float ang = t * 3.1416;
  float w = abs(cos(ang));                                 // 叶片在屏幕上的可见宽度
  float x = (local - .5) / max(w, 1e-3) + .5;              // 叶片内的取样坐标（压窄 → 拉回）
  float onSlat = step(abs(local - .5), w * .5);
  vec2 suv = vec2(uv.x + (x - local) / slats, uv.y);
  vec3 face = t < .5 ? getFromColor(suv).rgb : getToColor(suv).rgb;

  // ④ 立体明暗：叶片转到侧面时受光变化（一侧亮一侧暗），叶片之外露出的是深色的支架。
  float light = .65 + .35 * cos(ang * 2.);
  vec3 col = mix(vec3(.04), face * light, onSlat);
  col *= 1. + punch;
  return vec4(col, 1.);
}
