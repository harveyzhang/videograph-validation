/*@effect
{
  "id": "type-offset-outline",
  "name": "错位描边字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "outline", "offset", "misregister", "risograph type", "文字", "描边", "错位", "空心字"],
  "summary": "文字被三层不同颜色的空心描边围住，三层描边各自向不同方向错开并缓慢漂移，像套色没对准的丝印海报字；鼓点时三层一下子拉开。",
  "when": "潮流/独立音乐海报、街头品牌、杂志感标题、歌名与大字口号。",
  "avoid": "很小或很细的字（描边会糊进字里）；需要稳重可读的正式字幕。",
  "params": {
    "offset": { "type": "float", "default": 6, "min": 0, "max": 30, "label": "错位距离（像素）" },
    "width": { "type": "float", "default": 2, "min": 1, "max": 6, "label": "描边粗细（像素）" },
    "hollow": { "type": "bool", "default": false, "label": "主字掏空（只留描边）" },
    "c1": { "type": "color", "default": "#ff3d7f", "label": "描边 1" },
    "c2": { "type": "color", "default": "#36d6ff", "label": "描边 2" },
    "c3": { "type": "color", "default": "#ffd23f", "label": "描边 3" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.1, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "offset": { "to": "kick", "amount": 10 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/risograph 与 swiss-motion：错版描边字", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：丝印/riso 印刷时每种颜色一块版，空心描边字如果套印没对准，三种颜色的描边就会各自错开一点；
// 设计师也会故意把这种错位做成风格。这里每层描边 = 字形边缘（墨量梯度），各自偏移、缓慢绕圈漂移。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

// 字形边缘：在 p 处的墨量梯度（4 次采样），宽度由 width 控制
float edgeAt(vec2 p) {
  vec2 o = width / uRes;
  return clamp(abs(inkAt(p + vec2(o.x, 0.)) - inkAt(p - vec2(o.x, 0.))) + abs(inkAt(p + vec2(0., o.y)) - inkAt(p - vec2(0., o.y))), 0., 1.);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 三块版的错位方向：120° 间隔，并随时间缓慢转动（像版在印刷机里轻微晃动）。offset 挂鼓点：鼓点时三层拉开。
  float a0 = uTime * .4;
  vec2 o1 = vec2(cos(a0), sin(a0)) * offset / uRes;
  vec2 o2 = vec2(cos(a0 + 2.094), sin(a0 + 2.094)) * offset / uRes;
  vec2 o3 = vec2(cos(a0 + 4.189), sin(a0 + 4.189)) * offset / uRes;

  // ② 三层空心描边（各 4 次采样）。
  float e1 = edgeAt(uv - o1), e2 = edgeAt(uv - o2), e3 = edgeAt(uv - o3);

  // ③ 主字：保留原画面，或掏空成背景色（hollow）。
  float front = inkAt(uv);
  vec3 c = src;
  if (hollow) c = mix(src, src * .15, front);

  // ④ 叠印：三种颜色描边用“相加 + 截断”叠加（重叠处变亮，像荧光油墨叠印）。
  c = mix(c, c3, e3 * .95);
  c = mix(c, c2, e2 * .95);
  c = mix(c, c1, e1 * .95);
  return vec4(c, 1.);
}
