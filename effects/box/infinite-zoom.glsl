/*@effect
{
  "id": "infinite-zoom",
  "name": "无限递归推进",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["droste", "infinite zoom", "recursion", "tunnel", "frame in frame", "无限推进", "画中画递归", "德罗斯特", "隧道"],
  "summary": "画面里套着更小的自己，一层套一层（德罗斯特效应），镜头不停地向中心推进、永远推不到底；每层之间有一道细框，鼓点时细框亮起。",
  "when": "“无限循环”“深入内心”的意象、片头、迷幻与电子乐、屏幕里的屏幕。",
  "avoid": "需要正常观看的叙事镜头；画面中心没有内容（推进会显得空）。",
  "params": {
    "ratio": { "type": "float", "default": 0.5, "min": 0.25, "max": 0.8, "label": "每层缩小比例" },
    "speed": { "type": "float", "default": 0.25, "min": -2, "max": 2, "label": "推进速度（层/秒，负值为拉远）" },
    "frameWidth": { "type": "float", "default": 0.004, "min": 0, "max": 0.02, "label": "层间细框宽度" },
    "glow": { "type": "float", "default": 0.2, "min": 0, "max": 1.5, "label": "细框亮度（通常由节拍驱动）" },
    "frameColor": { "type": "color", "default": "#ff4d12", "label": "细框颜色" }
  },
  "bindings": { "glow": { "to": "kick", "amount": 0.9 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：递归与画中画", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：把一台摄像机对准正在显示它自己画面的屏幕，会得到一层套一层、越来越小的画面（视频反馈/德罗斯特效应）；
// 推近镜头时，每一层都长大成上一层，于是可以“无限推进”。
// 实现：用缩放的对数坐标——像素所在的层号 = floor(log(距离)/log(ratio))，把它放大回第 0 层再取样；推进 = 对数坐标随时间平移。

vec4 effect(vec2 uv) {
  vec2 p = uv - .5;
  // ① 方框“距离”：切比雪夫范数（画面的矩形边界 = 1）
  float d = max(abs(p.x), abs(p.y)) * 2.;
  // ② 推进：对数坐标平移 speed×时间，取小数部分 → 无缝循环
  float lr = log(ratio);
  float z = fract(uTime * speed);
  float lev = (log(max(d, 1e-4)) - z * lr) / lr;       // 连续层号（0 = 最外层）
  float n = floor(lev);
  // ③ 放大回最外层：乘以 ratio^(-n) 并补上推进量
  float s = pow(ratio, -n - z);
  vec2 q = p * s + .5;
  vec3 c = srcTex(q).rgb;
  // ④ 层间细框：在每层的边界附近画一条线（宽度换算到当前层的尺度），鼓点时亮起
  float qd = max(abs(q.x - .5), abs(q.y - .5)) * 2.;
  float line = smoothstep(1. - frameWidth * 2. * s - .002, 1., qd);
  c = mix(c, frameColor * (.6 + glow), clamp(line, 0., 1.) * (.5 + .5 * min(glow, 1.)));
  return vec4(c, 1.);
}
