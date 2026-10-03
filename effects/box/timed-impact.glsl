/*@effect
{
  "id": "timed-impact",
  "name": "定时冲击",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["impact", "notification", "pop", "haptic", "shake", "shockwave", "ui", "弹窗", "冲击", "震动", "实感"],
  "summary": "在指定的歌曲秒数触发一次“落地”冲击：画面短促震动、从冲击点扩散一圈折射波纹、RGB 色散与一团中心闪光，随后指数衰减回到原画面。",
  "when": "画面里某个元素“砸进来”的那一下：手机弹窗/通知出现、按钮按下、Logo 或标题落版、产品落桌；无鼓点的安静段落也能精确对准某一帧。",
  "avoid": "需要连续卡点的段落（用 kick-ripple / beat-shake）；同一镜头里多次冲击（只支持一个时间点，多处冲击请拆镜头）。",
  "params": {
    "atTime": { "type": "float", "default": 0.85, "min": 0, "max": 3600, "label": "触发时间（歌曲秒）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "冲击点 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "冲击点 Y（0 = 画面底部）" },
    "shake": { "type": "float", "default": 0.012, "min": 0, "max": 0.04, "label": "震动幅度（画面高度比例）" },
    "ripple": { "type": "float", "default": 0.02, "min": 0, "max": 0.06, "label": "波纹折射强度" },
    "rgb": { "type": "float", "default": 0.006, "min": 0, "max": 0.02, "label": "RGB 色散" },
    "flash": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "中心闪光" },
    "tint": { "type": "color", "default": "#FFD58A", "label": "闪光颜色" },
    "decay": { "type": "float", "default": 4.5, "min": 1, "max": 12, "label": "衰减速度（越大越短促）" }
  },
  "bindings": { "ripple": { "to": "kick", "amount": 0 } },
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）。为《拾愿长安》落版弹窗的“实感”意见编写；节拍绑定默认 amount 0（本动效由 atTime 精确触发，需要时可再挂鼓点）。"
}
@effect*/

// 现实中：一个东西“砸”到屏幕上（手机通知震动、按钮按下），我们感受到的是：
//   ① 手持镜头被震了一下（短促、高频、迅速平息）；② 冲击点向外传出一圈压力波（折射扭曲 + 亮边）；
//   ③ 光学上的瞬间失焦与色散；④ 冲击点本身的一团光。四者同一时刻起跳、同一条指数包络衰减。
// 用 atTime（歌曲秒）而不是节拍触发：落版、弹窗这些时刻往往在安静段里，没有鼓点可挂。

vec4 effect(vec2 uv) {
  float dt = uTime - atTime;
  float on = step(0., dt);
  float env = on * exp(-max(dt, 0.) * decay);              // 冲击包络：瞬间起跳 + 指数衰减

  // ① 震动：高频确定性噪声（按 30fps 量化，避免子帧平均把震动抹掉），幅度随包络衰减
  float q = floor(max(dt, 0.) * 30.);
  vec2 jitter = vec2(fxHash(vec2(q, 1.7)) - .5, fxHash(vec2(q, 9.3)) - .5) * 2. * shake * env;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 C = vec2(centerX, centerY);
  vec2 p = uv + jitter / asp;

  // ② 冲击波：波前从冲击点以固定速度外扩，波形前推后收
  vec2 d = (p - C) * asp;
  float r = length(d);
  float front = .04 + max(dt, 0.) * 1.6;
  float x = (r - front) / .08;
  float wave = -sin(x * 3.1416) * exp(-x * x * 1.5) * on * exp(-max(dt, 0.) * decay * .6);
  float amp = ripple * wave / (1. + front * 2.);
  vec2 dir = d / max(r, 1e-4);
  vec2 offs = dir * amp / asp;

  // ③ 色散：沿径向分离三个通道，强度跟包络走
  vec2 ca = dir * rgb * env / asp;
  vec3 c;
  c.r = srcTex(p - offs - ca).r;
  c.g = srcTex(p - offs).g;
  c.b = srcTex(p - offs + ca).b;

  // ④ 中心闪光 + 波前亮边
  c += tint * flash * env * exp(-r * r * 9.);
  c += max(wave, 0.) * ripple * 8. * tint;
  return vec4(c, 1.);
}
