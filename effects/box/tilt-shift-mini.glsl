/*@effect
{
  "id": "tilt-shift-mini",
  "name": "移轴微缩",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["tilt shift", "miniature", "toy", "diorama", "selective focus", "移轴", "微缩模型", "玩具感", "小人国"],
  "summary": "画面中间一条水平带保持清晰，上下逐渐变虚（移轴镜头的浅景深），同时提高饱和度与反差——真实城市/人群看起来像桌上的微缩模型；清晰带随拍缓慢上下呼吸。",
  "when": "俯拍的城市/街道/人群/车流、旅行 vlog、可爱的“小人国”感、延时摄影。",
  "avoid": "平视的人物特写（失去模型感，只剩模糊）；画面上下有字幕时。",
  "params": {
    "focusY": { "type": "float", "default": 0.45, "min": 0, "max": 1, "label": "清晰带位置（从下往上）" },
    "band": { "type": "float", "default": 0.12, "min": 0.02, "max": 0.4, "label": "清晰带半宽" },
    "blur": { "type": "float", "default": 0.012, "min": 0, "max": 0.04, "label": "最大模糊" },
    "saturation": { "type": "float", "default": 1.35, "min": 1, "max": 2, "label": "饱和度提升" },
    "drift": { "type": "float", "default": 0, "min": 0, "max": 0.1, "label": "清晰带呼吸（通常由小节驱动）" }
  },
  "bindings": { "drift": { "to": "bar", "amount": 0.03 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/tilt-shift", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：拍微缩模型时相机离物体很近，景深极浅——只有一条很窄的距离是清楚的；人脑习惯了“浅景深 = 小物体”。
// 移轴镜头把清晰平面倾斜，在拍大场景时也能做出这种窄条清晰带，城市就像模型；再加饱和与反差，像塑料玩具的颜色。

vec4 effect(vec2 uv) {
  // ① 模糊量：离清晰带越远越虚（drift 挂小节：清晰带每小节轻轻移动）
  float fy = focusY + drift * sin(uBar * 6.2832);
  float dist = max(abs(uv.y - fy) - band, 0.);
  float r = blur * smoothstep(0., .35, dist);
  // ② 盘形模糊：黄金角 12 次采样
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  float rot = fxHash(floor(uv * uRes)) * 6.2832;
  vec3 acc = vec3(0.);
  for (int i = 0; i < 12; i++) {
    float a = float(i) * 2.39996 + rot;
    acc += srcTex(uv + vec2(cos(a), sin(a)) * r * sqrt((float(i) + .5) / 12.) * asp).rgb;
  }
  vec3 c = acc / 12.;
  // ③ 玩具色：提饱和 + 轻微 S 曲线反差
  float l = fxLuma(c);
  c = mix(vec3(l), c, saturation);
  c = mix(c, c * c * (3. - 2. * c), .35);
  return vec4(clamp(c, 0., 1.), 1.);
}
