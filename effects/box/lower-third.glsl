/*@effect
{
  "id": "lower-third",
  "name": "下三分之一名牌",
  "kind": "post",
  "category": "画面版式",
  "tags": ["lower third", "name tag", "caption bar", "broadcast", "title bar", "名牌", "字幕条", "人名条", "包装"],
  "summary": "左下角动画出一套电视包装式名牌：强调色竖条先长出，再横向展开深色主条和彩色副条，主条上写最多 8 个字符的标签（英文/数字点阵字）；结尾按相反顺序收回。鼓点时强调色竖条闪亮。",
  "when": "人物介绍、访谈、新闻与纪录片、栏目包装、直播与发布会；也可只要条形不要字（标签全填 0），中文姓名用场景代码写在主条位置。",
  "avoid": "左下角有重要画面内容时（调 posX/posY）；中文标签（点阵字库只含英文大写、数字和少量符号）。",
  "params": {
    "chars1": { "type": "vec4", "default": [22, 9, 4, 5], "label": "标签字符 1–4（编码：0 空格，1–26 = A–Z，27–36 = 0–9，37 - 38 ! 39 . 40 ? 41 : 42 +）" },
    "chars2": { "type": "vec4", "default": [15, 0, 0, 0], "label": "标签字符 5–8（默认合起来是 VIDEO）" },
    "posX": { "type": "float", "default": 0.06, "min": 0, "max": 0.8, "label": "位置 X（左边缘）" },
    "posY": { "type": "float", "default": 0.16, "min": 0, "max": 0.9, "label": "位置 Y（底边，从下往上）" },
    "barW": { "type": "float", "default": 0.34, "min": 0.1, "max": 0.9, "label": "主条宽度（画面宽度比例）" },
    "inEnd": { "type": "float", "default": 0.3, "min": 0.03, "max": 0.8, "label": "展开完成于镜头进度" },
    "outStart": { "type": "float", "default": 0.88, "min": 0.4, "max": 1, "label": "收回开始（1 = 不收回）" },
    "accent": { "type": "color", "default": "#ff4d12", "label": "强调色" },
    "barColor": { "type": "color", "default": "#111216", "label": "主条颜色" },
    "flash": { "type": "float", "default": 0, "min": 0, "max": 0.6, "label": "鼓点闪亮（通常由节拍驱动）" }
  },
  "bindings": { "flash": { "to": "kick", "amount": 0.35 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：栏目包装名牌", "note": "按思路自写；5×7 点阵字形为本项目自绘" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；字形表由本项目自绘，inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（电视包装的“下三分之一”）：人物出场时，画面左下角依次动画出一组图形——强调色竖条先出现，
// 然后主条从竖条后面横向展开，主条上是姓名，下面一条细副条写头衔；离场时按相反顺序收回。
// 这里画全部图形，标签文字用 5×7 点阵字（只支持英文/数字）；中文姓名可以由镜头场景代码画在主条位置上。

const int GA[43] = int[43](0, 1033774, 509487, 34350, 575023, 492607, 492607, 951854, 1033777, 135310, 270620, 103729, 33825, 710513, 841329, 575022, 509487, 575022, 509487, 459838, 135327, 575025, 575025, 706097, 141873, 141873, 139807, 714286, 135364, 279086, 266527, 305544, 539711, 492620, 139807, 476718, 1001006, 1015808, 135300, 0, 279086, 6336, 1020032);
const int GB[43] = int[43](0, 17969, 15921, 14881, 15921, 31777, 1057, 31281, 17969, 14468, 6440, 17701, 31777, 17969, 17969, 14897, 1057, 22837, 17701, 15888, 4228, 14897, 4433, 10933, 17962, 4228, 31778, 14899, 14468, 31812, 14896, 8479, 14896, 14897, 2114, 14897, 6416, 0, 4100, 6336, 4100, 198, 132);

float lit5x7(int code, int col, int row) {
  int c = clamp(code, 0, 42);
  if (col < 0 || col > 4 || row < 0 || row > 6) return 0.;
  int bits = row < 4 ? GA[c] : GB[c];
  int idx = row < 4 ? row * 5 + col : (row - 4) * 5 + col;
  return float((bits >> idx) & 1);
}
// 在像素坐标 px（y 向下）处画一串 5×7 字（左上角 origin，每点 dp 像素），返回墨量
float text5x7(vec2 px, vec2 origin, float dp, int c0, int c1, int c2, int c3, int c4, int c5, int c6, int c7, int count) {
  vec2 q = (px - origin) / dp;
  if (q.y < 0. || q.y >= 7. || q.x < 0. || q.x >= float(count) * 6.) return 0.;
  int i = int(floor(q.x / 6.));
  int col = int(floor(q.x - float(i) * 6.)), row = int(floor(q.y));
  int code = i == 0 ? c0 : i == 1 ? c1 : i == 2 ? c2 : i == 3 ? c3 : i == 4 ? c4 : i == 5 ? c5 : i == 6 ? c6 : c7;
  return lit5x7(code, col, row);
}

float rectM(vec2 p, vec2 a, vec2 b) { return step(a.x, p.x) * step(p.x, b.x) * step(a.y, p.y) * step(p.y, b.y); }

vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;
  vec2 px = uv * uRes;                                    // y 向上（与 posY 一致）
  float H = uRes.y;
  // ① 时间轴：竖条 0–30%，主条 20–80%，副条 45–100%（都在 inEnd 内）；出场时三段倒放
  float p = uProgress;
  float t = clamp(p / inEnd, 0., 1.);
  if (outStart < .999) t = min(t, 1. - clamp((p - outStart) / (1. - outStart), 0., 1.));
  float e1 = 1. - pow(1. - clamp(t / .3, 0., 1.), 3.);
  float e2 = 1. - pow(1. - clamp((t - .2) / .6, 0., 1.), 4.);
  float e3 = 1. - pow(1. - clamp((t - .45) / .55, 0., 1.), 4.);
  vec2 o = vec2(posX * uRes.x, posY * H);
  float bh = H * .085, sh = H * .035, aw = H * .012;
  // ② 强调色竖条（从下往上长出）
  float acc = rectM(px, o, o + vec2(aw, (bh + sh + H * .006) * e1));
  // ③ 主条（从竖条处向右展开）与副条
  float mainW = barW * uRes.x * e2, subW = barW * uRes.x * .7 * e3;
  float mainB = rectM(px, o + vec2(aw, sh + H * .006), o + vec2(aw + mainW, sh + H * .006 + bh));
  float subB = rectM(px, o + vec2(aw, 0.), o + vec2(aw + subW, sh));
  c = mix(c, barColor, mainB * .92);
  c = mix(c, accent * .85, subB * .9);
  c = mix(c, accent * (1. + flash), acc);
  // ④ 标签文字：主条内左侧，被主条遮罩（主条展开到哪字就露到哪）
  float dp = bh * .085;
  int k0 = int(chars1.x + .5), k1 = int(chars1.y + .5), k2 = int(chars1.z + .5), k3 = int(chars1.w + .5);
  int k4 = int(chars2.x + .5), k5 = int(chars2.y + .5), k6 = int(chars2.z + .5), k7 = int(chars2.w + .5);
  int count = k7 != 0 ? 8 : k6 != 0 ? 7 : k5 != 0 ? 6 : k4 != 0 ? 5 : k3 != 0 ? 4 : k2 != 0 ? 3 : k1 != 0 ? 2 : k0 != 0 ? 1 : 0;
  vec2 tp = vec2(px.x, uRes.y - px.y);                    // 文字用 y 向下坐标
  vec2 to = vec2(o.x + aw + bh * .35, uRes.y - (o.y + sh + H * .006 + bh * .5) - 3.5 * dp);
  float txt = text5x7(tp, to, dp, k0, k1, k2, k3, k4, k5, k6, k7, count) * mainB;
  c = mix(c, vec3(.96), txt);
  // 副条上的细装饰线（象征头衔文字）
  float lines = rectM(px, o + vec2(aw + sh * .6, sh * .4), o + vec2(aw + sh * .6 + subW * .5, sh * .6)) * subB;
  c = mix(c, vec3(1.), lines * .7);
  return vec4(c, 1.);
}
