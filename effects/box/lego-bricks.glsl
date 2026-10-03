/*@effect
{
  "id": "lego-bricks",
  "name": "积木拼砌",
  "kind": "post",
  "category": "几何与图形",
  "tags": ["bricks", "toy blocks", "studs", "pixel 3d", "plastic", "积木", "颗粒", "拼砌", "玩具"],
  "summary": "画面变成用塑料积木颗粒拼成的墙：每格是一块带圆形凸点的方块，颜色限制在一组玩具色里，凸点有高光和阴影；鼓点时一部分积木轻轻弹起。",
  "when": "儿童与玩具、游戏与像素风、可爱的品牌/节日、“搭建”与创造的意象。",
  "avoid": "需要细节的写实镜头；文字细小的画面。",
  "params": {
    "brick": { "type": "float", "default": 0.03, "min": 0.01, "max": 0.1, "label": "积木大小（画面高度比例）" },
    "toyPalette": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "玩具色化（0 = 原色）" },
    "stud": { "type": "float", "default": 0.32, "min": 0.15, "max": 0.45, "label": "凸点大小" },
    "pop": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点弹起（通常由节拍驱动）" }
  },
  "bindings": { "pop": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/brick-toy", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：积木马赛克用一种颜色一块的方形积木拼成画，每块顶上有圆柱形凸点；从正面打光，凸点上方亮、下方有一圈阴影，
// 积木的颜色是有限的几种鲜艳塑料色。

const int NPAL = 10;
vec3 toyColor(int i) {
  vec3 p[10] = vec3[10](vec3(.95, .95, .93), vec3(.08, .08, .1), vec3(.82, .1, .12), vec3(.05, .35, .75), vec3(.98, .8, .05),
    vec3(.12, .55, .2), vec3(.95, .5, .1), vec3(.55, .55, .58), vec3(.6, .35, .2), vec3(.45, .7, .95));
  return p[i];
}

vec4 effect(vec2 uv) {
  float bpx = brick * uRes.y;
  vec2 g = uv * uRes / bpx;
  vec2 id = floor(g), f = fract(g);
  // ① 积木颜色：格中心取色，映射到最近的玩具色
  vec3 col = srcTex((id + .5) * bpx / uRes).rgb;
  vec3 best = col; float bd = 1e3;
  for (int i = 0; i < NPAL; i++) { vec3 d = col - toyColor(i); float dd = dot(d, d); if (dd < bd) { bd = dd; best = toyColor(i); } }
  col = mix(col, best, toyPalette);
  // ② 弹起：鼓点时少数积木被“按”起（变亮 + 阴影边）
  float up = pop * step(.88, fxHash(id + floor(uTime * 2.)));
  // ③ 积木块：边缘一圈暗缝 + 上左亮边下右暗边（塑料的倒角）
  vec3 c = col * (1. + up * .25);
  float e = min(min(f.x, 1. - f.x), min(f.y, 1. - f.y));
  c *= mix(.55, 1., smoothstep(0., .06, e));
  c *= 1. + .12 * (smoothstep(.12, 0., 1. - f.y) - smoothstep(.12, 0., f.y)) - .06 * smoothstep(.12, 0., 1. - f.x);
  // ④ 凸点：圆柱顶面 + 下方阴影 + 左上高光
  vec2 sp = f - .5;
  float dS = length(sp);
  float shadow = smoothstep(stud + .06, stud, length(sp - vec2(.04, -.05))) * (1. - smoothstep(stud, stud - .02, dS));
  c *= 1. - shadow * .35;
  float top = smoothstep(stud, stud - .02, dS);
  c = mix(c, col * 1.08 * (1. + up * .25), top);
  c += top * smoothstep(.12, 0., length(sp - vec2(-.1, .1))) * .35;
  c *= 1. - top * smoothstep(stud - .06, stud, dS) * .25;              // 凸点边缘的一圈暗
  return vec4(c, 1.);
}
