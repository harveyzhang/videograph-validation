/*@effect
{
  "id": "whip-pan",
  "name": "甩镜转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["whip pan", "swish pan", "motion blur", "fast cut", "speed", "甩镜", "快速摇镜", "动态模糊", "转场"],
  "summary": "镜头猛地横甩：上一镜头带着强烈的横向动态模糊飞出画面，下一镜头带着同方向的模糊冲进来并“刹住”；中段两者都糊成光丝，像摄影师快速摇镜接上了下一个场景。",
  "when": "快节奏剪辑、vlog 与旅行、动作与运动、喜剧节奏、同一段音乐里的场景跳切。",
  "avoid": "慢节奏抒情；对眩晕敏感的观众（时长建议 0.3–0.6 秒）。",
  "params": {
    "blur": { "type": "float", "default": 0.12, "min": 0, "max": 0.3, "label": "最大模糊长度" },
    "travel": { "type": "float", "default": 1, "min": 0.3, "max": 2, "label": "位移距离（画面宽度）" },
    "angle": { "type": "float", "default": 0, "min": -1.5708, "max": 1.5708, "label": "甩动方向（弧度，0 = 向左甩）" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：甩镜转场", "note": "按思路自写；与 gl-transitions 的 Directional/directionalwarp 不同：这里有对称的速度曲线与沿运动方向的多重采样动态模糊" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：摄影师在一个镜头结尾猛地摇动摄像机，画面在快门时间内划过一大段距离，糊成一片横向光丝；
// 剪辑师在模糊最严重的那几帧接上下一个镜头（下一个镜头开头也是同方向的甩动），观众感觉不到切点。
// 节拍：转场由进度驱动，不挂节拍（bindings 为空）。

vec4 transition(vec2 uv) {
  // ① 速度曲线：中间最快（sin），位移为速度的积分（smoothstep）；进度 0.5 处切换镜头
  float p = progress;
  float speed = sin(p * 3.1416);
  vec2 dir = vec2(cos(angle), sin(angle));
  float shift = (p * p * (3. - 2. * p)) * travel;
  // 前半：旧镜头向 dir 方向飞出；后半：新镜头从反方向飞入并刹住
  bool useTo = p > .5;
  vec2 off = useTo ? dir * (shift - travel) : dir * shift;
  // ② 动态模糊：沿运动方向 12 次采样平均，长度随速度
  float L = blur * speed;
  vec3 acc = vec3(0.);
  for (int i = 0; i < 12; i++) {
    float t = float(i) / 11. - .5;
    vec2 q = fract(uv + off + dir * L * t);              // 甩动中画面平铺，不露黑边
    acc += useTo ? getToColor(q).rgb : getFromColor(q).rgb;
  }
  vec3 c = acc / 12.;
  // ③ 切点附近轻微提亮（模糊的光丝把亮部拉开）
  c *= 1. + speed * .08;
  return vec4(c, 1.);
}
