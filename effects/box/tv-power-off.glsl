/*@effect
{
  "id": "tv-power-off",
  "name": "显像管关机转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["crt off", "tv shutdown", "retro", "collapse", "scanline", "关机", "老电视", "显像管", "复古转场"],
  "summary": "旧镜头像老式显像管电视关机一样，先被竖向压成一条发白的横线、再缩成中心一个亮点熄灭；然后反过来，亮点展开成线、线张开成下一个镜头（开机）。",
  "when": "复古/80–90 年代、电视与频道题材、段落之间的“关机重启”、喜剧与怀旧。",
  "avoid": "现代简约的风格。时长建议 0.6–1 秒。",
  "params": {
    "glow": { "type": "float", "default": 0.8, "min": 0, "max": 1.5, "label": "亮线/亮点强度" },
    "tint": { "type": "color", "default": "#e8f4ff", "label": "荧光色" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：复古电视转场", "note": "按思路自写；gl-transitions 无同类关机/开机转场" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：显像管电视关机时，垂直偏转先断电，电子束只在一条水平线上扫——画面被压成一条很亮的横线；
// 接着水平偏转也断电，线缩成中心一个亮点，荧光余辉让亮点慢慢熄灭。开机时过程相反。

vec4 transition(vec2 uv) {
  float p = progress;
  bool second = p > .5;
  float t = second ? 1. - (p - .5) * 2. : p * 2.;          // 0 → 1：从正常画面到完全熄灭（开机时倒放）
  // ① 两段：0–0.6 竖向压扁成线；0.6–1 横向缩成点
  float sy = 1. - smoothstep(0., .6, t) * .995;
  float sx = 1. - smoothstep(.6, 1., t) * .995;
  vec2 q = (uv - .5) / vec2(sx, sy) + .5;
  vec3 c = vec3(0.);
  if (q.x >= 0. && q.x <= 1. && q.y >= 0. && q.y <= 1.) c = second ? getToColor(q).rgb : getFromColor(q).rgb;
  // ② 被压扁的画面越来越亮、发白（能量集中在一条线上）
  //    只有画面仍在的那条带发白，带外保持黑（不是整屏白闪）
  float squash = smoothstep(.2, .6, t);
  float inBand = step(0., q.x) * step(q.x, 1.) * step(0., q.y) * step(q.y, 1.);
  c = mix(c, tint, squash * .6 * inBand) * (1. + squash * glow * .6);
  // ③ 中心亮点与余辉
  vec2 d = (uv - .5) * vec2(ratio, 1.);
  float dotL = exp(-length(d) * 60.) * smoothstep(.6, .9, t) * (1. - smoothstep(.95, 1., t) * .7);
  c += tint * dotL * glow * 2.;
  return vec4(c, 1.);
}
