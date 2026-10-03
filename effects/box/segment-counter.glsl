/*@effect
{
  "id": "segment-counter",
  "name": "数码管计数器",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["counter", "timecode", "7 segment", "digits", "countdown", "number", "数码管", "计数器", "时间码", "数字滚动"],
  "summary": "在画面上叠一排发光的七段数码管：可显示歌曲时间码（分:秒.帧）、镜头进度百分比，或在镜头内从起始值滚动到目标值；未点亮的段落淡淡可见，鼓点时数字亮一下。",
  "when": "倒计时、数据增长（用户数、销量、百分比）、计时器、科技/赛车/实验室风格的界面元素、MV 里的时间码装饰。",
  "avoid": "需要显示小数精度很高或超过 6 位的数字；温柔手绘风画面（数码管是硬朗的电子元素）。",
  "params": {
    "mode": { "type": "float", "default": 2, "min": 0, "max": 2, "label": "模式：0 歌曲时间码 / 1 镜头进度百分比 / 2 从起始值滚到目标值" },
    "fromValue": { "type": "float", "default": 0, "min": 0, "max": 999999, "label": "起始值（模式 2）" },
    "toValue": { "type": "float", "default": 2026, "min": 0, "max": 999999, "label": "目标值（模式 2）" },
    "countEnd": { "type": "float", "default": 0.6, "min": 0.05, "max": 1, "label": "滚动完成于镜头进度（模式 2）" },
    "digitH": { "type": "float", "default": 0.2, "min": 0.03, "max": 0.6, "label": "数字高度（画面高度比例）" },
    "posX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "posY": { "type": "float", "default": 0.22, "min": 0, "max": 1, "label": "中心 Y（下 0 上 1）" },
    "flash": { "type": "float", "default": 0.15, "min": 0, "max": 1, "label": "鼓点增亮（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#ff4d12", "label": "段码颜色" },
    "panel": { "type": "float", "default": 0.55, "min": 0, "max": 1, "label": "背板不透明度" }
  },
  "bindings": { "flash": { "to": "kick", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：数字滚动/计数器", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：七段数码管是 7 根发光的条形 LED（a 上 b 右上 c 右下 d 下 e 左下 f 左上 g 中），点亮不同组合显示 0–9；
// 未点亮的段在实物上也隐约可见（玻璃下的灰色段）。计数器动画的关键是“数字滚动”：数值按缓动曲线变化，个位跳得最快。

// 0–9 的段码（bit0=a … bit6=g）
const int SEG[10] = int[10](63, 6, 91, 79, 102, 109, 125, 7, 127, 111);

// 第 s 段的矩形（数字格坐标：宽 1，高 2，y 向下），返回点到段的有符号距离
float segDist(vec2 p, int s) {
  vec2 c; vec2 h;
  float t = .11;                               // 段的半厚度
  if (s == 0) { c = vec2(.5, .08); h = vec2(.32, t); }
  else if (s == 1) { c = vec2(.9, .54); h = vec2(t, .36); }
  else if (s == 2) { c = vec2(.9, 1.46); h = vec2(t, .36); }
  else if (s == 3) { c = vec2(.5, 1.92); h = vec2(.32, t); }
  else if (s == 4) { c = vec2(.1, 1.46); h = vec2(t, .36); }
  else if (s == 5) { c = vec2(.1, .54); h = vec2(t, .36); }
  else { c = vec2(.5, 1.); h = vec2(.32, t); }
  vec2 d = abs(p - c) - h;
  // 段两端削尖（六边形段），更像真实数码管
  float tip = (abs(p - c).x + abs(p - c).y * .9) - (h.x + h.y) * .95;
  return max(length(max(d, 0.)) + min(max(d.x, d.y), 0.), tip);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 要显示的 6 位数字和两个分隔点：按模式计算。
  //    模式 0：歌曲时间 mm:ss.ff（ff = 1/30 秒帧）；模式 1：镜头进度 0–100%；模式 2：从起始值到目标值的缓出滚动。
  int m = int(floor(mode + .5));
  float value; int sep = 0;
  if (m == 0) { float t = max(uTime, 0.); value = floor(t / 60.) * 10000. + floor(mod(t, 60.)) * 100. + floor(fract(t) * 30.); sep = 1; }
  else if (m == 1) value = floor(clamp(uProgress, 0., 1.) * 100.);
  else { float k = clamp(uProgress / countEnd, 0., 1.); k = 1. - pow(1. - k, 3.); value = floor(mix(fromValue, toValue, k) + .5); }
  value = clamp(value, 0., 999999.);
  int digits = m == 1 ? 3 : 6;
  if (m == 2) { digits = 1; for (int i = 1; i < 6; i++) if (max(fromValue, toValue) >= pow(10., float(i))) digits = i + 1; }

  // ② 版面：数字格宽 = 0.62×高，格距 0.18×高；整排以 (posX, posY) 居中。
  float hgt = digitH * uRes.y, w = hgt * .5, gap = hgt * .16;
  float total = float(digits) * (w + gap) - gap + (m == 1 ? w * .9 : 0.);
  vec2 px = vec2(uv.x * uRes.x, (1. - uv.y) * uRes.y);
  vec2 origin = vec2(posX * uRes.x - total * .5, (1. - posY) * uRes.y - hgt * .5);
  vec2 local = px - origin;

  float on = 0., off = 0.;
  float aa = 1.5 / w;
  for (int i = 0; i < 6; i++) {
    if (i >= digits) break;
    vec2 cp = (local - vec2(float(i) * (w + gap), 0.)) / vec2(w, hgt * .5);   // 数字格坐标：x 0..1，y 0..2
    if (cp.x < -.2 || cp.x > 1.2 || cp.y < -.1 || cp.y > 2.1) continue;
    cp.x -= (2. - cp.y) * .06;                                                   // 斜体 6°
    int d = int(mod(floor(value / pow(10., float(digits - 1 - i))), 10.));
    for (int s = 0; s < 7; s++) {
      float a = smoothstep(aa, -aa, segDist(cp, s));
      if (((SEG[d] >> s) & 1) == 1) on = max(on, a); else off = max(off, a);
    }
  }
  // ③ 分隔符：时间码模式在第 2、4 位后画两点 / 一点；百分比模式画一个 %（用两个小圆点 + 斜杠）。
  if (sep == 1) {
    for (int k = 1; k <= 2; k++) {
      float x = float(k * 2) * (w + gap) - gap * .5;
      vec2 a = (local - vec2(x, hgt * .32)) / hgt, b = (local - vec2(x, hgt * .72)) / hgt;
      on = max(on, smoothstep(.05, .04, length(b)));
      if (k == 1) on = max(on, smoothstep(.05, .04, length(a)));
    }
  }
  if (m == 1) {
    vec2 q = (local - vec2(float(digits) * (w + gap), 0.)) / hgt;
    float sl = abs(q.x * 1.8 + q.y - 1.25) / 2.06;
    float pc = min(min(length(q - vec2(.15, .25)) - .08, length(q - vec2(.6, .78)) - .08), max(sl - .035, abs(q.y - .5) - .5));
    on = max(on, smoothstep(.01, -.01, pc));
  }

  // ④ 合成：深色背板（让数码管在任何画面上都清楚）→ 未点亮段（暗）→ 点亮段（发光，鼓点时更亮）。
  vec2 boxMin = origin - vec2(gap, gap * .8), boxMax = origin + vec2(total + gap, hgt + gap * .8);
  float inBox = step(boxMin.x, px.x) * step(px.x, boxMax.x) * step(boxMin.y, px.y) * step(px.y, boxMax.y);
  vec3 c = mix(src, src * .1, inBox * panel);
  c = mix(c, color * .16, off * .8);
  c = mix(c, color * (1.1 + flash), on);
  c += color * on * flash * .25;
  return vec4(c, 1.);
}
