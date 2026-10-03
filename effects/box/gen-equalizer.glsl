/*@effect
{
  "id": "gen-equalizer",
  "name": "律动频谱条",
  "kind": "post",
  "category": "生成层",
  "tags": ["equalizer", "spectrum", "audio bars", "visualizer", "led meter", "频谱", "均衡器", "音乐可视化", "律动条"],
  "summary": "画面底部升起一排分段 LED 频谱条：低频条随鼓点猛跳、高频条细碎抖动，条顶有缓慢回落的峰值点；整体高度跟音乐能量走。",
  "when": "音乐人 PV、歌词视频、电台/播客、演出宣传、任何需要“看得见音乐”的镜头。",
  "avoid": "需要底部空间放字幕的镜头（可调 posY 上移或调低 height）；注意：条形是由节拍与能量驱动的装饰，不是逐频段的真实频谱分析。",
  "params": {
    "bars": { "type": "float", "default": 32, "min": 8, "max": 96, "label": "条数" },
    "height": { "type": "float", "default": 0.28, "min": 0.05, "max": 0.8, "label": "最大高度（画面比例）" },
    "posY": { "type": "float", "default": 0.04, "min": 0, "max": 0.8, "label": "底边位置" },
    "punch": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点冲击（通常由节拍驱动）" },
    "level": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "整体电平（通常由音乐能量驱动）" },
    "lowColor": { "type": "color", "default": "#3dff8a", "label": "低电平颜色" },
    "highColor": { "type": "color", "default": "#ff4d12", "label": "高电平颜色" }
  },
  "bindings": { "punch": { "to": "kick", "amount": 0.8 }, "level": { "to": "energy", "amount": 0.4 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：音频可视化", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（音响面板的频谱显示）：每根条对应一个频段，高度 = 该频段的响度；条由一格格 LED 组成，
// 低电平绿、高电平黄到红；顶部有“峰值保持”点，冲上去后慢慢掉下来。低频（左侧）跟着底鼓大起大落，高频细碎跳动。
// 宿主只提供节拍脉冲与整体能量，没有逐频段数据，所以这里用 鼓点 + 能量 + 每条自己的噪声 合成“像频谱”的运动。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float b = floor(uv.x * bars);
  float fx = fract(uv.x * bars);
  float k = b / max(bars - 1., 1.);                     // 0 低频 → 1 高频

  // ① 每根条的电平：低频吃鼓点（punch 挂 kick），高频吃快速噪声；整体乘音乐能量（level 挂 energy）。
  float n = fxNoise(vec2(b * .7, uTime * (2. + k * 9.)));
  float lowPart = punch * (1. - k) * (1. - k);
  float v = clamp((n * .55 + .15) * (.4 + level) * mix(1., .75, k) + lowPart * .8, 0., 1.);

  // ② 峰值保持点：取“稍早时刻”的电平与当前的较大者，再随时间回落（近似峰值保持）。
  float vPrev = clamp((fxNoise(vec2(b * .7, (uTime - .25) * (2. + k * 9.))) * .55 + .15) * (.4 + level) * mix(1., .75, k), 0., 1.);
  float peak = max(v, vPrev - .08);

  // ③ LED 分段：每根条分成 16 格，格间留缝；条间留缝。
  float y = (uv.y - posY) / height;
  float seg = floor(y * 16.);
  float inBar = step(.15, fx) * step(fx, .85) * step(0., y) * step(y, 1.);
  float inSeg = step(.18, fract(y * 16.));
  float lit = step(seg + 1., v * 16. + .5);
  float peakLit = step(abs(seg - floor(peak * 16.)), .5);
  vec3 led = mix(lowColor, highColor, smoothstep(.45, .95, (seg + .5) / 16.));

  // ④ 合成：未点亮的格淡淡可见（面板），点亮的格发光，峰值点白色；条带区域底下压暗一点。
  float panel = inBar * inSeg;
  vec3 c = mix(src, src * .5, step(0., y) * step(y, 1.) * .35);
  c = mix(c, led * .12, panel * (1. - lit) * .6);
  c = mix(c, led * 1.15, panel * lit);
  c = mix(c, vec3(1.), panel * peakLit * (1. - lit) * .9);
  return vec4(c, 1.);
}
