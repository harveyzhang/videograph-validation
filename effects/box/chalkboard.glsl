/*@effect
{
  "id": "chalkboard",
  "name": "黑板粉笔",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["chalkboard", "chalk", "blackboard", "classroom", "粉笔", "黑板", "板书"],
  "summary": "墨绿黑板上用粉笔画出轮廓与排线：粉笔线断断续续带颗粒，亮处淡淡涂抹一层，背景有擦过的残留粉痕；鼓点时下笔更粗。",
  "when": "教学、知识科普、校园回忆、讲解型宣传片、手绘信息图；文字标题效果好。",
  "avoid": "要看清细节或颜色的镜头；低对比的画面（轮廓少，黑板会显空）。",
  "params": {
    "board": { "type": "color", "default": "#1f3b2f", "label": "黑板颜色" },
    "chalk": { "type": "color", "default": "#f1efe6", "label": "粉笔颜色" },
    "weight": { "type": "float", "default": 0.5, "min": 0.2, "max": 1.2, "label": "笔画粗细" },
    "fill": { "type": "float", "default": 0.45, "min": 0, "max": 1, "label": "亮部涂抹" },
    "colorChalk": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "彩色粉笔比例" }
  },
  "bindings": { "weight": { "to": "kick", "amount": 0.3 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/whiteboard：讲解型手绘观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：黑板表面是细砂质的漆面，粉笔划过时只在凸起处留下碳酸钙粉，所以线条是断续的颗粒；
// 老师用粉笔侧面大面积涂抹时会得到一层薄薄的半透明白；擦过的黑板永远留着灰白的擦痕。

vec4 effect(vec2 uv) {
  vec2 p = uv * uRes;

  // ① 手抖：手画的线不会完全贴着原轮廓，用低频噪声把采样位置轻微推开（约 1.5 像素）。
  vec2 wob = (vec2(fxNoise(p * .02), fxNoise(p * .02 + 7.)) - .5) * 3. / uRes;
  vec3 src = srcTex(uv + wob).rgb;

  // ② 黑板：底色 + 板面细微明暗 + 擦过留下的弧形擦痕（低频、横向拉长的噪声）。
  float smear = smoothstep(.55, .85, fxNoise(vec2(uv.x * 3., uv.y * 9.) + fxNoise(uv * 2.) * 2.));
  vec3 c = board * (.9 + .15 * fxNoise(p * .05)) + chalk * smear * .07;

  // ③ 粉笔颗粒：漆面凸点才接到粉（像素级噪声，静止）。
  float grit = smoothstep(.3, .75, fxNoise(p * .8) * .7 + fxHash(floor(p)) * .3);

  // ④ 轮廓线：边缘（9 次采样）处画粉笔线；weight 挂鼓点——鼓点时笔画更粗更实。
  float e = smoothstep(.35 - weight * .25, .6 - weight * .3, fxSobel(uv + wob));
  float line = e * mix(.4, 1., grit);

  // ⑤ 亮部涂抹：用粉笔侧面斜着涂，亮处覆盖一层带方向纹理的薄粉。
  float lum = fxLuma(src);
  float side = .5 + .5 * sin(dot(p, vec2(.6, .8)) * .9 + fxNoise(p * .05) * 5.);
  float rub = smoothstep(.45, .9, lum) * fill * (.5 + .5 * side) * mix(.3, 1., grit);

  // ⑥ 粉笔颜色：大部分是白粉笔，原图饱和处换成同色系的淡彩粉笔（粉笔颜色都发粉发灰）。
  float sat = max(max(src.r, src.g), src.b) - min(min(src.r, src.g), src.b);
  vec3 pastel = mix(vec3(fxLuma(src)), src, .7) * .6 + .4;
  vec3 ink = mix(chalk, pastel, smoothstep(.15, .45, sat) * colorChalk);

  c = mix(c, ink, clamp(line * .95 + rub * .6, 0., 1.));
  return vec4(c, 1.);
}
