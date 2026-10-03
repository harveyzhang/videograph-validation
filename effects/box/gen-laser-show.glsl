/*@effect
{
  "id": "gen-laser-show",
  "name": "激光秀",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["laser", "rave", "edm", "beams", "festival", "激光", "电音节", "光束", "锐舞"],
  "summary": "从画面底部中心射出一扇细而锐利的彩色激光束，光束整体扇动、在每拍切换扇形图案（散开/收拢/交叉），光束沿线有颗粒闪烁；鼓点时激光更亮。",
  "when": "电子乐/电音节/锐舞、夜店、游戏与科幻、副歌 drop。",
  "avoid": "安静抒情段落；对强光敏感的观众（激光很细，整体亮度变化小，但仍建议控制 intensity）。",
  "params": {
    "beams": { "type": "float", "default": 9, "min": 2, "max": 24, "label": "光束数" },
    "fan": { "type": "float", "default": 1.1, "min": 0.1, "max": 3, "label": "扇形张角（弧度）" },
    "intensity": { "type": "float", "default": 0.7, "min": 0, "max": 2, "label": "亮度（通常由节拍驱动）" },
    "originY": { "type": "float", "default": -0.05, "min": -0.3, "max": 1.3, "label": "发射点 Y" },
    "colorA": { "type": "color", "default": "#3dff6e", "label": "激光色 A" },
    "colorB": { "type": "color", "default": "#ff2a6d", "label": "激光色 B" }
  },
  "bindings": { "intensity": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：舞台灯光", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：激光秀的激光束极细、亮度极高、颜色纯；在烟雾里能看到整条光路。振镜让光束快速扇动，
// 灯光师按节拍切换图案（扇形展开、收拢、交叉扫动）。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 O = vec2(.5 * asp.x, originY);
  vec2 d = uv * asp - O;
  float r = length(d);
  float a = atan(d.x, d.y);                               // 0 = 正上方
  // ① 每拍一个图案：拍号决定 散开 / 收拢 / 交叉摆动（拍内平滑过渡）
  float beatN = floor(uTime * 2.);
  float pat = mod(beatN, 3.);
  float spreadNow = pat < .5 ? fan : pat < 1.5 ? fan * .35 : fan * .8;
  float swing = pat > 1.5 ? sin(uTime * 6.) * .4 : sin(uTime * 1.3) * .15;
  float n = floor(beams + .5);
  vec3 light = vec3(0.);
  float px = 1. / uRes.y;
  for (int i = 0; i < 24; i++) {
    float fi = float(i);
    if (fi >= n) break;
    float ba = (fi / max(n - 1., 1.) - .5) * spreadNow + swing * (pat > 1.5 && mod(fi, 2.) < 1. ? -1. : 1.);
    // ② 光束：与光束方向的角距离换算成像素宽度（远处略粗，像在烟里扩散）
    float da = abs(a - ba) * r;
    float w = px * 1.4 + r * .002;
    float beam = smoothstep(w * 2., 0., da) + exp(-da / (w * 6.)) * .25;
    // ③ 沿光路的颗粒闪烁（烟雾）
    float grain = .6 + .4 * fxNoise(vec2(r * 60. - uTime * 3., fi));
    light += mix(colorA, colorB, mod(fi, 2.)) * beam * grain * exp(-r * .4);
  }
  // ④ 发射点的亮团
  light += mix(colorA, colorB, .5) * exp(-r * 25.) * .8;
  vec3 c = 1. - (1. - src * .9) * (1. - clamp(light * intensity, 0., 1.));
  return vec4(c, 1.);
}
