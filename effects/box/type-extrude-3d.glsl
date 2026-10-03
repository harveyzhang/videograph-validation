/*@effect
{
  "id": "type-extrude-3d",
  "name": "立体挤出字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "3d text", "extrude", "long shadow", "retro title", "文字", "立体字", "挤出", "长投影"],
  "summary": "亮色文字向斜后方挤出成一块有厚度的立体字：侧面按深度由亮到暗，正面带一圈斜面高光；鼓点时厚度猛地加深再回落。",
  "when": "复古片头、游戏/街机标题、80 年代海报、品牌名大字、卡点标题砸入。",
  "avoid": "文字很细或很小（挤出后糊成一团）；画面大面积都是亮色（整片都会被挤出）。",
  "params": {
    "depth": { "type": "float", "default": 0.035, "min": 0.005, "max": 0.1, "label": "厚度（画面高度比例）" },
    "angle": { "type": "float", "default": -0.75, "min": -3.1416, "max": 3.1416, "label": "挤出方向（弧度）" },
    "side": { "type": "color", "default": "#ff4d12", "label": "侧面颜色" },
    "threshold": { "type": "float", "default": 0.55, "min": 0.1, "max": 0.95, "label": "文字亮度阈值" },
    "bevel": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "正面斜面高光" }
  },
  "bindings": { "depth": { "to": "kick", "amount": 0.025 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/game-show 与 cel-anime-80s：立体标题字观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（立体字招牌/3D 软件挤出）：平面字沿一个方向推出厚度，侧面朝向光的部分亮、背光的部分暗，
// 越往后越暗（远离光源、被正面遮挡）；正面边缘倒角会反出一圈高光。
// 实现：对每个像素，沿挤出方向“往回看”12 步——如果回看路径上碰到字，这个像素就在那个字的侧面上，碰到的步数 = 深度。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  vec2 dir = vec2(cos(angle), sin(angle)) * asp;

  // ① 正面：当前像素本身就是字 → 显示原画面（字面）。
  float front = inkAt(uv);

  // ② 侧面：沿挤出方向反向回看 12 步，找到最近的字；步数越大 = 越靠后 = 越暗。
  //    depth 挂鼓点：鼓点那一下字“变厚”，像被低音推出来。
  float hit = 0., d = 0.;
  for (int i = 1; i <= 12; i++) {
    float t = float(i) / 12.;
    float m = inkAt(uv - dir * depth * t);
    if (m > .5 && hit < .5) { hit = 1.; d = t; }
  }

  // ③ 侧面明暗：近正面亮、远处暗；再叠一点条纹，像挤出体的分层（老式立体字常见的线条）。
  float stripe = .9 + .1 * step(.5, fract(d * 6.));
  vec3 sideCol = side * mix(1.05, .35, d) * stripe;

  // ④ 正面斜面：正面边缘朝光一侧（挤出反方向）提亮，2 次采样。
  float rim = front * (1. - inkAt(uv + dir * .004)) * bevel;
  float shade = front * (1. - inkAt(uv - dir * .004)) * bevel;

  // ⑤ 合成：背景 → 侧面 → 正面（正面在最上层），正面边缘高光/暗边。
  vec3 c = mix(src, sideCol, hit * (1. - front));
  c = mix(c, src, front);
  c += rim * .35 - shade * .2;
  return vec4(c, 1.);
}
