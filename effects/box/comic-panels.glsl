/*@effect
{
  "id": "comic-panels",
  "name": "漫画分格",
  "kind": "post",
  "category": "画面版式",
  "tags": ["comic", "manga", "panels", "halftone", "speed lines", "漫画", "分格", "网点", "速度线"],
  "summary": "画面被切成几格倾斜的漫画格（粗黑边框 + 白色格缝），每格是画面的不同局部并带网点阴影；中间一格是主格，鼓点时主格放出放射速度线。",
  "when": "动漫/漫画风、搞笑与热血、综艺、游戏与潮玩、多个瞬间并置的叙事。",
  "avoid": "写实或高端质感的镜头；需要完整看到全画面时。",
  "params": {
    "slant": { "type": "float", "default": 0.12, "min": 0, "max": 0.3, "label": "分格倾斜" },
    "border": { "type": "float", "default": 0.006, "min": 0.002, "max": 0.02, "label": "边框粗细" },
    "dots": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "网点阴影" },
    "action": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "速度线（通常由节拍驱动）" },
    "paper": { "type": "color", "default": "#f6f1e6", "label": "纸色" }
  },
  "bindings": { "action": { "to": "kick", "amount": 0.8 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/cel-anime-80s 与 halftone-dossier：漫画网点", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：漫画页由大小不一、边缘常常倾斜的格子组成，格子之间留白，格子用粗黑线框住；
// 阴影用网点纸（规则的黑点）表现；关键的动作格会画放射状的速度线（集中线）。

vec4 effect(vec2 uv) {
  float A = uRes.x / uRes.y;
  // ① 分格：一条斜的竖分割线把画面分成左右；右侧再被一条斜横线分成上下 → 3 格（左大格为主格）
  float x1 = .58 + (uv.y - .5) * slant;
  float y1 = .5 + (uv.x - .8) * slant * 1.5;
  float id = uv.x < x1 ? 0. : (uv.y > y1 ? 1. : 2.);
  float gap = .012;
  float dX = abs(uv.x - x1) * A, dY = uv.x > x1 ? abs(uv.y - y1) : 1.;
  float dEdge = min(min(min(uv.x, 1. - uv.x) * A, min(uv.y, 1. - uv.y)), min(dX, dY));
  // ② 每格取景：主格看画面中部、两个小格是放大的局部
  vec2 q = uv;
  if (id == 1.) q = vec2(.5, .62) + (uv - vec2(.79, .75)) * .55;
  if (id == 2.) q = vec2(.62, .4) + (uv - vec2(.79, .25)) * .55;
  if (id == 0.) q = vec2(.5, .5) + (uv - vec2(x1 * .5, .5)) * .85;
  vec3 s = srcTex(q).rgb;
  // ③ 漫画上色：颜色压成几档 + 暗部叠网点（按 45° 网格的圆点）
  float l = fxLuma(s);
  vec3 c = floor(s * 4. + .5) / 4.;
  vec2 g = fxRot(.785) * (uv * uRes / 7.);
  float dot_ = length(fract(g) - .5);
  float shade = smoothstep(.55, .25, l) * dots;
  c *= 1. - step(dot_, .38 * shade) * .7;
  // ④ 主格速度线：鼓点时从主格中心放射的细线（集中线），中心留空
  if (id == 0. && action > .01) {
    vec2 cp = (uv - vec2(x1 * .5, .5)) * vec2(A, 1.);
    float ang = atan(cp.y, cp.x);
    float ray = step(.88, fxHash(vec2(floor(ang * 60.), 1.))) * smoothstep(.12, .35, length(cp));
    c = mix(c, vec3(.05), ray * action * .9);
  }
  // ⑤ 边框与格缝：离格边 < gap 为纸色留白，再往里 border 为黑框
  vec3 col = dEdge < gap * .5 ? paper : dEdge < gap * .5 + border ? vec3(.05) : c;
  return vec4(col, 1.);
}
