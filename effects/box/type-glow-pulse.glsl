/*@effect
{
  "id": "type-glow-pulse",
  "name": "文字光晕呼吸",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "glow", "pulse", "beat", "halo", "文字", "发光", "光晕", "呼吸"],
  "summary": "亮色文字周围生出一圈柔和的彩色光晕，光晕随每一拍向外扩散再收回（像在呼吸），颜色可在两色之间随小节渐变；字本身保持清晰。",
  "when": "歌词大字、Logo 落版、夜景与霓虹氛围、抒情与梦幻段落、片头片名。",
  "avoid": "浅色背景（光晕看不出）；字特别多时整片发雾。",
  "params": {
    "radius": { "type": "float", "default": 0.02, "min": 0.003, "max": 0.05, "label": "光晕半径（画面高度比例）" },
    "strength": { "type": "float", "default": 1.4, "min": 0, "max": 2, "label": "光晕强度" },
    "breathe": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "节拍呼吸（通常由节拍驱动）" },
    "colorA": { "type": "color", "default": "#ff5ea8", "label": "光晕色 A" },
    "colorB": { "type": "color", "default": "#5ec8ff", "label": "光晕色 B" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.1, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "breathe": { "to": "beat", "amount": 0.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：发光字", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：发光的字（霓虹、灯箱）在空气里散射出一圈光晕，光晕越远越淡；拍点处像灯被电压冲了一下，光晕扩大再回落。
// 实现：在两个半径上各取 8 个方向的字墨量（16 次采样）做近似的大半径模糊，只用于字外的区域。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float front = inkAt(uv);
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  float R = radius * (1. + breathe * .8);
  float halo = 0.;
  for (int i = 0; i < 8; i++) {
    float a = float(i) * .7854 + .39;
    vec2 d = vec2(cos(a), sin(a)) * asp;
    halo += inkAt(uv + d * R * .45) * .6 + inkAt(uv + d * R) * .4;
  }
  halo /= 8.;
  // 颜色：随小节在两色之间渐变
  vec3 col = mix(colorA, colorB, .5 + .5 * sin(uBar * 6.2832));
  vec3 c = src + col * halo * strength * (1. + breathe * .5) * (1. - front);
  return vec4(c, 1.);
}
