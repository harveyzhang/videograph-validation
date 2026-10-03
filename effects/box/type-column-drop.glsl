/*@effect
{
  "id": "type-column-drop",
  "name": "逐列落字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "kinetic type", "drop in", "bounce", "stagger", "文字动画", "入场", "落字", "弹跳"],
  "summary": "画面按字宽切成竖列，镜头开头每列像字块一样从上方依次落下、弹两下站稳；结尾再一列列掉出画面。鼓点时整排字轻轻一蹲。",
  "when": "标题、口号、歌词大字、品牌名的入场/出场；海报式字体镜头；需要“有节奏地砸进来”的文字。",
  "avoid": "画面主体不是文字或大色块时（会变成整幅画面被切条下落）；镜头很短（<1.5 秒）时入场来不及看清。",
  "params": {
    "columns": { "type": "float", "default": 12, "min": 3, "max": 40, "label": "列数（≈ 字数）" },
    "inEnd": { "type": "float", "default": 0.3, "min": 0.05, "max": 0.7, "label": "入场完成于镜头进度" },
    "outStart": { "type": "float", "default": 0.88, "min": 0.4, "max": 1, "label": "出场开始于镜头进度（1 = 不出场）" },
    "stagger": { "type": "float", "default": 0.6, "min": 0, "max": 0.9, "label": "列间错落" },
    "shuffle": { "type": "float", "default": 0.25, "min": 0, "max": 1, "label": "顺序打乱" },
    "squash": { "type": "float", "default": 0, "min": 0, "max": 0.06, "label": "鼓点下蹲（通常由节拍驱动）" },
    "fill": { "type": "color", "default": "#0d0d0f", "label": "空位底色" }
  },
  "bindings": { "squash": { "to": "kick", "amount": 0.025 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：文字入场/逐字弹跳", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（AE 文字动画预设）：设计师把一行字拆成单个字符，每个字符从画外落下，用“弹跳”缓动着陆，
// 字符之间按顺序错开几帧（stagger）——这就是最常见的“逐字入场”。这里把画面按列切开代替逐字拆分，
// 列宽≈字宽时效果与逐字一致；入场/出场由镜头进度 uProgress 驱动（不依赖镜头秒数，长短镜头都成立）。

// 弹跳缓动（落地后弹两下）：0→1
float bounceOut(float t) {
  t = clamp(t, 0., 1.);
  if (t < .5454) return 7.5625 * t * t;
  if (t < .9090) { t -= .7272; return 7.5625 * t * t + .75; }
  t -= .9545; return 7.5625 * t * t + .9375;
}

vec4 effect(vec2 uv) {
  // ① 拆字：按列切开，每列一个“字块”；顺序 = 从左到右，可按 shuffle 打乱（像设计师手动调过的错落）。
  float n = max(columns, 1.);
  float col = floor(uv.x * n);
  float order = mix(col / max(n - 1., 1.), fxHash(vec2(col, 7.)), shuffle);

  // ② 入场：每列在自己的时间窗里从上方落下（content 上移量 s：1 = 整屏高之上，0 = 就位），弹跳着陆。
  float p = uProgress;
  float tIn = clamp((p / inEnd - order * stagger) / max(1. - stagger, .05), 0., 1.);
  float s = 1. - bounceOut(tIn);

  // ③ 出场：结尾按同样顺序加速掉出画面底部（s 为负 = 向下移）。outStart = 1 时不出场。
  float tOut = outStart < .999 ? clamp(((p - outStart) / (1. - outStart) - order * stagger) / max(1. - stagger, .05), 0., 1.) : 0.;
  s -= tOut * tOut * 1.2;

  // ④ 鼓点下蹲：已就位的列在鼓点那一下整体下沉一点再弹回（squash 挂 kick），像字块被低音压了一下。
  s -= squash * (1. - abs(s)) * (.6 + .4 * fxHash(vec2(col, 3.)));

  // ⑤ 取样：显示位置 y 对应原画面的 y - s；超出画面的部分是空位（底色）。
  //    列的上下边缘加一点阴影，让“落下的字块”有厚度。
  float y = uv.y - s;
  if (y < 0. || y > 1.) return vec4(fill, 1.);
  vec3 c = srcTex(vec2(uv.x, y)).rgb;
  //    就位（s≈0）时完全等于原画面；只有移动中的列，在上下边缘 6 像素内压暗。
  float edge = min(y, 1. - y) * uRes.y;
  c *= 1. - .25 * (1. - smoothstep(0., 6., edge)) * step(.0005, abs(s));
  return vec4(c, 1.);
}
