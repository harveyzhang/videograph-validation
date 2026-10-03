/*@effect
{
  "id": "browser-window",
  "name": "浏览器窗口",
  "kind": "post",
  "category": "画面版式",
  "tags": ["browser", "window", "mockup", "ui frame", "web", "浏览器", "窗口", "界面样机", "网页"],
  "summary": "把画面缩进一个圆角浏览器窗口里：顶部标题栏带红黄绿三个圆点和地址栏，窗口浮在柔和的渐变背景上并有阴影；窗口以弹性缩放入场，鼓点时轻轻浮起。",
  "when": "网站/SaaS/App 产品介绍、技术分享、界面录屏的包装、“上网冲浪”的复古梗。",
  "avoid": "需要画面全屏的电影感镜头。",
  "params": {
    "scale": { "type": "float", "default": 0.78, "min": 0.4, "max": 0.95, "label": "窗口大小" },
    "radius": { "type": "float", "default": 0.018, "min": 0, "max": 0.06, "label": "圆角" },
    "dark": { "type": "bool", "default": false, "label": "深色标题栏" },
    "inEnd": { "type": "float", "default": 0.2, "min": 0, "max": 0.8, "label": "入场完成于镜头进度" },
    "lift": { "type": "float", "default": 0, "min": 0, "max": 0.02, "label": "鼓点浮起（通常由节拍驱动）" },
    "bgA": { "type": "color", "default": "#e8ecff", "label": "背景渐变色 A" },
    "bgB": { "type": "color", "default": "#ffd9e8", "label": "背景渐变色 B" }
  },
  "bindings": { "lift": { "to": "kick", "amount": 0.006 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/living-screencast：录屏包装", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（产品视频的“样机”包装）：把录屏放进一个浏览器/系统窗口的外框里，窗口浮在干净的背景上，
// 观众一眼就知道“这是一个网页/软件”。窗口外框由标题栏、三个控制圆点、地址栏组成。

float rbox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.)) + min(max(q.x, q.y), 0.) - r; }

vec4 effect(vec2 uv) {
  float A = uRes.x / uRes.y;
  // ① 入场弹性缩放 + 鼓点浮起（lift 挂 kick）
  float t = inEnd <= 0. ? 1. : clamp(uProgress / inEnd, 0., 1.);
  float e = 1. - pow(1. - t, 3.) + sin(t * 3.1416) * .06;
  float s = scale * mix(.85, 1., e);
  vec2 p = (uv - vec2(.5, .5 + lift)) * vec2(A, 1.);
  float barH = .055 * s;
  vec2 half_ = vec2(A * s * .5, s * .5);
  // ② 背景：对角渐变
  vec3 c = mix(bgA, bgB, uv.x * .6 + uv.y * .4);
  // ③ 投影：窗口下方偏移的柔和暗影
  float dsh = rbox(p - vec2(0., -.02), half_, radius);
  c *= 1. - .25 * exp(-max(dsh, 0.) * 25.) * e;
  float d = rbox(p, half_, radius);
  float inWin = smoothstep(.0015, -.0015, d) * step(.001, e);
  // ④ 窗口内容：原画面缩进窗口（去掉标题栏的高度）
  vec2 local = (p + half_) / (half_ * 2.);
  float contentTop = 1. - barH / (half_.y * 2.);
  vec3 content = srcTex(vec2(local.x, local.y / contentTop)).rgb;
  // ⑤ 标题栏：底色、三个圆点、地址栏
  vec3 bar = dark ? vec3(.17, .17, .19) : vec3(.93, .93, .95);
  vec2 bp = p - vec2(-half_.x, half_.y - barH * .5);
  float dots = 0.; vec3 dotC = vec3(0.);
  for (int i = 0; i < 3; i++) {
    float dd = length(bp - vec2(barH * (.6 + float(i) * .55), 0.)) - barH * .17;
    float m = smoothstep(.0015, -.0015, dd);
    dotC = mix(dotC, i == 0 ? vec3(1., .37, .34) : i == 1 ? vec3(1., .74, .18) : vec3(.16, .79, .26), m);
    dots = max(dots, m);
  }
  float addr = smoothstep(.0015, -.0015, rbox(p - vec2(0., half_.y - barH * .5), vec2(half_.x * .45, barH * .27), barH * .27));
  bar = mix(bar, dark ? vec3(.26, .26, .28) : vec3(1.), addr);
  bar = mix(bar, dotC, dots);
  vec3 win = local.y > contentTop ? bar : content;
  c = mix(c, win, inWin);
  return vec4(c, 1.);
}
