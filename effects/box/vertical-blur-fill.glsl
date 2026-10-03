/*@effect
{
  "id": "vertical-blur-fill",
  "name": "竖屏模糊填充",
  "kind": "post",
  "category": "画面版式",
  "tags": ["vertical video", "9:16", "blur fill", "background fill", "social", "竖屏", "模糊背景", "填充", "短视频"],
  "summary": "把画面中间裁成一块竖屏（默认 9:16）清晰显示，两侧空白用同一画面放大、模糊、压暗后的版本填满，竖屏边缘带柔和投影；鼓点时竖屏轻轻放大一下。",
  "when": "把竖屏素材放进横屏成片、社媒截图/直播片段、强调画面中心的人物或手机内容。",
  "avoid": "画面中心不是主体时（调 centerX）；本来就需要横向全景的镜头。",
  "params": {
    "aspect": { "type": "float", "default": 0.5625, "min": 0.3, "max": 1.2, "label": "中间画幅比（宽/高，9:16 = 0.5625）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "裁取位置 X" },
    "blur": { "type": "float", "default": 0.03, "min": 0, "max": 0.08, "label": "背景模糊" },
    "dim": { "type": "float", "default": 0.45, "min": 0, "max": 0.9, "label": "背景压暗" },
    "pop": { "type": "float", "default": 0, "min": 0, "max": 0.06, "label": "鼓点放大（通常由节拍驱动）" }
  },
  "bindings": { "pop": { "to": "kick", "amount": 0.02 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：竖屏适配", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（短视频剪辑的常规做法）：竖屏素材放进横屏时，左右会有两大块空白；剪辑师把同一素材放大铺满作底、
// 加重模糊压暗，再把原素材居中放在上面——空白被“相关”的颜色填满，又不抢主体。

vec4 effect(vec2 uv) {
  float frameA = uRes.x / uRes.y;
  float w = aspect / frameA * (1. + pop);                   // 中间竖屏占画面宽度的比例
  float h = 1. + pop;
  vec2 lo = vec2(.5 - w * .5, .5 - h * .5);
  vec2 local = (uv - lo) / vec2(w, h);
  // 中间竖屏对应原画面的区域：以 centerX 为中心、宽 = aspect/frameA 的竖条
  float srcW = aspect / frameA;
  // ① 背景：放大到铺满（只取中间竖条放大）、8 次环形采样模糊、压暗
  vec2 bq = vec2(centerX + (uv.x - .5) * srcW, .5 + (uv.y - .5) * srcW);   // 中间竖条等比放大到铺满画面宽
  vec3 bg = vec3(0.);
  for (int i = 0; i < 8; i++) {
    float a = float(i) * .7854;
    bg += srcTex(bq + vec2(cos(a), sin(a)) * blur * vec2(uRes.y / uRes.x, 1.)).rgb;
  }
  bg = bg / 8. * (1. - dim);
  // ② 投影：竖屏边缘外侧一圈柔和暗影
  vec2 dd = max(max(-local, local - 1.), 0.) * vec2(w * frameA, h);
  float sh = exp(-length(dd) * 30.);
  bg *= 1. - .5 * sh * step(.0001, length(dd));
  // ③ 前景竖屏：清晰的原画面中间竖条
  float inside = step(0., local.x) * step(local.x, 1.) * step(0., local.y) * step(local.y, 1.);
  vec3 fg = srcTex(vec2(centerX + (local.x - .5) * srcW, local.y)).rgb;
  return vec4(mix(bg, fg, inside), 1.);
}
