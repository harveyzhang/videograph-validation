/*@effect
{
  "id": "gen-countdown-ring",
  "name": "倒计时圆环",
  "kind": "post",
  "category": "画面版式",
  "tags": ["countdown", "progress ring", "timer", "loading", "circle", "倒计时", "进度环", "计时器", "加载"],
  "summary": "画面中央（或角落）叠一个圆形进度环：环按镜头进度（或歌曲小节）逐渐填满，环上有刻度与发光的前端，中心是一个随拍跳动的圆点；可作为倒计时、加载、读条。",
  "when": "倒计时/开场前/抽奖、加载与进度的意象、游戏与直播界面、“时间到”的悬念。",
  "avoid": "需要显示具体数字时（与 segment-counter 搭配叠用）。",
  "params": {
    "mode": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "进度来源：0 镜头进度 / 1 每小节循环" },
    "reverse": { "type": "bool", "default": true, "label": "倒计时（环逐渐减少）" },
    "radius": { "type": "float", "default": 0.18, "min": 0.04, "max": 0.45, "label": "半径（画面高度比例）" },
    "thick": { "type": "float", "default": 0.018, "min": 0.004, "max": 0.06, "label": "环宽" },
    "posX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "posY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y" },
    "color": { "type": "color", "default": "#ff4d12", "label": "颜色" },
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "中心点跳动（通常由节拍驱动）" }
  },
  "bindings": { "pulse": { "to": "kick", "amount": 0.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：界面进度元素", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（界面设计的“进度环”）：一个圆环从 12 点方向开始顺时针填充，表示完成了多少；倒计时则相反，环逐渐消失。
// 环的前端常有一个发光的点，中心可以放数字或图标，这里放一个随拍跳动的圆点。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 d = (uv - vec2(posX, posY)) * vec2(uRes.x / uRes.y, 1.);
  float r = length(d);
  // ① 进度
  float prog = mode < .5 ? clamp(uProgress, 0., 1.) : uBar;
  if (reverse) prog = 1. - prog;
  // ② 角度：12 点方向为 0，顺时针增加（0..1）
  float a = fract(atan(d.x, d.y) / 6.2832 + 1.);
  float ring = smoothstep(thick * .5 + .002, thick * .5, abs(r - radius));
  float filled = step(a, prog);
  // ③ 底环（暗）+ 已填充（亮）+ 前端发光点 + 刻度
  vec3 c = mix(src, src * .35 + color * .08, ring * (1. - filled) + smoothstep(radius + thick, radius - thick * 4., r) * .35);
  c = mix(c, color, ring * filled);
  vec2 tip = vec2(sin(prog * 6.2832), cos(prog * 6.2832)) * radius;
  c += color * exp(-length(d - tip) / (thick * .8)) * .8;
  float tick = step(abs(fract(a * 12. + .5) - .5), .015) * smoothstep(.004, 0., abs(r - radius - thick * 1.6) - thick * .4);
  c = mix(c, vec3(.9), tick * .6);
  // ④ 中心点：随鼓点跳动
  float dot_ = smoothstep(radius * .12 * (1. + pulse * .6) + .002, radius * .12 * (1. + pulse * .6), r);
  c = mix(c, color * (1. + pulse * .5), dot_);
  return vec4(c, 1.);
}
