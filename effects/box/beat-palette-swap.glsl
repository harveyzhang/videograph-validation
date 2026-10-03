/*@effect
{
  "id": "beat-palette-swap",
  "name": "拍点换调色板",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["palette swap", "gradient map", "beat", "color cycle", "pop art", "换色", "渐变映射", "波普"],
  "summary": "画面被映射成三色渐变（暗/中/亮），每一拍换一套配色（4 套轮换），换色在拍点上瞬间切换、拍内保持；像波普海报一拍一个颜色。",
  "when": "流行/电子/嘻哈的副歌、时尚与潮牌、波普艺术风、快节奏的产品展示。",
  "avoid": "需要真实颜色的镜头；节奏很快（>160 BPM）时换色太频繁会累眼，改用 bar 级切换（见 mixAmt 说明）。",
  "params": {
    "mixAmt": { "type": "float", "default": 0.9, "min": 0, "max": 1, "label": "映射强度（0 = 原画面）" },
    "contrast": { "type": "float", "default": 1.15, "min": 0.6, "max": 2, "label": "反差" },
    "flashEdge": { "type": "float", "default": 0, "min": 0, "max": 0.6, "label": "换色瞬间的亮边（通常由节拍驱动）" }
  },
  "bindings": { "flashEdge": { "to": "kick", "amount": 0.35 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/silkscreen-poster 与 midcentury-toon：波普配色", "note": "只参考风格名称与观感描述，代码为本项目自写；4 套配色为本项目自选" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（平面与剪辑）：安迪·沃霍尔式波普把同一张照片用不同配色丝印多次；剪辑师把它做成动态——
// 每一拍换一套配色，画面结构不变、颜色跟着音乐跳。实现上就是“渐变映射”（明暗 → 三色渐变）。
// 安全：相邻配色的平均亮度接近（都是暗-中-亮三段），换色时整屏亮度变化小；每拍一次（≤ 2.7 次/秒 @160BPM）。

vec3 grad(float l, vec3 a, vec3 b, vec3 c) {
  return l < .5 ? mix(a, b, l * 2.) : mix(b, c, l * 2. - 1.);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float l = clamp((fxLuma(src) - .5) * contrast + .5, 0., 1.);

  // ① 第几拍：用小节相位算出当前是小节里的第 0–3 拍，每拍对应一套配色（拍内保持不变）。
  float k = floor(uBar * 4.);

  // ② 四套配色（暗 / 中 / 亮），平均亮度相近，换色时不会整屏忽明忽暗。
  vec3 col;
  if (k < .5) col = grad(l, vec3(.12, .05, .3), vec3(.95, .2, .45), vec3(1., .9, .55));
  else if (k < 1.5) col = grad(l, vec3(.02, .15, .25), vec3(.1, .7, .65), vec3(.95, .97, .8));
  else if (k < 2.5) col = grad(l, vec3(.25, .05, .1), vec3(.98, .45, .1), vec3(1., .95, .7));
  else col = grad(l, vec3(.1, .08, .3), vec3(.45, .4, .95), vec3(.85, 1., .95));

  // ③ 换色瞬间的亮边：flashEdge 挂鼓点——鼓点那一帧画面轮廓亮一下，帮眼睛“接住”换色。
  vec2 o = 1.5 / uRes;
  float e = abs(fxLuma(srcTex(uv + vec2(o.x, 0.)).rgb) - fxLuma(srcTex(uv - vec2(o.x, 0.)).rgb))
          + abs(fxLuma(srcTex(uv + vec2(0., o.y)).rgb) - fxLuma(srcTex(uv - vec2(0., o.y)).rgb));
  col += smoothstep(.1, .4, e) * flashEdge;

  return vec4(mix(src, col, mixAmt), 1.);
}
