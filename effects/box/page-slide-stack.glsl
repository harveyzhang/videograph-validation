/*@effect
{
  "id": "page-slide-stack",
  "name": "卡片叠压转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["card stack", "slide over", "push", "depth", "ui transition", "卡片", "叠压", "推入", "层次"],
  "summary": "下一个镜头像一张带圆角与阴影的卡片从画面下方滑入、盖在上一个镜头上，上一个镜头同时被推远（缩小、变暗、略微后仰），最后新卡片铺满画面、圆角消失。",
  "when": "App/产品介绍、内容合集与图文切换、现代简约的品牌片、社交媒体风格。",
  "avoid": "电影感叙事（UI 感很强）。时长建议 0.6–1 秒。",
  "params": {
    "radius": { "type": "float", "default": 0.04, "min": 0, "max": 0.12, "label": "卡片圆角" },
    "depth": { "type": "float", "default": 0.12, "min": 0, "max": 0.3, "label": "旧镜头推远程度" },
    "fromBottom": { "type": "bool", "default": true, "label": "从下方滑入（关 = 从右侧）" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/dark-keynote：卡片切换", "note": "只参考风格名称与观感描述，代码为本项目自写；与 gl-transitions 的 Slides/swap 不同：带圆角阴影卡片与旧画面景深推远" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（iOS 等系统界面的页面切换）：新页面作为一张卡片从下方滑上来盖住旧页面，旧页面同时缩小、变暗退到后面，
// 给人层次与深度感；卡片到位后圆角消失、铺满屏幕。

float rbox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.)) + min(max(q.x, q.y), 0.) - r; }

vec4 transition(vec2 uv) {
  float p = progress;
  float e = 1. - pow(1. - p, 4.);
  vec2 asp = vec2(ratio, 1.);
  // ① 旧镜头：缩小、变暗
  float s = 1. - depth * e;
  vec3 c = getFromColor((uv - .5) / s + .5).rgb * (1. - .5 * e);
  vec2 qo = abs((uv - .5) / s);
  if (qo.x > .5 || qo.y > .5) c = vec3(.02);
  // ② 新卡片：从下方/右侧滑入；滑入过程中略小于全屏并带圆角，到位时铺满
  vec2 off = fromBottom ? vec2(0., -(1. - e) * 1.05) : vec2((1. - e) * 1.05, 0.);
  float cs = mix(.92, 1., smoothstep(.7, 1., e));
  vec2 q = (uv - .5 - off) / cs;
  float rr = radius * (1. - smoothstep(.85, 1., e));
  float d = rbox(q * asp, asp * .5, rr);
  // ③ 卡片投影（在旧镜头上）
  float sh = rbox((q - vec2(0., -.02)) * asp, asp * .5, rr);
  c *= 1. - .4 * exp(-max(sh, 0.) * 18.) * step(.001, 1. - e);
  float inside = smoothstep(.002, -.002, d);
  c = mix(c, getToColor(q + .5).rgb, inside);
  return vec4(c, 1.);
}
