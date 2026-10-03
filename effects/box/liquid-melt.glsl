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
    "stretch": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "流淌拉伸" },
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
  // ① 每道滴痕的速度：按列取噪声（相邻列平滑相关），并加上细小的随机抖动
  float x = uv.x * drips;
  float sp = .6 + .8 * fxNoise(vec2(x * .5, 3.)) + .25 * fxHash(vec2(floor(x), 7.));
  // 列边缘做成圆弧状（滴痕前端是圆的）
  float colShape = .04 * (1. - cos(fract(x) * 6.2832)) * .5;
  float front = 1. - p * sp * 1.6 + colShape;             // 颜料下沿（从 1 往下流到 < 0）
  if (uv.y < front) {
    // ② 下沿以下：露出新镜头（前端附近有一道湿亮边）
    float edge = smoothstep(.02, 0., front - uv.y);
    return vec4(b + rim * edge * .35, 1.);
  }
  // ③ 下沿以上：旧画面被向下拉长（离下沿越近拉伸越大）
  float k = (uv.y - front) / max(1. - front, .001);
  float y = mix(front + (1. - front) * pow(k, 1. + stretch * 2.), uv.y, 1. - p);
  vec3 a = getFromColor(vec2(uv.x, mix(uv.y, y, min(p * 3., 1.)))).rgb;
  // 前端圆头的高光
  a += rim * smoothstep(.015, 0., uv.y - front) * .4;
  return vec4(a, 1.);
}
