/*@effect
{
  "id": "pixel-title",
  "name": "点阵标题字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "title", "pixel font", "dot matrix", "headline", "bitmap", "文字", "标题", "点阵字", "像素字"],
  "summary": "在画面上直接生成一行 5×7 点阵大字（最多 8 个字符：A–Z、0–9、- ! . ? : +），每个点是圆角发光方块；字符按顺序弹出入场、结尾依次缩回，鼓点时整行跳一下。",
  "when": "需要在任意镜头上叠一个英文/数字标题、倒计时数字、口号（HELLO、2026、GO!、NEW）；复古游戏、电子乐、科技发布。",
  "avoid": "中文标题（点阵字库只有英文大写、数字与少量符号，中文请用场景代码写字）；超过 8 个字符的句子。",
  "params": {
    "chars1": { "type": "vec4", "default": [6, 24, 0, 2], "label": "字符 1–4（编码：0 空格，1–26 = A–Z，27–36 = 数字 0–9，37 - 38 ! 39 . 40 ? 41 : 42 +）" },
    "chars2": { "type": "vec4", "default": [15, 24, 38, 0], "label": "字符 5–8（同上编码；默认拼出 FX BOX!）" },
    "dotSize": { "type": "float", "default": 0.022, "min": 0.004, "max": 0.08, "label": "点大小（画面高度比例）" },
    "posX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "posY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y（下 0 上 1）" },
    "inEnd": { "type": "float", "default": 0.3, "min": 0.02, "max": 0.8, "label": "入场完成于镜头进度" },
    "outStart": { "type": "float", "default": 0.9, "min": 0.4, "max": 1, "label": "出场开始（1 = 不出场）" },
    "hop": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点跳动（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#ffd23f", "label": "字色" },
    "shadowColor": { "type": "color", "default": "#c21d0b", "label": "投影色" }
  },
  "bindings": { "hop": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/pixel-rpg 与 microgame：点阵标题字", "note": "只参考风格名称与观感描述；5×7 点阵字形为本项目自绘" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；字形表由本项目自绘，inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：LED 跑马灯、街机计分板和老游戏的标题都用 5×7 点阵字——每个字符是 5 列 × 7 行的小灯，亮哪几盏由字形表决定。
// 宿主的参数里没有字符串类型，所以字符用编码写进两个 vec4（见参数说明）；字形表把 35 个点拆成两个整数（前 4 行 / 后 3 行）。

const int GA[43] = int[43](0, 1033774, 509487, 34350, 575023, 492607, 492607, 951854, 1033777, 135310, 270620, 103729, 33825, 710513, 841329, 575022, 509487, 575022, 509487, 459838, 135327, 575025, 575025, 706097, 141873, 141873, 139807, 714286, 135364, 279086, 266527, 305544, 539711, 492620, 139807, 476718, 1001006, 1015808, 135300, 0, 279086, 6336, 1020032);
const int GB[43] = int[43](0, 17969, 15921, 14881, 15921, 31777, 1057, 31281, 17969, 14468, 6440, 17701, 31777, 17969, 17969, 14897, 1057, 22837, 17701, 15888, 4228, 14897, 4433, 10933, 17962, 4228, 31778, 14899, 14468, 31812, 14896, 8479, 14896, 14897, 2114, 14897, 6416, 0, 4100, 6336, 4100, 198, 132);

// 编码 → 第 (col,row) 盏灯是否亮（row 0 在最上）
float lit(int code, int col, int row) {
  int c = clamp(code, 0, 42);
  if (col < 0 || col > 4 || row < 0 || row > 6) return 0.;
  int bits = row < 4 ? GA[c] : GB[c];
  int idx = row < 4 ? row * 5 + col : (row - 4) * 5 + col;
  return float((bits >> idx) & 1);
}

int codeAt(int i) {
  float v = i < 4 ? chars1[i] : chars2[i - 4];
  return int(floor(v + .5));
}

// 一个字符位置上的点阵（含入场缩放），返回 (亮度, 是否在点内的软边)
float glyph(vec2 cellPos, int i, float scale) {
  // cellPos：以字符格左上角为原点、以“点”为单位的坐标（x 向右 0..6，y 向下 0..7）
  vec2 c = vec2(2.5, 3.5);
  vec2 q = (cellPos - c) / max(scale, .001) + c;
  vec2 cell = floor(q);
  vec2 f = fract(q) - .5;
  float on = lit(codeAt(i), int(cell.x), int(cell.y));
  float r = .36;
  float d = length(max(abs(f) - vec2(r - .12), 0.)) - .12;      // 圆角方块
  return on * smoothstep(.04, -.04, d);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 排版：最后一个非空字符决定行宽（尾部空格不占位），整行以 (posX, posY) 居中；每字符 6 点宽（5 点 + 1 点字距）。
  float dp = dotSize * uRes.y;          // 点大小换算成像素（与分辨率无关）
  int count = 0;
  for (int i = 0; i < 8; i++) if (codeAt(i) != 0) count = i + 1;
  vec2 px = vec2(uv.x * uRes.x, (1. - uv.y) * uRes.y);
  vec2 origin = vec2(posX * uRes.x - float(count) * 6. * dp * .5 + dp * .5, (1. - posY) * uRes.y - 3.5 * dp);

  // ② 入场/出场：每个字符依次从 0 弹到 1（略过冲），结尾依次缩回；hop 挂鼓点——字符依次往上跳一下（像波）。
  float p = uProgress;
  float lum = 0., sh = 0.;
  for (int i = 0; i < 8; i++) {
    if (i >= count) break;
    float order = float(i) / max(float(count), 1.);
    float tIn = clamp((p / inEnd - order * .6) / .4, 0., 1.);
    float sIn = tIn < 1. ? 1. - pow(1. - tIn, 3.) + sin(tIn * 3.1416) * .25 : 1.;
    float tOut = outStart < .999 ? clamp(((p - outStart) / (1. - outStart) - order * .5) / .5, 0., 1.) : 0.;
    float s = sIn * (1. - tOut * tOut);
    float jump = hop * .8 * sin(clamp(1. - fract(uBeat + order * .3), 0., 1.) * 3.1416);
    vec2 cp = (px - origin - vec2(float(i) * 6. * dp, -jump * dp)) / dp;
    if (cp.x < -1. || cp.x > 6. || cp.y < -1. || cp.y > 8.) continue;
    lum = max(lum, glyph(cp, i, s));
    // ③ 硬投影：向右下 0.45 点
    sh = max(sh, glyph(cp - vec2(.45, .45), i, s));
  }

  // ④ 合成：投影 → 字（带一点上亮下暗的渐变，像灯珠受光）→ 一圈很淡的辉光。
  vec3 c = mix(src, shadowColor * .8, sh * (1. - lum) * .9);
  float grad = 1.08 - .2 * fract((px.y - origin.y) / (7. * dp));
  c = mix(c, color * grad, lum);
  return vec4(c, 1.);
}
