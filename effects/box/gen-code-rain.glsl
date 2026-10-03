/*@effect
{
  "id": "gen-code-rain",
  "name": "代码雨",
  "kind": "post",
  "category": "生成层",
  "tags": ["code rain", "digital rain", "matrix", "hacker", "glyphs", "代码雨", "数字雨", "黑客", "字符"],
  "summary": "一列列绿色的伪字符从上往下落，每列的“雨头”最亮发白、身后拖着渐暗的尾巴，字符在落下过程中偶尔变换；可以叠在画面上，或只透过画面亮部显示（像画面由代码组成）。",
  "when": "黑客/网络/AI/赛博题材、“数字世界”的转场段、科技片头。",
  "avoid": "温暖自然题材；需要看清人物表情的镜头（可调低 opacity 或开启 shapeOnly）。",
  "params": {
    "cell": { "type": "float", "default": 0.026, "min": 0.008, "max": 0.08, "label": "字符大小（画面高度比例）" },
    "speed": { "type": "float", "default": 0.6, "min": 0.1, "max": 3, "label": "下落速度" },
    "opacity": { "type": "float", "default": 0.85, "min": 0, "max": 1, "label": "代码雨强度" },
    "shapeOnly": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "只在画面亮部显示（0 全屏 / 1 只在亮部）" },
    "surge": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点增亮（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#3dff6e", "label": "字符颜色" }
  },
  "bindings": { "surge": { "to": "kick", "amount": 0.9 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：字符雨", "note": "按思路自写；字符为程序生成的点阵伪字形，不使用任何字体" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（早期终端屏幕的艺术化）：绿色荧光屏上一列列字符向下滚动，新写入的字符最亮（荧光刚被激发），
// 旧的字符逐渐暗去（荧光余辉）；字符本身偶尔被改写。这里字符是 3×5 点阵伪字形，由哈希生成。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float cpx = cell * uRes.y;
  vec2 g = vec2(uv.x * uRes.x, (1. - uv.y) * uRes.y) / vec2(cpx * .7, cpx);
  vec2 id = floor(g), f = fract(g);

  // ① 每列一个“雨头”：位置随时间下落（每列速度、起点不同），循环长度 = 屏高格数 × 1.6。
  float rows = uRes.y / cpx;
  float h = fxHash(vec2(id.x, 1.));
  float headY = fract(uTime * speed * (.3 + h * .5) / 1.6 + h) * rows * 1.6;
  float behind = headY - id.y;                             // 当前格在雨头之后多少格（>0 = 已经落过）
  float trailLen = rows * (.35 + .4 * fxHash(vec2(id.x, 2.)));
  float bright = behind >= 0. ? exp(-behind / (trailLen * .35)) : 0.;
  float isHead = step(abs(behind - .5), .5);

  // ② 字形：3×5 点阵，比特由哈希给出；每个字符按自己的节奏偶尔改写（每 0.1–0.6 秒）。
  float rate = 2. + fxHash(id) * 8.;
  vec2 q = (f - vec2(.15, .1)) / vec2(.7, .8);
  float bit = 0.;
  if (q.x >= 0. && q.x < 1. && q.y >= 0. && q.y < 1.) bit = step(.5, fxHash(id * 1.7 + floor(q * vec2(3., 5.)) * 3.1 + floor(uTime * rate)));

  // ③ 亮度：雨头发白、尾巴绿色渐暗；surge 挂鼓点：鼓点时整片代码亮一下。
  float lum = bit * bright * (1. + surge * .6);
  vec3 code = mix(color, vec3(.85, 1., .9), isHead) * lum;

  // ④ 只在亮部显示：用画面亮度作遮罩（画面像由代码组成）；0 = 全屏代码雨。
  float mask = mix(1., smoothstep(.15, .6, fxLuma(src)), shapeOnly);
  vec3 c = mix(src, src * .25, opacity * .6);               // 底下画面压暗，代码才看得清
  c += code * mask * opacity;
  return vec4(c, 1.);
}
