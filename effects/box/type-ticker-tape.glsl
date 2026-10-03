/*@effect
{
  "id": "type-ticker-tape",
  "name": "滚动跑马灯",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["ticker", "marquee", "news crawl", "scrolling text", "banner", "跑马灯", "滚动字幕", "新闻条", "横幅"],
  "summary": "在画面底部（或顶部）叠一条新闻台风格的横幅：左侧强调色标签块，右侧把画面里中间一行的内容复制成横向循环滚动的字幕条；滚动速度可调，鼓点时标签块闪亮。",
  "when": "新闻/资讯/直播包装、体育比分、促销与公告、复古电视感、“正在发生”的紧迫感。",
  "avoid": "画面本身没有横排文字时（滚动条会是滚动的画面切片，可以当作装饰带用）。",
  "params": {
    "posY": { "type": "float", "default": 0.07, "min": 0, "max": 0.95, "label": "横幅位置（从下往上）" },
    "barH": { "type": "float", "default": 0.07, "min": 0.03, "max": 0.2, "label": "横幅高度" },
    "sourceY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "从画面哪一行取滚动内容" },
    "speed": { "type": "float", "default": 0.12, "min": -1, "max": 1, "label": "滚动速度（画面宽/秒）" },
    "accent": { "type": "color", "default": "#e6202a", "label": "标签块颜色" },
    "barColor": { "type": "color", "default": "#0d1b2e", "label": "横幅底色" },
    "flash": { "type": "float", "default": 0, "min": 0, "max": 0.6, "label": "鼓点闪亮（通常由节拍驱动）" }
  },
  "bindings": { "flash": { "to": "kick", "amount": 0.3 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：新闻包装", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（电视新闻的滚动字幕条）：屏幕底部一条深色横幅，左边是固定的“快讯/LIVE”标签，右边的文字匀速从右往左滚动、循环播放。
// 宿主没有字符串参数，所以滚动内容取自画面本身的一行（把那一行横向复制成无缝循环的长条）。

vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;
  float y0 = posY, y1 = posY + barH;
  if (uv.y < y0 || uv.y > y1) return vec4(c, 1.);
  float fy = (uv.y - y0) / barH;
  float labelW = barH * 2.6 * uRes.y / uRes.x;
  // ① 标签块（左侧）：强调色 + 白色斜纹装饰，鼓点闪亮
  if (uv.x < labelW) {
    vec3 lc = accent * (1. + flash);
    float stripe = step(.7, fract((uv.x * uRes.x + uv.y * uRes.y) / 10.)) * step(.75, fy) ;
    return vec4(lc + stripe * .15, 1.);
  }
  // ② 滚动条：取画面 sourceY 附近、与横幅等高的一条（按横幅高度缩放），横向无缝循环滚动
  float srcH = barH * 1.4;
  float sx = fract(uv.x + uTime * speed);
  vec3 strip = srcTex(vec2(sx, sourceY - srcH * .5 + fy * srcH)).rgb;
  // ③ 横幅底色 + 内容（亮部作为文字显示为白色）+ 上下细边
  float txt = smoothstep(.4, .6, fxLuma(strip));
  vec3 bc = mix(barColor, vec3(.97), txt);
  float edge = step(fy, .06) + step(.94, fy);
  bc = mix(bc, accent * .8, edge);
  return vec4(bc, 1.);
}
