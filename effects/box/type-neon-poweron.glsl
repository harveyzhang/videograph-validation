/*@effect
{
  "id": "type-neon-poweron",
  "name": "霓虹字通电",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "neon", "power on", "flicker", "sign", "文字动画", "霓虹", "通电", "闪烁点亮"],
  "summary": "亮色文字像霓虹招牌通电：从左到右一个字一个字地“噼啪”闪几下后亮起，亮起后带一圈彩色辉光并随拍轻轻呼吸；没通电的字是暗灰的玻璃管。",
  "when": "夜店/酒吧/赌场/赛博朋克的标题、店招与 Logo 落版、复古 80 年代、夜景文字。",
  "avoid": "白天/浅色底的画面（辉光看不出）；需要立即读到全部文字的快节奏镜头。",
  "params": {
    "columns": { "type": "float", "default": 10, "min": 2, "max": 40, "label": "通电分段数（≈ 字数）" },
    "inEnd": { "type": "float", "default": 0.35, "min": 0.05, "max": 0.8, "label": "全部点亮于镜头进度" },
    "glow": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "辉光（通常由节拍驱动）" },
    "radius": { "type": "float", "default": 0.012, "min": 0.002, "max": 0.04, "label": "辉光半径（画面高度比例）" },
    "neon": { "type": "color", "default": "#ff3d9a", "label": "霓虹色" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.1, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "glow": { "to": "beat", "amount": 0.35 } },
  "inspiredBy": [{ "source": "lievan-video-prompts", "ref": "prompts/worlds：neon sign 场景描述", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：霓虹灯管通电时，管里的气体先要被击穿，所以会“噼啪”闪几下才稳定亮起；整块招牌往往一个字一个字地点亮。
// 安全：闪烁只发生在正在通电的那一段（局部、几分之一秒），整屏平均亮度变化很小。
// 和 neon-tube-sign（把所有轮廓变成灯管）不同：这里保留字的形状，只做“通电点亮”的过程与辉光。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkAt(uv);

  // ① 通电顺序：按列（≈ 字）从左到右，每列在自己的时刻开始击穿，击穿过程占 0.12 个镜头进度。
  float col = floor(uv.x * columns);
  float start = col / columns * inEnd * .8 + fxHash(vec2(col, 3.)) * inEnd * .1;
  float ph = (uProgress - start) / .12;
  // ② 击穿闪烁：过程中以约 15 次/秒随机亮灭（只在这一列），之后稳定点亮。
  float flick = step(.45, fxHash(vec2(col, floor(uTime * 15.))));
  float lit = ph >= 1. ? 1. : (ph > 0. ? flick * (.4 + .6 * ph) : 0.);

  // ③ 辉光：周围 8 个方向的墨量平均（8 次采样），只取已通电的列；glow 挂每拍——每拍辉光呼吸一次。
  float r = radius;
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  float halo = 0.;
  for (int i = 0; i < 8; i++) {
    float a = float(i) * .7854;
    vec2 q = uv + vec2(cos(a), sin(a)) * r * asp;
    float cq = floor(q.x * columns);
    float sq = cq / columns * inEnd * .8 + fxHash(vec2(cq, 3.)) * inEnd * .1;
    halo += inkAt(q) * step(sq + .12, uProgress);
  }
  halo /= 8.;

  // ④ 合成：字外略压暗（夜色）；未通电的字是暗灰玻璃管；通电的字 = 白热管芯 + 霓虹色，外面一圈辉光。
  vec3 c = src * mix(1., .55, smoothstep(0., .5, halo + ink));
  vec3 off = vec3(.12, .11, .12);
  vec3 on = mix(neon, vec3(1.), .55);
  c = mix(c, mix(off, on, lit), ink);
  c += neon * halo * glow * 1.4 * (1. - ink);
  return vec4(c, 1.);
}
