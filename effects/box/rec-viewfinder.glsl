/*@effect
{
  "id": "rec-viewfinder",
  "name": "录像取景框",
  "kind": "post",
  "category": "画面版式",
  "tags": ["viewfinder", "camcorder", "rec", "vlog", "found footage", "取景框", "录像", "REC", "DV"],
  "summary": "在画面上叠一层摄像机取景器界面：四角框线、中心十字、红色 REC 圆点随拍闪烁、右上时间码（歌曲时间）、电池与 HD 标识、三分线；画面轻微发灰偏青像 DV 录像。",
  "when": "vlog/第一人称/伪纪录片、复古 DV 回忆、幕后花絮、恐怖片的“发现录像”、直播感。",
  "avoid": "精致的商业成片（界面元素会显得廉价，这正是它的用途）。",
  "params": {
    "uiColor": { "type": "color", "default": "#f2f2f2", "label": "界面颜色" },
    "thirds": { "type": "float", "default": 0.25, "min": 0, "max": 1, "label": "三分线可见度" },
    "dv": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "DV 画质（偏色、发灰）" },
    "blink": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "REC 点亮度（通常由节拍驱动）" },
    "scale": { "type": "float", "default": 0.005, "min": 0.002, "max": 0.012, "label": "字点大小（画面高度比例）" }
  },
  "bindings": { "blink": { "to": "beat", "amount": 0.7 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/living-screencast：界面叠层", "note": "只参考风格名称与观感描述；5×7 点阵字形为本项目自绘" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；字形表由本项目自绘，inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：家用摄像机的取景器在画面上叠一层白色界面——四角框线标出画幅、REC 红点表示正在录制（会闪）、
// 时间码在走、电池图标；DV 磁带的画质偏青偏灰。这些元素组合起来就是“这是一段录像”的符号。

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

float rect(vec2 p, vec2 a, vec2 b) { return step(a.x, p.x) * step(p.x, b.x) * step(a.y, p.y) * step(p.y, b.y); }

vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;
  // ① DV 画质：偏青、发灰、反差略低
  c = mix(c, c * vec3(.92, 1.02, 1.05) * .9 + .05, dv);
  vec2 px = vec2(uv.x, 1. - uv.y) * uRes;                 // 像素坐标，y 向下
  float H = uRes.y, W = uRes.x, m = H * .06, L = H * .07, lw = max(H * .003, 1.);
  float ui = 0.;
  // ② 四角框线
  vec2 cp = min(px, vec2(W, H) - px);
  float inCorner = step(cp.x, m + L) * step(cp.y, m + L) * step(m, cp.x) * step(m, cp.y);
  ui += inCorner * (step(cp.x, m + lw) + step(cp.y, m + lw));
  // ③ 中心十字与三分线
  vec2 cc = abs(px - vec2(W, H) * .5);
  ui += step(cc.x, lw * .6) * step(cc.y, H * .025) + step(cc.y, lw * .6) * step(cc.x, H * .025);
  vec2 th = abs(fract(px / vec2(W, H) * 3. + .5) - .5) * vec2(W, H) / 3.;
  float thirdsLine = (step(th.x, lw * .4) + step(th.y, lw * .4)) * thirds * .35;
  // ④ 文字：左上 "REC"，右上时间码 mm:ss:ff（歌曲时间），左下 "HD"
  float dp = max(scale * H, 1.);
  vec2 o1 = vec2(m + H * .05, m + H * .02);
  ui += text5x7(px, o1, dp, 18, 5, 3, 0, 0, 0, 0, 0, 3);
  float t = max(uTime, 0.);
  int mm = int(mod(floor(t / 60.), 100.)), ss = int(mod(floor(t), 60.)), ff = int(mod(floor(t * 30.), 30.));
  vec2 o2 = vec2(W - m - dp * 48. - H * .01, m + H * .02);
  ui += text5x7(px, o2, dp, 27 + mm / 10, 27 + mm - (mm / 10) * 10, 41, 27 + ss / 10, 27 + ss - (ss / 10) * 10, 41, 27 + ff / 10, 27 + ff - (ff / 10) * 10, 8);
  vec2 o3 = vec2(m + H * .02, H - m - H * .02 - dp * 7.);
  ui += text5x7(px, o3, dp, 8, 4, 0, 0, 0, 0, 0, 0, 2);
  // 右下电池
  vec2 b0 = vec2(W - m - H * .09, H - m - H * .055), b1 = b0 + vec2(H * .06, H * .03);
  ui += rect(px, b0, b1) * (1. - rect(px, b0 + lw * 1.5, b1 - lw * 1.5)) + rect(px, b0 + lw * 3., vec2(b0.x + H * .042, b1.y - lw * 3.)) + rect(px, vec2(b1.x, b0.y + H * .009), vec2(b1.x + lw * 2., b1.y - H * .009));
  // ⑤ REC 红点：在 REC 左侧，亮度挂每拍（每拍闪一次）
  float dot_ = smoothstep(dp * 3.2, dp * 2.6, length(px - (o1 + vec2(-H * .03, dp * 3.5))));
  c = mix(c, uiColor, clamp(ui, 0., 1.) * .9);
  c = mix(c, uiColor, clamp(thirdsLine, 0., 1.));
  c = mix(c, vec3(1., .12, .1), dot_ * (.35 + .65 * blink));
  return vec4(c, 1.);
}
