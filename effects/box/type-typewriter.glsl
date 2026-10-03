/*@effect
{
  "id": "type-typewriter",
  "name": "打字机揭示",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "typewriter", "type on", "caret", "terminal", "文字动画", "打字机", "逐字出现", "光标"],
  "summary": "文字从左到右一格一格“打”出来，打字头处有一个与字同高、随拍闪烁的光标块；多行文字可按行依次打出；结尾像按退格键一样删回去。",
  "when": "字幕、引文、聊天/终端界面、信件与日记、旁白文字逐句出现；任何横排文字的入场。",
  "avoid": "竖排文字；需要整句同时被读到的快节奏镜头；lineDelay > 0 时 lines 要与文字行数大致对齐，否则一行字会被切成两段先后打出。",
  "params": {
    "lines": { "type": "float", "default": 4, "min": 1, "max": 30, "label": "行数（按画面高度均分，用于按行错开）" },
    "lineDelay": { "type": "float", "default": 0, "min": 0, "max": 0.3, "label": "每行延迟（0 = 各行同时打）" },
    "threshold": { "type": "float", "default": 0.35, "min": 0.05, "max": 0.95, "label": "文字亮度阈值（光标只出现在有字的高度）" },
    "cell": { "type": "float", "default": 0.025, "min": 0.005, "max": 0.15, "label": "每次打出的宽度（画面高度比例）" },
    "inEnd": { "type": "float", "default": 0.6, "min": 0.1, "max": 0.95, "label": "打完于镜头进度" },
    "outStart": { "type": "float", "default": 1, "min": 0.4, "max": 1, "label": "退格开始（1 = 不删除）" },
    "caret": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "光标亮度（通常由节拍驱动）" },
    "ghost": { "type": "float", "default": 0.22, "min": 0, "max": 0.5, "label": "未打出部分的透出" },
    "caretColor": { "type": "color", "default": "#ff4d12", "label": "光标颜色" }
  },
  "bindings": { "caret": { "to": "beat", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：打字机字幕", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：打字机/终端一次只出现一个字符，打完一行回车换行；光标块停在下一个字符的位置闪烁。
// 这里每行按 cell 宽度一格一格揭示，揭示头位置由镜头进度决定（与镜头长短无关）；各行默认同时打（避免把一行字切开），
// 需要“打完一行再打下一行”时调 lineDelay 并让 lines 对齐文字行数。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 稿纸：第几行（从上往下数）、行内第几格。
  float ln = floor((1. - uv.y) * lines);
  float cpx = cell * uRes.y;
  float cols = ceil(uRes.x / cpx);
  float k = floor(uv.x * uRes.x / cpx);

  // ② 打字头：每行自己的进度（按 lineDelay 依次错开；0 = 所有行同时打，不会把一行字切开），出场时退格。
  float p = uProgress;
  float span = max(1. - (lines - 1.) * lineDelay, .1);
  float pr = clamp((p / inEnd - ln * lineDelay) / span, 0., 1.);
  if (outStart < .999) pr *= 1. - clamp((p - outStart) / (1. - outStart), 0., 1.);
  float head = pr * cols;
  float typed = step(k + 1., head);

  // ③ 光标：打字头那一格里、并且这一高度上打字头附近有字（4 次采样）——光标与字同高，空白处不出现；亮度挂每拍。
  float atHead = step(abs(k - floor(head)), .5) * step(pr, .999) * step(.001, pr);
  float hx = (floor(head) + .5) * cpx / uRes.x, dx = cpx / uRes.x;
  float near = max(max(inkAt(vec2(hx - dx, uv.y)), inkAt(vec2(hx, uv.y))), max(inkAt(vec2(hx + dx, uv.y)), inkAt(vec2(hx - 2. * dx, uv.y))));
  float block = atHead * near;

  // ④ 合成：已打出 = 原画面；未打出的“字”极淡地透出（像纸上的压痕），背景始终保持原样；光标叠加在上面。
  float inkHere = inkAt(uv);
  vec3 c = mix(mix(src, src * ghost, inkHere), src, typed);
  c = mix(c, caretColor, block * clamp(caret, 0., 1.));
  return vec4(c, 1.);
}
