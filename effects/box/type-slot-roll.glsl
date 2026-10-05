/*@effect
{
  "id": "type-slot-roll",
  "name": "老虎机滚字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "slot machine", "roll", "odometer", "counter", "文字动画", "老虎机", "滚动", "里程表"],
  "summary": "文字按列像老虎机转轮一样竖向高速滚动（带运动模糊），从左到右依次“咔”地停在正确位置并轻微回弹；停住后每个鼓点有一列再转半圈。",
  "when": "抽奖/揭晓/数字公布、游戏与综艺、价格与倒计时、悬念揭示的标题。",
  "avoid": "文字压在复杂背景上（每列连背景一起滚）；严肃新闻字幕。",
  "params": {
    "columns": { "type": "float", "default": 10, "min": 2, "max": 40, "label": "列数（≈ 字数）" },
    "inEnd": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.9, "label": "全部停住于镜头进度" },
    "spins": { "type": "float", "default": 6, "min": 1, "max": 20, "label": "停前滚过的圈数" },
    "blur": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "滚动模糊" },
    "nudge": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点再转（通常由节拍驱动）" },
    "fill": { "type": "color", "default": "#0d0d0f", "label": "列缝底色" }
  },
  "bindings": { "nudge": { "to": "kick", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：数字滚动揭晓", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：老虎机的每个转轮把一圈符号贴在圆柱上，拉下拉杆后转轮高速旋转（看到的是竖向拖影），
// 再从左到右依次刹停——刹停时有一个小小的过冲回弹。这里把画面按列当作转轮，“一圈”就是画面的高度。

vec4 effect(vec2 uv) {
  float col = floor(uv.x * columns);
  float order = col / max(columns - 1., 1.);
  // ① 本列的停止时刻（左到右依次），转动角度 = 剩余圈数（减速曲线），停住后带回弹
  float stopT = mix(.35, 1., order) * inEnd;
  float t = clamp(uProgress / max(stopT, .001), 0., 1.);
  float remain = pow(1. - t, 2.5) * spins;                 // 剩下还要转的圈数（越来越慢）
  float bounce = t >= 1. ? sin(clamp((uProgress - stopT) / .04, 0., 1.) * 3.1416) * .03 * exp(-(uProgress - stopT) * 20.) : 0.;
  float re = nudge * step(.75, fxHash(vec2(col, floor(uTime * 2.)))) * .5;
  float off = remain + bounce + re;
  // ② 滚动模糊：速度越快越糊（竖向 6 次采样）
  float speed = clamp(2.5 * spins * pow(1. - t, 1.5) / max(stopT, .05) * .02, 0., .08) * blur + re * .04;
  vec3 c = vec3(0.);
  for (int i = 0; i < 6; i++) {
    float y = fract(uv.y + off + speed * (float(i) / 5. - .5));
    c += srcTex(vec2(uv.x, y)).rgb;
  }
  c /= 6.;
  // ③ 转轮的圆柱感：列的上下边缘变暗（曲面），列与列之间一条细缝
  c *= .65 + .35 * sin(uv.y * 3.1416);
  float fx = fract(uv.x * columns);
  float gap = step(fx, .03) + step(.97, fx);
  return vec4(mix(c, fill, min(gap, 1.)), 1.);
}
