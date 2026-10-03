/*@effect
{
  "id": "paper-tear",
  "name": "纸张撕裂转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["paper tear", "rip", "collage", "zine", "handmade", "撕纸", "撕裂", "拼贴"],
  "summary": "上一个镜头像一张纸被从中间撕开：裂口是锯齿状的，露出白色纸纤维毛边，两半各自带着阴影向上下滑走，露出下面的新镜头。",
  "when": "拼贴/手作/杂志风、青春与校园、“揭开真相”的段落、复古海报感的宣传片。",
  "avoid": "严肃商务；很短的转场（<0.4 秒看不清撕口）。",
  "params": {
    "jagged": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "撕口锯齿" },
    "angle": { "type": "float", "default": 0.08, "min": -0.6, "max": 0.6, "label": "撕裂方向倾斜（弧度）" },
    "fiber": { "type": "color", "default": "#f4efe4", "label": "纸纤维毛边颜色" },
    "shadow": { "type": "float", "default": 0.45, "min": 0, "max": 1, "label": "纸片阴影" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/papercut-red 与 paper-popup：纸艺观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：纸被撕开时，裂口沿着纤维最弱的地方走，所以是不规则锯齿；撕开处纤维被拉出来，露出比纸面更白的毛边
// （印刷面在正面，纸芯是白的）；两半纸片翘起离开，在下面那张上投下柔和阴影。
// 节拍：转场本身由进度驱动，不挂节拍。

// 撕口曲线：相对水平中线的上下偏移（多尺度噪声 = 大弯 + 小锯齿）
float tearLine(float x) {
  return (fxNoise(vec2(x * 3., 1.)) - .5) * .12 + (fxNoise(vec2(x * 22., 5.)) - .5) * .05 * jagged + (fxHash(vec2(floor(x * 140.), 9.)) - .5) * .012 * jagged;
}

vec4 transition(vec2 uv) {
  // ① 撕裂方向：以画面中心为轴把坐标转一点（撕口不必完全水平）。
  vec2 c = uv - .5;
  vec2 r = vec2(c.x * cos(angle) + c.y * sin(angle), -c.x * sin(angle) + c.y * cos(angle));

  // ② 两半分开：上半往上、下半往下，带缓入（先慢慢撕开，再加速飞走）。
  float p = progress * progress;
  float open = p * .75;

  // ③ 判断当前像素属于：上半纸片 / 下半纸片 / 中间露出的新镜头。
  //    上半纸片的撕口在 tear + open，下半在 tear - open；纸片内容按位移取样（纸是整体移动的）。
  float yTop = r.y - open, yBot = r.y + open;           // 纸片自身坐标
  float tTop = tearLine(r.x), tBot = tearLine(r.x);     // 同一条撕口，两边吻合
  float inTop = step(tTop, yTop), inBot = step(yBot, tBot);
  vec2 uvTop = uv - vec2(-sin(angle), cos(angle)) * open;
  vec2 uvBot = uv + vec2(-sin(angle), cos(angle)) * open;

  vec3 col = getToColor(uv).rgb;

  // ④ 阴影：纸片翘起，在新镜头上投下柔和阴影（离撕口越近越深）。
  float sTop = smoothstep(.06, 0., tTop - yTop) * (1. - inTop);
  float sBot = smoothstep(.06, 0., yBot - tBot) * (1. - inBot);
  col *= 1. - max(sTop, sBot) * shadow * min(progress * 6., 1.);

  // ⑤ 纸片：内容 + 撕口处一条宽窄不一的白色纤维毛边。
  float fiberW = .006 + .01 * fxNoise(vec2(r.x * 60., 2.));
  vec3 top = getFromColor(uvTop).rgb;
  top = mix(top, fiber, smoothstep(fiberW, 0., yTop - tTop) * step(.0001, progress));
  vec3 bot = getFromColor(uvBot).rgb;
  bot = mix(bot, fiber, smoothstep(fiberW, 0., tBot - yBot) * step(.0001, progress));
  col = mix(col, top, inTop);
  col = mix(col, bot, inBot);
  return vec4(col, 1.);
}
