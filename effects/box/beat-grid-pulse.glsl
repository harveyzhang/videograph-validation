/*@effect
{
  "id": "beat-grid-pulse",
  "name": "节拍网格脉冲",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["grid", "pulse", "beat", "tron", "dance floor", "网格", "节拍", "地板灯"],
  "summary": "画面上叠一张发光网格，每个鼓点从中心放出一圈方形波纹沿网格扩散，被波纹扫过的格子短暂亮起；平时网格安静呼吸。",
  "when": "电子舞曲、夜店、科技发布会开场、游戏与数据主题的卡点段落。",
  "avoid": "需要干净画面的镜头；抒情慢歌；画面已有很多直线结构（网格会冲突）。",
  "params": {
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 1.5, "label": "脉冲强度（通常由节拍驱动）" },
    "cells": { "type": "float", "default": 16, "min": 4, "max": 48, "label": "网格横向格数" },
    "color": { "type": "color", "default": "#36f0ff", "label": "网格颜色" },
    "lineAlpha": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "网格线亮度" }
  },
  "bindings": { "pulse": { "to": "kick", "amount": 1 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：网格/地板灯随拍点亮", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（舞台灯光）：迪斯科地板是一格格独立的灯箱，灯光师让一圈圈灯格随底鼓从中心向外点亮，形成“波纹”。
// 这里把它叠在画面上：网格线是灯箱的边框，波纹扫过的格子发光，然后熄灭。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float asp = uRes.x / uRes.y;

  // ① 灯箱网格：按画面高度归一化，格子是正方形。
  vec2 p = (uv - .5) * vec2(asp, 1.) * cells / asp;
  vec2 id = floor(p);
  vec2 f = fract(p);

  // ② 波纹：从中心出发的方形波（切比雪夫距离），波前位置由拍内相位决定（拍点时在中心，随后向外扩散）。
  //    pulse 挂鼓点：决定这一圈波纹的亮度，随衰减逐渐变暗。
  //    拍点那一刻中心 2 圈已经点亮（底鼓的冲击是瞬间的），随后波前向外推进。
  float ring = max(abs(id.x + .5), abs(id.y + .5));
  float front = 1. + uBeat * cells * .55;
  float hit = exp(-pow(max(ring - front, 0.) + max(front - 2. - ring, 0.) * .35, 2.) * .6) * pulse;

  // ③ 格子发光：被波纹扫到的格子整体亮起（格内中心最亮），每个格子亮度略有随机（灯泡新旧不一）。
  float cellGlow = hit * (.6 + .4 * fxHash(id)) * (1. - .5 * length(f - .5));

  // ④ 网格线：边框细线（约 1 像素），平时随小节缓慢呼吸。
  vec2 lw = fwidth(p) * 1.2;
  vec2 gd = min(f, 1. - f);
  float line = max(smoothstep(lw.x, 0., gd.x), smoothstep(lw.y, 0., gd.y));
  float breathe = .7 + .3 * cos(uBar * 6.2832);

  // ⑤ 合成：网格与格光以屏幕混合加到画面上（加光而非盖住）。
  vec3 light = color * (line * lineAlpha * breathe + line * hit * .9 + cellGlow * .45);
  vec3 col = 1. - (1. - src) * (1. - clamp(light, 0., 1.));
  return vec4(col, 1.);
}
