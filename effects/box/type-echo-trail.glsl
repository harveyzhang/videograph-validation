/*@effect
{
  "id": "type-echo-trail",
  "name": "字形残影",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "echo", "trail", "repeat", "psychedelic", "文字", "残影", "重复", "复古迷幻"],
  "summary": "亮色文字身后拖出 6 层渐变色的重复字形，层层缩放、偏移、转角，像 70 年代迷幻海报的回声字；鼓点时残影一下子散开。",
  "when": "迷幻/复古/放克/电子乐的标题、歌名、强调词；需要文字更有“声音感”的镜头。",
  "avoid": "文字太多的段落（残影会互相叠成一片）；严肃信息类字幕。",
  "params": {
    "spread": { "type": "float", "default": 0.012, "min": 0, "max": 0.05, "label": "残影间距" },
    "scaleStep": { "type": "float", "default": 0.025, "min": -0.08, "max": 0.08, "label": "每层缩放" },
    "twist": { "type": "float", "default": 0.02, "min": -0.15, "max": 0.15, "label": "每层旋转（弧度）" },
    "colorA": { "type": "color", "default": "#ff4d12", "label": "近层颜色" },
    "colorB": { "type": "color", "default": "#5b3cff", "label": "远层颜色" },
    "threshold": { "type": "float", "default": 0.55, "min": 0.1, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "spread": { "to": "kick", "amount": 0.014 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/midcentury-toon 与 rubber-hose：复古回声字", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：迷幻海报和老式片头会把同一个字复制好几层，每层换一种颜色、稍微放大/偏移/转一点角度，
// 叠在主字后面，形成“回声”。由近到远颜色从暖到冷渐变，越远越淡。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float front = inkAt(uv);
  vec2 asp = vec2(uRes.x / uRes.y, 1.);

  // ① 由远到近画 6 层：第 i 层 = 主字绕画面中心 放大 i×scaleStep、旋转 i×twist、向右下偏移 i×spread。
  //    spread 挂鼓点：鼓点那一下残影散开，随后收拢。远层先画，近层盖在上面。
  vec3 c = src;
  for (int j = 0; j < 6; j++) {
    float i = float(6 - j);
    vec2 q = (uv - .5) * asp;
    q = fxRot(-twist * i) * q / (1. + scaleStep * i);
    vec2 p = q / asp + .5 - vec2(spread, -spread * .6) * i;
    float m = inkAt(p);
    // ② 每层颜色从近层色渐变到远层色，越远越淡（但仍是实色块，像丝印的层）
    vec3 layer = mix(colorA, colorB, (i - 1.) / 5.);
    c = mix(c, layer, m * mix(.95, .55, (i - 1.) / 5.));
  }

  // ③ 主字盖在最上面（原画面），保证可读。
  c = mix(c, src, front);
  return vec4(c, 1.);
}
