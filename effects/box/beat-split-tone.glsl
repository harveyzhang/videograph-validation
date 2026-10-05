/*@effect
{
  "id": "beat-split-tone",
  "name": "拍点冷暖跳色",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["split tone", "color jump", "beat", "warm cool", "grade switch", "冷暖", "跳色", "调色", "卡点"],
  "summary": "画面的调色在冷暖两套方案之间按拍切换：一拍偏青冷（阴影蓝、高光青），下一拍偏暖（阴影洋红、高光金），切换落在拍点上；强度随音乐能量变化。",
  "when": "流行/电子/时尚的快节奏段落、对比与矛盾的情绪、给普通画面加节奏感的调色变化。",
  "avoid": "需要稳定色彩的人像与产品镜头；慢节奏抒情。",
  "params": {
    "amount": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "强度（通常由音乐能量驱动）" },
    "perBeat": { "type": "float", "default": 1, "min": 0.25, "max": 4, "label": "每拍切换次数（1 = 每拍、0.5 = 每两拍）" }
  },
  "bindings": { "amount": { "to": "energy", "amount": 0.3 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：调色切换", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（分离色调 split toning）：给阴影和高光分别染上不同颜色——最常见的是阴影冷、高光暖（青橙）。
// 这里把两套相反的分离色调按拍交替，画面结构不变但“温度”随节拍跳动。亮度保持，所以不会造成整屏闪烁。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float l = fxLuma(src);
  // ① 本拍是冷还是暖（拍号奇偶，按 perBeat 缩放；用歌曲时间 120 BPM 网格对齐拍点）
  float idx = floor(uTime * 2. * perBeat);
  bool warm = mod(idx, 2.) < 1.;
  // ② 分离色调：阴影色与高光色按亮度混合，作为乘性色偏；再把亮度校正回原值
  vec3 sh = warm ? vec3(1.08, .9, 1.05) : vec3(.88, .97, 1.12);
  vec3 hi = warm ? vec3(1.1, 1.0, .82) : vec3(.9, 1.04, 1.08);
  vec3 tinted = src * mix(sh, hi, smoothstep(.2, .8, l));
  tinted *= l / max(fxLuma(tinted), 1e-3);
  return vec4(mix(src, clamp(tinted, 0., 1.), amount), 1.);
}
