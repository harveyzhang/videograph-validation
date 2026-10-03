/*@effect
{
  "id": "swirl-twist",
  "name": "漩涡扭转",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["swirl", "twist", "vortex", "warp", "psychedelic", "漩涡", "扭转", "旋转扭曲", "迷幻"],
  "summary": "以画面中心为圆心把画面拧成漩涡：中心转得最多、边缘不动；平时缓慢地来回拧，鼓点时猛拧一下再松开。",
  "when": "迷幻/电子乐、眩晕与失控的情绪、梦境入口、催眠与魔法。",
  "avoid": "需要稳定观看的镜头；对眩晕敏感的观众（把 base 设为 0，只在鼓点拧）。",
  "params": {
    "radius": { "type": "float", "default": 0.45, "min": 0.1, "max": 1.2, "label": "漩涡半径（画面高度比例）" },
    "base": { "type": "float", "default": 0.6, "min": 0, "max": 4, "label": "常驻扭转（弧度）" },
    "twist": { "type": "float", "default": 0, "min": 0, "max": 6, "label": "鼓点扭转（通常由节拍驱动）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y" }
  },
  "bindings": { "twist": { "to": "kick", "amount": 1.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：扭曲冲击", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：像搅动一杯液体——中心旋转得最快、离中心越远越慢，到杯壁不动；画面上的图案被拉成螺旋。
// 实现：每个像素按到中心的距离计算一个旋转角（中心最大、半径处为 0，用平滑曲线过渡），再按这个角度反向转回去取样。

vec4 effect(vec2 uv) {
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 c = vec2(centerX, centerY);
  vec2 p = (uv - c) * asp;
  float r = length(p);
  // ① 扭转量：常驻部分随时间缓慢来回（sin），叠加鼓点冲击（twist 挂 kick）
  float amt = base * sin(uTime * .7) + twist;
  // ② 距离衰减：中心最大，到半径处平滑归零（三次曲线，边界无折痕）
  float k = smoothstep(radius, 0., r);
  float ang = amt * k * k;
  // ③ 反向旋转取样
  p = fxRot(ang) * p;
  return vec4(srcTex(p / asp + c).rgb, 1.);
}
