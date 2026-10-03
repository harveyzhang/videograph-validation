/*@effect
{
  "id": "type-pixel-assemble",
  "name": "像素组装字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "pixel", "assemble", "particles", "build", "文字动画", "像素", "组装", "粒子成字"],
  "summary": "文字由一个个方块像素从画面四周飞来、按随机先后拼成完整的字；拼好后每个鼓点有少数方块弹起再落回；结尾方块飞散消失。",
  "when": "游戏/科技/数据主题的标题、Logo 组装、“构建”“连接”的意象。",
  "avoid": "文字很细或很小（方块大于笔画会拼不出字形）；文字压在复杂背景上（只拼字，背景不动）。",
  "params": {
    "block": { "type": "float", "default": 0.012, "min": 0.004, "max": 0.05, "label": "方块大小（画面高度比例）" },
    "inEnd": { "type": "float", "default": 0.4, "min": 0.05, "max": 0.9, "label": "拼好于镜头进度" },
    "outStart": { "type": "float", "default": 0.9, "min": 0.4, "max": 1, "label": "飞散开始（1 = 不飞散）" },
    "hop": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点弹起（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" }
  },
  "bindings": { "hop": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：粒子成字", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（动态设计的“粒子成字”）：把字栅格化成方块，每块从画外飞到自己的位置，到达时间错开；观众看到碎块拼成字。
// 实现（无帧间状态）：每一行方块从左/右交替飞入（整行共享主位移），每块再带 ±2 格以内的个体错位；
// 像素只需在本行里查 7 个候选方块（7 次采样）就能找到“此刻飞到这里”的方块。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec3 c = mix(src, bg, inkOf(src));                        // 先擦掉原位的字
  float bpx = block * uRes.y;
  vec2 g = uv * uRes / bpx;
  float row = floor(g.y);
  float p = uProgress;
  float cols = uRes.x / bpx;
  // ① 本行主位移：入场从画外（左/右交替）以强缓出飞入；出场向另一侧加速飞走
  float rh = fxHash(vec2(row, 9.));
  float tIn = clamp((p / inEnd - rh * .5) / .5, 0., 1.);
  float e = 1. - pow(1. - tIn, 4.);
  float dir = mod(row, 2.) < 1. ? -1. : 1.;
  float rowOff = dir * (1. - e) * cols * 1.1;
  if (outStart < .999) { float o = clamp(((p - outStart) / (1. - outStart) - rh * .4) / .6, 0., 1.); rowOff -= dir * o * o * cols * 1.1; }
  // ② 在本行里查 7 个候选方块：home = 当前格 − 主位移 ± 3
  float hx0 = floor(g.x - rowOff);
  for (int i = -3; i <= 3; i++) {
    vec2 id = vec2(hx0 + float(i), row);
    vec3 sc = srcTex((id + .5) * bpx / uRes).rgb;
    if (inkOf(sc) < .5) continue;
    float h = fxHash(id);
    // 个体错位：未到位时最多 ±2 格（横向）与 ±1 格（纵向），到位后归零；鼓点时少数方块弹起
    vec2 jit = (vec2(fxHash(id + 1.), fxHash(id + 2.)) - .5) * vec2(4., 2.) * (1. - e);
    jit.y += hop * step(.85, fxHash(id + floor(uTime * 2.))) * sin(clamp(1. - uBeat, 0., 1.) * 3.1416) * .8;
    vec2 pos = id + .5 + vec2(rowOff, 0.) + jit;
    vec2 d = abs(g - pos);
    float sz = .5 * mix(.55, .96, e);                       // 飞行中方块略小，到位后几乎贴合
    if (d.x < sz && d.y < sz) c = sc * mix(1.35, 1., e);
  }
  return vec4(c, 1.);
}
