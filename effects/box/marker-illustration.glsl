/*@effect
{
  "id": "marker-illustration",
  "name": "马克笔插画",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["marker", "copic", "alcohol marker", "illustration", "design sketch", "马克笔", "设计手绘", "快速表现"],
  "summary": "酒精马克笔快速表现：颜色压成几级平涂，能看到一笔一笔平行的笔道、笔道交叠处更深，留白处是纸，最后用针管笔勾黑线。",
  "when": "产品/建筑/服装设计草图、创意提案、漫画分镜、轻松的科普讲解；明亮干净的画面最好看。",
  "avoid": "暗部很多的画面（马克笔叠深会发脏）；需要写实质感的镜头。",
  "params": {
    "levels": { "type": "float", "default": 4, "min": 2, "max": 8, "label": "色阶" },
    "nib": { "type": "float", "default": 14, "min": 6, "max": 40, "label": "笔道宽度（像素）" },
    "angle": { "type": "float", "default": 0.35, "min": -1.5708, "max": 1.5708, "label": "运笔方向（弧度）" },
    "liner": { "type": "float", "default": 0.85, "min": 0, "max": 1.5, "label": "针管笔勾线" },
    "paper": { "type": "color", "default": "#fdfbf6", "label": "纸色" }
  },
  "bindings": { "liner": { "to": "kick", "amount": 0.4 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/urban-sketch：快速手绘观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：酒精马克笔是透明染料，一笔下去颜色平而亮，但两笔重叠的地方染料叠两次会更深，
// 所以平涂区能看到一条条平行笔道和它们之间的深色接缝；设计师只用几个灰阶/色阶，最亮处直接留白，
// 最后用 0.3 针管笔勾出轮廓。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = uv * uRes;

  // ① 选笔：颜色按亮度分 levels 级，每级是一支马克笔（保留原色相，饱和度略提高，像染料色）。
  float l = fxLuma(src);
  float q = max(floor(l * levels + .5) / levels, .22);   // 最深一级也只是深色马克笔，不是死黑
  vec3 hue = src / max(l, .05);
  vec3 ink = clamp(mix(vec3(1.), hue, .9) * q, 0., 1.);
  ink = mix(vec3(fxLuma(ink)), ink, 1.25);

  // ② 运笔：沿 angle 方向一笔一笔平涂；每笔宽 nib，笔与笔之间轻微重叠。笔道边界随手抖略弯。
  vec2 d = vec2(cos(angle), sin(angle));
  float across = dot(p, vec2(-d.y, d.x)) / nib + fxNoise(p * .01) * .6;
  float f = fract(across);
  float overlap = smoothstep(.12, 0., f) + smoothstep(.88, 1., f);      // 两笔重叠的接缝

  // ③ 叠染：接缝处染料叠两层 → 再乘一次颜色（变深）；每笔起止处染料多一点（笔头停顿）。
  float along = dot(p, d) / nib;
  float pool = smoothstep(.75, 1., fxNoise(vec2(floor(across) * 3.7, along * .3)));
  vec3 c = paper * ink;
  c *= mix(vec3(1.), ink, clamp(overlap * .7 + pool * .4, 0., 1.));

  // ④ 留白：最亮的一级直接是纸（马克笔表现里高光是不涂的）。
  c = mix(c, paper, step(.92, q));

  // ⑤ 针管笔勾线：沿轮廓（9 次采样）的细黑线，宽度稳定。liner 挂鼓点：鼓点时线条加重。
  float e = smoothstep(.18, .45, fxSobel(uv));
  c = mix(c, vec3(.08, .08, .1), clamp(e * liner, 0., 1.));
  return vec4(c, 1.);
}
