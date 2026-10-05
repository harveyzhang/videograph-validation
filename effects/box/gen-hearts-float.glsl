/*@effect
{
  "id": "gen-hearts-float",
  "name": "爱心飘升",
  "kind": "post",
  "category": "生成层",
  "tags": ["hearts", "love", "valentine", "float", "live stream", "爱心", "点赞", "情人节", "飘升"],
  "summary": "一颗颗粉红色的小爱心从画面右下角冒出、一边左右摇摆一边往上飘，越飘越大越淡（像直播间的点赞特效）；每个鼓点冒出一串新的爱心。",
  "when": "情人节/告白/婚礼、直播与社交媒体风格、可爱与少女感、点赞与好评的意象。",
  "avoid": "严肃题材；画面右下角有重要内容时（调 originX）。",
  "params": {
    "originX": { "type": "float", "default": 0.85, "min": 0, "max": 1, "label": "冒出位置 X" },
    "rate": { "type": "float", "default": 6, "min": 1, "max": 12, "label": "每秒冒出个数" },
    "size": { "type": "float", "default": 0.045, "min": 0.01, "max": 0.08, "label": "爱心大小（画面高度比例）" },
    "colorA": { "type": "color", "default": "#ff4d8d", "label": "颜色 A" },
    "colorB": { "type": "color", "default": "#ff9fc8", "label": "颜色 B" },
    "burst": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点一串（通常由节拍驱动）" }
  },
  "bindings": { "burst": { "to": "kick", "amount": 0.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：直播点赞", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（直播间点赞动画）：每点一下，就有一颗爱心从按钮处冒出，沿着随机的 S 形曲线往上飘、逐渐放大并淡出。
// 实现：按时间均匀“发射”，第 i 颗爱心的诞生时刻 = i / rate；每颗的轨迹是诞生后时间的函数（无帧间状态）。

// 心形距离场：两个圆 + 一个旋转 45° 的正方形（尖朝下），单位大小约 1
float heart(vec2 p) {
  p.y += .25;
  vec2 q = fxRot(.785) * p;
  float sq = max(abs(q.x), abs(q.y)) - .42;
  float c1 = length(p - vec2(-.3, .3)) - .42, c2 = length(p - vec2(.3, .3)) - .42;
  return min(sq, min(c1, c2));
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp;
  vec3 c = src;
  float life = 2.5;                                        // 每颗爱心飘 2.5 秒
  float n0 = floor(uTime * rate);
  // ① 最近 life×rate 颗爱心（上限 30）
  for (int k = 0; k < 30; k++) {
    float idx = n0 - float(k);
    float age = (uTime - idx / rate) / life;
    if (age < 0. || age > 1.) continue;
    float h = fxHash(vec2(idx, 3.));
    // 鼓点时额外显示：用 burst 控制这一颗是否“加大”
    // ② 轨迹：从起点往上飘，S 形摇摆，略微向左散开
    vec2 start = vec2(originX + (h - .5) * .05, .08) * asp;
    vec2 pos = start + vec2(sin(age * 6. + h * 10.) * .04 - age * (.1 + h * .15), age * .75);
    float s = size * (.6 + age * .8) * (1. + burst * .5 * step(.5, h));
    vec2 d = (p - pos) / s;
    d = fxRot(sin(age * 5. + h * 3.) * .3) * d;
    float m = smoothstep(.06, -.06, heart(d));
    float fade = smoothstep(1., .6, age) * smoothstep(0., .06, age);
    vec3 col = mix(colorA, colorB, h);
    col += smoothstep(.2, .0, length(d - vec2(-.15, .15))) * .4;   // 小高光
    c = mix(c, col, m * fade);
  }
  return vec4(c, 1.);
}
