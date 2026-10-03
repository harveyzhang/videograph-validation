/*@effect
{
  "id": "gen-orbit-rings",
  "name": "轨道粒子环",
  "kind": "post",
  "category": "生成层",
  "tags": ["orbit", "rings", "particles", "atom", "planet", "轨道", "粒子环", "原子", "星环"],
  "summary": "三条倾斜的椭圆轨道环绕画面中心，每条轨道上一串发光粒子沿轨道转动（近处大而亮、远处小而暗，带透视）；鼓点时粒子拖出更长的光尾。",
  "when": "科技/AI/科学主题、产品或 Logo 的环绕展示、宇宙与能量的意象、片头 Logo 演绎。",
  "avoid": "中心位置有人脸时（粒子会穿过脸，调 centerX/centerY）。",
  "params": {
    "radius": { "type": "float", "default": 0.32, "min": 0.1, "max": 0.6, "label": "轨道半径（画面高度比例）" },
    "count": { "type": "float", "default": 14, "min": 3, "max": 40, "label": "每环粒子数" },
    "speed": { "type": "float", "default": 0.35, "min": -2, "max": 2, "label": "转速" },
    "streak": { "type": "float", "default": 0.1, "min": 0, "max": 0.6, "label": "光尾（通常由节拍驱动）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y" },
    "color": { "type": "color", "default": "#7fd8ff", "label": "粒子颜色" }
  },
  "bindings": { "streak": { "to": "kick", "amount": 0.35 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：环绕粒子", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（原子模型/行星环的图形化）：几条圆形轨道各自倾斜一个角度，从斜前方看过去是椭圆；
// 粒子沿轨道转动时，转到前方（离观众近）显得大而亮，转到后方显得小而暗，形成立体感。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = (uv - vec2(centerX, centerY)) * asp;
  float light = 0., ringL = 0.;
  for (int k = 0; k < 3; k++) {
    float K = float(k);
    float tiltA = K * 1.047 + .3;                       // 每条轨道在画面内的朝向
    float flat_ = .28 + K * .08;                         // 椭圆扁率（倾斜程度）
    float R = radius * (1. + K * .12);
    // ① 轨道线：极淡的椭圆
    vec2 q = fxRot(-tiltA) * p;
    float e = length(q / vec2(R, R * flat_));
    ringL += smoothstep(.012, 0., abs(e - 1.) * R) * .25;
    // ② 粒子：沿轨道等距，整体旋转；前后深度由 sin 决定
    for (int i = 0; i < 40; i++) {
      float fi = float(i);
      if (fi >= count) break;
      float th = fi / count * 6.2832 + uTime * speed * (1. + K * .3) * (mod(K, 2.) < 1. ? 1. : -1.);
      vec2 pos = fxRot(tiltA) * vec2(cos(th) * R, sin(th) * R * flat_);
      float depth = .5 + .5 * sin(th);                   // 1 = 前方
      float sz = max(.005 + .007 * depth, 2. / uRes.y);
      // ③ 光尾：沿运动切线方向拉长（streak 挂鼓点）
      vec2 tang = fxRot(tiltA) * vec2(-sin(th), cos(th) * flat_);
      vec2 d = p - pos;
      float along = dot(d, normalize(tang)), across = dot(d, normalize(vec2(-tang.y, tang.x)));
      float tailLen = streak * R * .6;
      float tail = smoothstep(sz, 0., abs(across)) * step(-tailLen, along) * step(along, 0.) * (1. + along / max(tailLen, 1e-4));
      light += (smoothstep(sz, sz * .3, length(d)) + exp(-length(d) / (sz * 3.)) * .3 + tail * .6) * mix(.35, 1., depth);
    }
  }
  vec3 c = 1. - (1. - src) * (1. - clamp(color * (light + ringL), 0., 1.));
  return vec4(c, 1.);
}
