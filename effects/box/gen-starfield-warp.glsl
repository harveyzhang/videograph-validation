/*@effect
{
  "id": "gen-starfield-warp",
  "name": "星空跃迁",
  "kind": "post",
  "category": "生成层",
  "tags": ["starfield", "warp", "hyperspace", "speed lines", "space", "星空", "跃迁", "超空间", "速度线"],
  "summary": "从画面中心向四周飞出的星光拉成速度线，像飞船进入超空间；平时是缓慢漂移的星点，鼓点时一下子拉长成光丝。原画面被推远、略微暗下去。",
  "when": "科幻、太空、开场冲刺、转折前的蓄力、“进入新世界”的段落；电子乐 drop 前后。",
  "avoid": "需要稳定观看的信息镜头；温柔抒情段落。",
  "params": {
    "speed": { "type": "float", "default": 0.3, "min": 0, "max": 3, "label": "飞行速度" },
    "stretch": { "type": "float", "default": 0.1, "min": 0, "max": 1.5, "label": "拉丝长度（通常由节拍驱动）" },
    "density": { "type": "float", "default": 0.5, "min": 0.05, "max": 1, "label": "星密度" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "消失点 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "消失点 Y" },
    "dim": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "原画面压暗" },
    "tint": { "type": "color", "default": "#cfe3ff", "label": "星光色" }
  },
  "bindings": { "stretch": { "to": "kick", "amount": 0.9 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：速度线/星空", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（电影里的超空间）：高速前进时，前方的星星向四周飞散，离视线中心越远飞得越快，
// 快门时间内的移动把星点拉成指向消失点的光丝。实现：在极坐标里把方向切成扇区、每个扇区一颗星，
// 星的“深度”随时间减小（越来越近），屏幕半径 = 1/深度；光丝长度 = 快门内半径的变化。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 d = (uv - vec2(centerX, centerY)) * asp;
  float r = length(d);
  float a = atan(d.y, d.x);
  float light = 0.;

  // ① 三层星：每层把方向切成 N 个扇区，每个扇区一颗星（概率 density），深度循环减小（飞近）。
  for (int L = 0; L < 3; L++) {
    float n = 90. + float(L) * 70.;
    float sec = floor((a / 6.2832 + .5) * n);
    float h = fxHash(vec2(sec, float(L) * 13.));
    if (h > density) continue;
    float secA = ((sec + .5) / n - .5) * 6.2832 + (fxHash(vec2(sec, 5.)) - .5) * 6.2832 / n * .6;
    float z = fract(fxHash(vec2(sec, float(L) + 2.)) - uTime * speed * (.15 + .1 * float(L)));   // 1 远 → 0 近
    z = max(z, .02);
    float rs = .06 / z;                                      // 星的屏幕半径
    // ② 光丝：从 rs 向外延伸 stretch 倍（越近越长）；stretch 挂鼓点——鼓点那一下全部拉成长丝。
    float len = rs * (.04 + stretch * .5) / max(z * 3., .2);
    float along = r - rs;
    float across = abs(sin(a - secA)) * r;
    float w = .0016 + .004 * (1. - z);
    float m = smoothstep(w, 0., across) * smoothstep(-.003, .0, along) * smoothstep(len + .002, 0., along);
    light += m * (1. - z) * 1.6;
  }

  // ③ 合成：原画面被推远一点（轻微缩小、压暗），星光加在上面。
  vec3 c = src * (1. - dim * .6);
  c = 1. - (1. - c) * (1. - clamp(tint * light, 0., 1.));
  return vec4(c, 1.);
}
