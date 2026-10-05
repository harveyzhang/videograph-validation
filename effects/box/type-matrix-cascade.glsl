/*@effect
{
  "id": "type-matrix-cascade",
  "name": "字符瀑布成字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "matrix", "cascade", "digital rain", "reveal", "文字动画", "代码雨", "成字", "黑客"],
  "summary": "一列列绿色字符雨从上往下落，雨滴落到文字的位置就“凝固”下来变成亮绿的字形，最终整句文字由凝固的字符点阵组成；文字以外的雨继续落下并渐渐稀疏。",
  "when": "黑客/AI/网络安全题材的标题、数字世界的揭示、科技发布的口号。",
  "avoid": "温暖手作题材；细小的字（字符格比笔画粗时拼不出字形）。",
  "params": {
    "cell": { "type": "float", "default": 0.018, "min": 0.006, "max": 0.05, "label": "字符大小（画面高度比例）" },
    "inEnd": { "type": "float", "default": 0.5, "min": 0.05, "max": 0.95, "label": "成字完成于镜头进度" },
    "rain": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "背景字符雨密度" },
    "glow": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "成字亮度（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#3dff6e", "label": "字符颜色" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "glow": { "to": "kick", "amount": 0.4 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：字符雨成字", "note": "按思路自写；字符为程序生成的点阵伪字形" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（电影里的数字雨与“成字”镜头）：字符一列列下落，落到某个位置就停住、变亮，越积越多，最后显现出一句话。
// 实现：每列有一个随时间下落的“雨头”；雨头走过字所在的格子之后，那个格子就固定显示为亮字符；其他格子只在雨头附近短暂亮起。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float cpx = cell * uRes.y;
  vec2 g = vec2(uv.x * uRes.x, (1. - uv.y) * uRes.y) / vec2(cpx * .7, cpx);
  vec2 id = floor(g), f = fract(g);
  float rows = uRes.y / cpx;
  // ① 本格是否属于字：取格中心的字墨量
  vec2 cuv = vec2((id.x + .5) * cpx * .7 / uRes.x, 1. - (id.y + .5) * cpx / uRes.y);
  float isText = step(.5, inkAt(cuv));
  // ② 雨头位置：每列速度、起点不同；入场期间雨头从顶部扫到底部至少一遍
  float h = fxHash(vec2(id.x, 1.));
  float head = (uProgress / inEnd * (1.1 + h * .6) - h * .3) * rows;
  float behind = head - id.y;
  // ③ 字形：3×5 伪字符；未凝固的字符随时间换形，凝固的字符固定
  vec2 q = (f - vec2(.15, .1)) / vec2(.7, .8);
  float frozen = isText * step(0., behind);
  float seed = frozen > .5 ? 0. : floor(uTime * 10.);
  float bit = 0.;
  if (q.x >= 0. && q.x < 1. && q.y >= 0. && q.y < 1.) bit = step(.42, fxHash(id * 1.7 + floor(q * vec2(3., 5.)) * 3.1 + seed));
  // ④ 亮度：凝固的字 = 亮绿（+ 鼓点辉光）；雨头附近 = 白绿渐暗尾迹；背景雨稀疏地持续落下
  float trail = behind >= 0. ? exp(-behind / 6.) : 0.;
  float bgRain = 0.;
  float h2 = fxHash(vec2(id.x, 7.));
  float head2 = fract(uTime * (.2 + h2 * .3) + h2) * rows * 1.4;
  float b2 = head2 - id.y;
  if (b2 >= 0. && h2 < rain) bgRain = exp(-b2 / 5.) * .6;
  float lum = bit * max(max(frozen * (1. + glow), trail * (1. - frozen)), bgRain * (1. - frozen));
  vec3 col = mix(color, vec3(.85, 1., .9), step(abs(behind - .5), .5) * (1. - frozen)) * lum;
  vec3 c = src * .08 + col;
  return vec4(c, 1.);
}
