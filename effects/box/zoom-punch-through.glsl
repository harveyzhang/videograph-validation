/*@effect
{
  "id": "zoom-punch-through",
  "name": "冲焦穿越转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["zoom through", "punch in", "radial blur", "speed", "impact", "推进穿越", "冲进", "径向模糊", "冲击转场"],
  "summary": "镜头猛地冲进上一个画面的中心（急速放大 + 径向模糊），在最快的一瞬间换成下一个镜头，下一个镜头从放大状态“砸”回正常大小并带一圈冲击余震。",
  "when": "动作与运动、电子乐 drop、能量爆发、开场冲刺、段落之间的强力衔接。",
  "avoid": "慢节奏；对眩晕敏感的观众。时长建议 0.4–0.8 秒。",
  "params": {
    "zoom": { "type": "float", "default": 3, "min": 1.2, "max": 8, "label": "最大放大倍数" },
    "blur": { "type": "float", "default": 0.18, "min": 0, "max": 0.4, "label": "径向模糊强度" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "冲入点 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "冲入点 Y" },
    "flash": { "type": "float", "default": 0.25, "min": 0, "max": 0.6, "label": "切换瞬间的闪光" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：冲焦转场", "note": "按思路自写；与 gl-transitions 的 CrossZoom 不同：这里是“冲进旧画面 → 新画面从放大砸回”的两段式，带余震" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（剪辑师的“zoom transition”）：前一个镜头结尾做一个急速推近（带径向模糊），下一个镜头开头做一个急速拉回，
// 在两者都最模糊的那一帧接上——观众感觉镜头一路冲进了下一个场景。

vec4 transition(vec2 uv) {
  vec2 c = vec2(centerX, centerY);
  float p = progress;
  bool second = p > .5;
  // ① 缩放曲线：前半 1 → zoom（加速），后半 zoom → 1（减速，带一点过冲回弹 = 余震）
  float t = second ? (p - .5) * 2. : p * 2.;
  float z = second ? mix(zoom, 1., 1. - pow(1. - t, 3.)) * (1. - .04 * sin(t * 9.42) * (1. - t)) : mix(1., zoom, t * t * t);
  float speed = second ? (1. - t) : t;
  // ② 径向模糊：从冲入点沿径向 12 次采样
  vec2 d = uv - c;
  vec3 acc = vec3(0.);
  for (int i = 0; i < 12; i++) {
    float s = 1. - blur * speed * float(i) / 11.;
    vec2 q = c + d * s / z;
    acc += second ? getToColor(q).rgb : getFromColor(q).rgb;
  }
  vec3 col = acc / 12.;
  // ③ 切换瞬间的闪光（只在中点附近 ±8%，局部亮度提升，不是整屏白闪）
  col += flash * exp(-pow((p - .5) / .06, 2.)) * (1. - length(d));
  return vec4(col, 1.);
}
