/*@effect
{
  "id": "wireframe-terrain",
  "name": "线框地形",
  "kind": "post",
  "category": "几何与图形",
  "tags": ["wireframe", "mesh", "terrain", "ridgeline", "synthwave", "3d", "线框", "网格", "山脊线"],
  "summary": "把画面的明暗当作高度，抬成一张发光的线框地形：一条条横向山脊线按亮度隆起、前面的山挡住后面的线，竖向经线向远处收拢；鼓点时山体整体弹高。",
  "when": "电子乐、合成器浪潮、科幻 HUD、数据可视化开场、“数字化”某个画面的瞬间；人像剪影会变成一座山。",
  "avoid": "需要看清原画面的镜头（只剩线框）；画面整体很平（明暗差小）时网格几乎不起伏。",
  "params": {
    "rows": { "type": "float", "default": 34, "min": 12, "max": 60, "label": "山脊线条数" },
    "height": { "type": "float", "default": 0.09, "min": 0, "max": 0.2, "label": "隆起高度" },
    "lineColor": { "type": "color", "default": "#4cf2c8", "label": "线色" },
    "fill": { "type": "float", "default": 0.1, "min": 0, "max": 0.6, "label": "原画面透出" }
  },
  "bindings": { "height": { "to": "kick", "amount": 0.05 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/hologram-hud：线框与 HUD 观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（计算机图形 / 科学绘图）：把一张图当作高度图，按等间距取一条条横剖面，每条剖面按高度向上抬起，
// 从斜前方看过去只画线——前面（画面下方、离观众近）的山脊会挡住后面的线，这就是早期矢量显示器
// 和著名的“脉冲星山脊图”那种立体感的来源。再加上向灭点收拢的经线，就成了一张线框网格。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 横剖面：画面从下到上等距 rows 条基线；第 k 条基线在 y = (k+.5)/rows。
  //    能落到当前像素的剖面，基线一定在当前像素下方 height 以内 → 只需检查下方 12 条（12 次采样）。
  float kTop = floor(uv.y * rows - .5);
  float pxY = 1. / uRes.y;

  // ② 从近到远（从下往上）逐条抬起：剖面在当前 x 处的抬高量 = 该基线处的亮度 × height。
  //    height 挂鼓点：鼓点时所有山体一起弹高再落回。
  //    遮挡：如果更近的某条剖面已经抬到当前像素之上，当前像素就在那座“山”的背后，更远的线不可见。
  float covered = -1.;      // 已处理（更近）的剖面里，抬得最高的屏幕位置
  float line = 0.;
  for (int i = 0; i < 12; i++) {
    float k = kTop - 11. + float(i);
    if (k < 0.) continue;
    float by = (k + .5) / rows;
    float lifted = by + fxLuma(srcTex(vec2(uv.x, by)).rgb) * height;
    float visible = step(covered, uv.y + pxY * .5);
    line = max(line, smoothstep(1.3 * pxY, .2 * pxY, abs(uv.y - lifted)) * visible);   // 线宽约 1.3 像素
    covered = max(covered, lifted);
  }

  // ③ 经线：向画面上方收拢的竖线（越往上越密，模拟透视），画得比山脊线淡，作为网格的“纬向参考”。
  float persp = 1. + uv.y * 1.2;
  float vx = (uv.x - .5) * persp * rows * .9;
  float col = 1. - smoothstep(0., 1.2, abs(fract(vx + .5) - .5) / max(fwidth(vx), 1e-4));

  // ④ 发光：近处（画面下方）亮、远处淡入雾里；亮处（山顶）线更亮，像能量更高。
  float fade = mix(1., .45, uv.y);
  float lines = max(line, col * .35) * fade;

  // ⑤ 合成：背景是深紫夜空 + 一点原画面（fill），线色发光。
  vec3 bg = mix(vec3(.015, .01, .05), vec3(.07, .02, .11), uv.y) + src * fill;
  vec3 c = bg + lineColor * lines * (1. + fxLuma(src) * .5);
  return vec4(c, 1.);
}
