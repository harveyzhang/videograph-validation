/*@effect
{
  "id": "xerox-photocopy",
  "name": "复印机影印",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["xerox", "photocopy", "zine", "punk", "toner", "影印", "复印", "朋克杂志"],
  "summary": "多次复印后的黑白影印件：高反差、灰阶塌成黑白、碳粉颗粒与黑点噪、边缘有扫描灯的渐暗；鼓点时像又被复印了一次，反差更狠。",
  "when": "朋克/地下乐队、手工 zine、街头海报、调查档案、粗粝的说唱与摇滚 MV。",
  "avoid": "需要灰阶细节或颜色的镜头；温柔细腻的情绪。",
  "params": {
    "generations": { "type": "float", "default": 2, "min": 0, "max": 6, "label": "复印代数（越多越脏越硬）" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.2, "max": 0.8, "label": "黑白分界" },
    "toner": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "碳粉噪点" },
    "paper": { "type": "color", "default": "#f4f2ec", "label": "纸色" }
  },
  "bindings": { "generations": { "to": "kick", "amount": 2.5 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/halftone-dossier：粗粝影印观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：静电复印是“曝光 → 感光鼓带电 → 吸附碳粉 → 加热定影”。碳粉要么吸上要么不吸，所以灰阶很快塌成黑白；
// 每复印一代，反差更硬、细线变粗、暗部发黑、白处多出零星黑点（玻璃板上的灰尘和鼓上的划痕）；
// 扫描灯管照不到的纸边会发暗，纸没压平的地方出现一条深色阴影带。

vec4 effect(vec2 uv) {
  // ① 曝光：读原稿亮度，扫描灯在画面边缘照度不足 → 边缘偏暗（越多代越明显）。
  float l = fxLuma(srcTex(uv).rgb);
  float edgeFall = smoothstep(.35, .75, length((uv - .5) * vec2(1.2, 1.)));
  l -= edgeFall * (.08 + generations * .03);

  // ② 碳粉吸附：每一代都会让 S 曲线更陡（反差更硬），并让暗部稍稍“膨胀”（笔画变粗）。
  //    generations 挂鼓点：鼓点那一下像又过了两代复印，黑白更狠，然后恢复。
  float hardness = 6. + generations * 6.;
  float shift = threshold + generations * .025;
  float toned = 1. / (1. + exp(-(l - shift) * hardness));   // 0 = 黑（有碳粉），1 = 白

  // ③ 碳粉颗粒：黑处的碳粉不均匀（有细小白点），白处有零星黑点（灰尘），都是静止的（同一张复印件）。
  float speck = fxHash(floor(uv * uRes * .8));
  float dust = step(.997 - toner * .006 * (1. + generations * .5), fxHash(floor(uv * uRes * .5) + 3.));
  float grainy = (fxNoise(uv * uRes * .7) - .5) * .35 * toner;
  toned = clamp(toned + grainy, 0., 1.);
  toned = mix(toned, 1., step(.985, speck) * (1. - toned) * toner);   // 黑里的白点
  toned *= 1. - dust;                                                   // 白里的黑点

  // ④ 纸没压平：画面一侧有一条柔和的深色带（书脊/纸边翘起的阴影）。
  float spine = smoothstep(.06, 0., uv.x) * .6 + smoothstep(.95, 1., uv.x) * .3;
  toned *= 1. - spine;

  // ⑤ 输出：碳粉不是纯黑（偏一点暖灰），纸色略灰白。
  vec3 c = mix(vec3(.07, .065, .06), paper, toned);
  return vec4(c, 1.);
}
