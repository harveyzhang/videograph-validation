/*@effect
{
  "id": "gen-meteor-shower",
  "name": "流星雨",
  "kind": "post",
  "category": "生成层",
  "tags": ["meteor", "shooting stars", "night sky", "wish", "streak", "流星", "流星雨", "夜空", "许愿"],
  "summary": "夜空里一颗颗流星斜着划过：明亮的头部拖着渐细渐淡的长尾，出现位置和时间随机，偶尔有一颗特别亮的火流星；每个鼓点多划过一颗。",
  "when": "浪漫/许愿/青春、夜景与星空、梦想与远方、抒情副歌。",
  "avoid": "白天画面；画面上部有重要内容时。",
  "params": {
    "rate": { "type": "float", "default": 4, "min": 0.3, "max": 10, "label": "每秒流星数" },
    "angle": { "type": "float", "default": -0.6, "min": -1.5, "max": 1.5, "label": "划落方向（弧度）" },
    "tail": { "type": "float", "default": 0.25, "min": 0.05, "max": 0.6, "label": "尾巴长度" },
    "color": { "type": "color", "default": "#e6f2ff", "label": "颜色" },
    "extra": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点加亮（通常由节拍驱动）" }
  },
  "bindings": { "extra": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：夜空粒子", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：流星是太空碎屑高速冲进大气层燃烧，头部最亮，后面拖着电离的发光尾迹；整个过程不到一秒；
// 流星雨时所有流星都从天上同一个方向（辐射点）射来，所以划过的方向大致平行。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp;
  vec2 dir = vec2(cos(angle), sin(angle));
  float light = 0.;
  float n0 = floor(uTime * rate);
  // ① 最近 12 颗流星：每颗在诞生时刻随机位置出现，0.7 秒内划过
  for (int k = 0; k < 12; k++) {
    float idx = n0 - float(k);
    float age = (uTime - idx / rate) / 1.1;
    if (age < 0. || age > 1.) continue;
    float h = fxHash(vec2(idx, 1.));
    vec2 start = vec2(fxHash(vec2(idx, 2.)) * asp.x * 1.2 - .1, .55 + .45 * fxHash(vec2(idx, 3.)));
    float bright = step(.92, h) * 1.5 + .6;                 // 少数火流星特别亮
    vec2 head = start + dir * age * .9;
    // ② 尾迹：沿 -dir 方向的线段，越远越淡越细
    vec2 d = p - head;
    float along = -dot(d, dir);
    float across = abs(dot(d, vec2(-dir.y, dir.x)));
    float L = tail * (.6 + h * .6);
    float t = clamp(along / L, 0., 1.);
    float w = (2.5 / uRes.y + .003 * bright) * (1. - t * .7);
    float streak = smoothstep(w, 0., across) * step(0., along) * step(along, L) * (1. - t) * (1. - t);
    float headGlow = exp(-length(d) * 60. / bright);
    float life = smoothstep(0., .1, age) * smoothstep(1., .7, age);
    light += (streak + headGlow) * life * bright * (1. + extra);
  }
  vec3 c = 1. - (1. - src) * (1. - clamp(color * light, 0., 1.));
  return vec4(c, 1.);
}
