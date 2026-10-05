/*@effect
{
  "id": "liquid-melt",
  "name": "液化流淌转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["melt", "drip", "liquid", "paint drip", "dissolve", "融化", "流淌", "滴落", "液体转场"],
  "summary": "上一个镜头像湿颜料一样从上往下融化流淌：一道道不规则的“滴痕”带着画面向下拉长、往下淌，滴痕边缘有一道亮边，后面露出下一个镜头。",
  "when": "迷幻/艺术/恐怖、颜料与涂鸦题材、情绪崩塌、梦境转场。",
  "avoid": "利落干净的商务风格。时长建议 0.8–1.5 秒。",
  "params": {
    "drips": { "type": "float", "default": 24, "min": 4, "max": 80, "label": "滴痕数量" },
    "stretch": { "type": "float", "default": 0.25, "min": 0, "max": 1.5, "label": "流淌拉伸" },
    "rim": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "滴痕亮边" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：液化转场", "note": "按思路自写；与 gl-transitions 的 luminance_melt/Drop 不同：这里按列不规则滴落并拉伸画面" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：一幅刚画好的湿颜料画被竖起来，颜料受重力往下淌——每一道流痕的速度不同（颜料厚薄不一），
// 流痕前端圆圆的、带一点高光，被拉长的部分颜色也被拉成竖条。

vec4 transition(vec2 uv) {
  vec3 b = getToColor(uv).rgb;
  float p = progress;
  // ① 每道滴痕的速度：按列取噪声（相邻列平滑相关）+ 细小随机；列边缘做成圆弧（滴痕前端是圆的）
  float x = uv.x * drips;
  float sp = .7 + .6 * fxNoise(vec2(x * .5, 3.)) + .2 * fxHash(vec2(floor(x), 7.));
  float colShape = .03 * (1. - cos(fract(x) * 6.2832)) * .5 * min(p * 8., 1.);   // 起始时没有圆头，画面完全等于旧镜头
  // ② 颜料上沿：从画面顶部往下移动（p=0 在顶部之上，p=1 落到底部之下）；上沿以上已经流走，露出新镜头
  float top = 1.05 - p * (1.15 + sp * .6) - colShape;   // 最慢的一列在 p = 1 时也流出画面
  if (uv.y > top) {
    float wet = smoothstep(.025, 0., uv.y - top);          // 刚流走处一道湿亮边
    return vec4(b + rim * wet * .3, 1.);
  }
  // ③ 上沿以下：旧画面整体向下流（下移 1 - top），越靠上沿被拉得越长
  float shift = max(1.05 - top, 0.);
  float k = clamp((top - uv.y) / max(top, .001), 0., 1.);
  float y = uv.y + shift * (1. - stretch * .5 * (1. - k) * min(p * 8., 1.));
  vec3 a = getFromColor(vec2(uv.x, y)).rgb;
  if (y > 1.) a = b;
  // ④ 圆头高光（颜料前端）
  a += rim * smoothstep(.012, 0., top - uv.y) * .4;
  return vec4(a, 1.);
}
