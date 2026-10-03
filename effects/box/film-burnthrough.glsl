/*@effect
{
  "id": "film-burnthrough",
  "name": "胶片烧穿转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["film burn", "melt", "projector", "celluloid", "burn hole", "胶片烧穿", "片门熔化", "烧洞"],
  "summary": "放映机片门卡住，胶片被灯烧出几个洞：洞口边缘是焦黑 + 橙红发光的熔化带，洞迅速扩大、连成一片，透出下一个镜头。",
  "when": "复古/怀旧到现实的切换、“记忆被烧毁”、摇滚与 grindhouse 风格、旧片段结束的标志。",
  "avoid": "温柔甜美的题材；需要非常干净的硬切时。",
  "params": {
    "holes": { "type": "float", "default": 3, "min": 1, "max": 6, "label": "起火点数量" },
    "glow": { "type": "color", "default": "#ff7a1a", "label": "熔化发光色" },
    "char": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "焦黑宽度" },
    "bubble": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "受热起泡" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：胶片质感/片尾烧片", "note": "按思路自写；与 gl-transitions 的 FilmBurn（漏光式）/ burn（加色）机制不同" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：胶片停在片门里不动时，放映灯的热量几秒就能把醋酸片基烧穿：先在几个点起泡变形，然后熔出洞，
// 洞的边缘是一圈焦黑的碳化带，最外沿还在发橙红色的光（正在燃烧），洞迅速扩大并连成一片，露出白光——这里露出下一个镜头。
// 节拍：转场本身由进度驱动，不挂节拍。

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.);
  float p = progress;

  // ① 起火点：holes 个随机位置，每个点开始燃烧的时间略有先后；当前像素到“最近的火”的有效距离。
  float burn = 1e3;
  for (int i = 0; i < 6; i++) {
    if (float(i) >= holes) break;
    vec2 c = vec2(fxHash(vec2(float(i), 1.)), fxHash(vec2(float(i), 2.))) * .7 + .15;
    float start = fxHash(vec2(float(i), 3.)) * .3;
    float grow = max(p - start, 0.) / (1. - start);
    float r = grow * grow * 1.6;                        // 先慢后快地扩大
    burn = min(burn, length((uv - c) * asp) - r);
  }
  // 熔化边缘不规则：用噪声扰动距离（片基受热不均）
  burn += (fxFbm(uv * 6. + 2.) - .5) * .12;
  // 进度到头时保证全部烧穿
  burn -= smoothstep(.85, 1., p) * 2.;

  // ② 起泡：洞外不远处的胶片受热起泡变形——画面被轻微扭曲、变暖变暗。
  float heat = smoothstep(.25, 0., burn) * step(0., burn);
  vec2 warp = (vec2(fxNoise(uv * 30.), fxNoise(uv * 30. + 5.)) - .5) * .02 * heat * bubble;
  vec3 from = getFromColor(uv + warp).rgb;
  from = mix(from, from * vec3(1.1, .7, .4), heat * .7);

  // ③ 分层：洞里 = 下一个镜头；洞口外沿 = 发光熔化带；再往外 = 焦黑碳化带；最外 = 起泡的原画面。
  float charW = .03 + .05 * char;
  vec3 col = from;
  col = mix(col, vec3(.05, .03, .02), smoothstep(charW, charW * .4, burn) * step(0., burn));   // 焦黑
  col = mix(col, glow * 1.4, smoothstep(.018, 0., burn) * step(0., burn));                       // 燃烧的边
  vec3 to = getToColor(uv).rgb;
  float inHole = step(burn, 0.);
  // 洞口内侧一小圈被火光照亮（白热）
  to += glow * smoothstep(-.03, 0., burn) * .6;
  col = mix(col, to, inHole);
  return vec4(col, 1.);
}
