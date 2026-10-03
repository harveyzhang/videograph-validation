/*@effect
{
  "id": "type-typewriter",
  "name": "打字机揭示",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "typewriter", "type on", "caret", "terminal", "文字动画", "打字机", "逐字出现", "光标"],
  "summary": "画面按行从上到下、行内从左到右一格一格“打”出来，打字头处有一个随拍闪烁的光标块；结尾像按退格键一样从末尾删回去。",
  "when": "字幕、引文、聊天/终端界面、信件与日记、旁白文字逐句出现。",
  "avoid": "文字不是横排或行距与 lines 参数差得很远时（会在行中间切开）；需要整句同时被读到的快节奏镜头。",
  "params": {
    "lines": { "type": "float", "default": 6, "min": 1, "max": 30, "label": "行数（按画面高度均分）" },
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
// 这里把画面当作 lines 行的稿纸，每行按 cell 宽度一格一格揭示；揭示头的位置由镜头进度决定（与镜头长短无关）。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 稿纸：第几行（从上往下数）、行内第几格。
  float ln = floor((1. - uv.y) * lines);
  float cpx = cell * uRes.y;
  float cols = ceil(uRes.x / cpx);
  float k = floor(uv.x * uRes.x / cpx);
  float idx = ln * cols + k;                 // 阅读顺序里的序号
  float total = lines * cols;

  // ② 打字头：进度映射到已打出的格数（入场），出场时从末尾往回删（退格）。
  float p = uProgress;
  float head = clamp(p / inEnd, 0., 1.) * total;
  if (outStart < .999) head *= 1. - clamp((p - outStart) / (1. - outStart), 0., 1.);
  float typed = step(idx + 1., head);

  // ③ 光标：打字头所在的那一格画一个实心块（高度为行高的 70%），亮度挂每拍——跟着节拍闪。
  float atHead = step(abs(idx - floor(head)), .5) * step(head, total - .5);
  float lineY = fract((1. - uv.y) * lines);
  float block = atHead * step(.15, lineY) * step(lineY, .85) * step(.15, fract(uv.x * uRes.x / cpx));

  // ④ 合成：已打出 = 原画面；未打出 = 原画面极淡地透出（像纸上的压痕），光标叠加在上面。
  vec3 c = mix(src * ghost, src, typed);
  c = mix(c, caretColor, block * clamp(caret, 0., 1.));
  return vec4(c, 1.);
}
