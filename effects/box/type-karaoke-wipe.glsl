/*@effect
{
  "id": "type-karaoke-wipe",
  "name": "卡拉OK填色",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["karaoke", "lyrics", "wipe", "color fill", "sing along", "卡拉OK", "歌词", "填色", "逐字变色"],
  "summary": "文字按镜头进度从左到右被一种高亮颜色“唱”过去：已唱部分变色并带一点辉光，填色前沿有一条细亮线；多行可依次填色。",
  "when": "歌词视频与 MV 的歌词行、跟唱/教学、按节奏强调一句口号。",
  "avoid": "需要与人声逐字精确同步的场景（这里按镜头进度匀速推进；逐字对齐请用场景代码的 wordProgress）；深色字请开 darkText。",
  "params": {
    "start": { "type": "float", "default": 0.05, "min": 0, "max": 0.9, "label": "开始填色的镜头进度" },
    "end": { "type": "float", "default": 0.85, "min": 0.1, "max": 1, "label": "填满的镜头进度" },
    "lines": { "type": "float", "default": 1, "min": 1, "max": 10, "label": "行数（多行时按行依次填，行高按画面均分）" },
    "sung": { "type": "color", "default": "#ff4d12", "label": "已唱颜色" },
    "glow": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "辉光（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "darkText": { "type": "bool", "default": false, "label": "深色字（浅底）" }
  },
  "bindings": { "glow": { "to": "beat", "amount": 0.4 } },
  "inspiredBy": [{ "source": "shotcraft", "ref": "卡拉OK纪律：未唱/正在唱/已唱三态", "note": "本仓库" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：卡拉OK字幕用两层字——底层是未唱的颜色，上层是已唱的颜色，一个遮罩随着人声从左向右推进，露出上层。
// 这里没有词级时间，所以遮罩前沿按镜头进度匀速推进（多行时一行填完再填下一行）。

float inkAt(vec2 p) {
  float l = fxLuma(srcTex(p).rgb);
  return darkText ? smoothstep(threshold + .08, threshold - .08, l) : smoothstep(threshold - .08, threshold + .08, l);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkAt(uv);
  // ① 前沿位置：总进度 → 第几行、行内 x
  float n = max(floor(lines + .5), 1.);
  float k = clamp((uProgress - start) / max(end - start, .01), 0., 1.) * n;
  float row = floor((1. - uv.y) * n);
  float fx = clamp(k - row, 0., 1.);                     // 本行已填到哪（0..1）
  float filled = smoothstep(fx + .002, fx - .002, uv.x);
  // ② 前沿亮线：正在唱的位置
  float edge = exp(-pow((uv.x - fx) * 140., 2.)) * step(.001, fx) * step(fx, .999);
  // ③ 辉光：已唱字的周围 4 点平均墨量（4 次采样），随拍呼吸
  vec2 o = vec2(4. / uRes.x, 4. / uRes.y);
  float halo = (inkAt(uv + vec2(o.x, 0.)) + inkAt(uv - vec2(o.x, 0.)) + inkAt(uv + vec2(0., o.y)) + inkAt(uv - vec2(0., o.y))) * .25;
  // ④ 合成：已唱部分的字换成高亮色，未唱部分保持原样；辉光与前沿亮线只在字附近
  vec3 c = mix(src, sung * (1. + .15 * glow), ink * filled);
  c += sung * halo * (1. - ink) * filled * glow * .6;
  c += vec3(1.) * edge * ink * .8;
  return vec4(c, 1.);
}
