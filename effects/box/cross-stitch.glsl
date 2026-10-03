/*@effect
{
  "id": "cross-stitch",
  "name": "十字绣",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["cross stitch", "embroidery", "needlework", "fabric", "craft", "十字绣", "刺绣", "布艺", "手工"],
  "summary": "画面变成一幅十字绣：棉布网格上每一格是一个用彩色绣线绣成的“×”，线有光泽与纤维纹，颜色被限制在有限的线色里，背景露出亚麻布纹；鼓点时绣线光泽一亮。",
  "when": "手工/家庭/温暖怀旧题材、节日与祝福、母亲节、可爱的生活方式品牌。",
  "avoid": "需要细节的镜头（每格只有一种颜色）；科技与冷峻风格。",
  "params": {
    "stitch": { "type": "float", "default": 0.018, "min": 0.006, "max": 0.06, "label": "针脚大小（画面高度比例）" },
    "levels": { "type": "float", "default": 6, "min": 2, "max": 16, "label": "线色级数" },
    "fabric": { "type": "color", "default": "#efe6d2", "label": "布色" },
    "skip": { "type": "float", "default": 0.08, "min": 0, "max": 1, "label": "留白阈值（亮于此的格子不绣）" },
    "sheen": { "type": "float", "default": 0.2, "min": 0, "max": 1, "label": "绣线光泽（通常由节拍驱动）" }
  },
  "bindings": { "sheen": { "to": "kick", "amount": 0.4 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/crayon-book：手作质感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：十字绣在有规则网眼的十字绣布上进行，每一格用两针斜线交叉成一个“×”；绣线是几股棉线并成的，
// 有光泽和纤维纹；颜色由有限的几种线色组成（看图样换线）；很亮的地方通常不绣，直接露出布。

vec4 effect(vec2 uv) {
  float spx = stitch * uRes.y;
  vec2 g = uv * uRes / spx;
  vec2 id = floor(g), f = fract(g) - .5;
  // ① 每格的线色：格中心颜色按 levels 级量化（有限线色），太亮的格子留白
  vec3 col = srcTex((id + .5) * spx / uRes).rgb;
  col = floor(col * levels + .5) / levels;
  float stitched = step(fxLuma(col), 1. - skip);
  // ② 布纹：亚麻布的经纬线与网眼
  vec2 q = uv * uRes / (spx / 4.);
  float weave = .9 + .1 * (step(.5, fract(q.x)) * .5 + step(.5, fract(q.y)) * .5);
  vec3 c = fabric * weave * (.94 + .06 * fxNoise(uv * uRes * .5));
  c *= 1. - .25 * smoothstep(.42, .5, max(abs(f.x), abs(f.y)));          // 网眼处略暗
  // ③ “×”：两条对角线，线宽约格子的 22%；上面那针（右上到左下）盖在下面那针之上
  float w = .11;
  float d1 = abs(f.x - f.y) / 1.414, d2 = abs(f.x + f.y) / 1.414;
  float inBox = step(max(abs(f.x), abs(f.y)), .42);
  float s1 = smoothstep(w, w * .6, d1) * inBox, s2 = smoothstep(w, w * .6, d2) * inBox;
  // ④ 绣线质感：沿线方向的纤维纹 + 中央高光（光泽，sheen 挂鼓点）
  float fib1 = .8 + .2 * sin((f.x + f.y) * 40.), fib2 = .8 + .2 * sin((f.x - f.y) * 40.);
  vec3 th1 = col * fib1 * (1. + (sheen + .15) * smoothstep(w * .5, 0., d1));
  vec3 th2 = col * fib2 * (1. + (sheen + .15) * smoothstep(w * .5, 0., d2));
  c = mix(c, th1 * .9, s1 * stitched);
  c = mix(c, th2, s2 * stitched);
  return vec4(c, 1.);
}
