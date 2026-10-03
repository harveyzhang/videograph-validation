/*@effect
{
  "id": "gen-hud-rings",
  "name": "HUD 瞄准环",
  "kind": "post",
  "category": "生成层",
  "tags": ["hud", "interface", "target", "rings", "sci-fi ui", "radar", "界面", "瞄准", "科幻界面", "雷达"],
  "summary": "以一点为中心叠一组科幻界面圆环：刻度环、断续弧段、扫描扇区、数据小方块，各环以不同速度反向旋转；中心十字准星，鼓点时外环扩张一下。",
  "when": "科幻/军事/赛车/游戏界面、锁定目标、产品功能标注、“分析中”的数据镜头。",
  "avoid": "温暖手作或自然题材；中心位置正好压着人脸时（调 centerX/centerY）。",
  "params": {
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y" },
    "radius": { "type": "float", "default": 0.32, "min": 0.08, "max": 0.6, "label": "外环半径（画面高度比例）" },
    "spin": { "type": "float", "default": 0.3, "min": 0, "max": 2, "label": "旋转速度" },
    "expand": { "type": "float", "default": 0, "min": 0, "max": 0.2, "label": "鼓点扩张（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#5fe6ff", "label": "界面颜色" },
    "accent": { "type": "color", "default": "#ff4d12", "label": "强调色" }
  },
  "bindings": { "expand": { "to": "kick", "amount": 0.06 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/hologram-hud", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（电影 UI 设计）：科幻 HUD 由几层同心元素组成——带刻度的仪表环、断续的弧段、雷达扫描扇区、
// 小方块“数据位”和中心准星；各层以不同速度、相反方向转动，制造“正在计算”的感觉。所有线条都是 1–2 像素的细线发光。

float ringLine(float r, float R, float w) { return smoothstep(w, 0., abs(r - R)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 d = (uv - vec2(centerX, centerY)) * vec2(uRes.x / uRes.y, 1.);
  float r = length(d);
  float a = atan(d.y, d.x) / 6.2832 + .5;            // 0..1
  float px = 1.2 / uRes.y;
  float R = radius * (1. + expand);
  float ui = 0., acc = 0.;

  // ① 外环：细圆 + 72 格刻度（每 6 格一根长刻度），顺时针慢转。
  float a1 = fract(a + uTime * spin * .05);
  ui += ringLine(r, R, px);
  float tick = step(fract(a1 * 72.), .12) * step(R, r) * step(r, R + (step(fract(a1 * 12.), .02) > .5 ? .03 : .015));
  ui += tick;

  // ② 断续弧段：在 0.82R 处，按角度分成 5 段、每段长短不同，逆时针转。
  float a2 = fract(a - uTime * spin * .12);
  float arcOn = step(fract(a2 * 5.), .55 + .3 * fxHash(vec2(floor(a2 * 5.), 1.)));
  ui += ringLine(r, R * .82, px * 2.2) * arcOn;

  // ③ 雷达扫描扇区：在 0.6R 内，一个扇形亮区转圈，后沿渐隐（余辉）。
  float a3 = fract(a - uTime * spin * .5);
  ui += step(r, R * .6) * smoothstep(.15, 0., a3) * .35;
  ui += ringLine(r, R * .6, px) * .8;

  // ④ 数据位：0.7R 处一圈小方块，部分亮起（随时间换），强调色。
  float a4 = fract(a + uTime * spin * .2);
  float cellA = floor(a4 * 40.);
  float blk = step(abs(fract(a4 * 40.) - .5), .3) * step(abs(r - R * .7), .008);
  acc += blk * step(.55, fxHash(vec2(cellA, floor(uTime * 2.))));

  // ⑤ 中心准星：十字 + 小圆，十字中间留空。
  vec2 ad = abs(d);
  float cross = (step(ad.y, px) * step(R * .06, ad.x) * step(ad.x, R * .2)) + (step(ad.x, px) * step(R * .06, ad.y) * step(ad.y, R * .2));
  ui += cross + ringLine(r, R * .04, px);
  // 鼓点时外环闪一下强调色
  acc += ringLine(r, R * 1.06, px * 1.5) * expand * 12.;

  // ⑥ 合成：界面线加光叠加，强调元素用强调色。
  vec3 c = 1. - (1. - src) * (1. - clamp(color * min(ui, 1.) * .9, 0., 1.));
  c = mix(c, accent, clamp(acc, 0., 1.) * .9);
  return vec4(c, 1.);
}
