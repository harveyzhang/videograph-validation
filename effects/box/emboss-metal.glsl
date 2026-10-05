/*@effect
{
  "id": "emboss-metal",
  "name": "金属浮雕",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["emboss", "relief", "metal", "coin", "engrave", "浮雕", "金属", "硬币", "压印"],
  "summary": "画面像被压印在一块金属板上（硬币/奖牌质感）：明暗变成凹凸起伏，左上方光照下凸起处亮、凹处暗，表面带拉丝金属纹理与色泽（金/银/铜可调）；一道高光随小节扫过。",
  "when": "奖牌/徽章/纪念、金融与货币、复古工业、Logo 与标题的“铸造”效果。",
  "avoid": "需要颜色与细节的写实画面；低对比的画面（起伏不明显）。",
  "params": {
    "metal": { "type": "color", "default": "#c9a256", "label": "金属色（金/银/铜）" },
    "relief": { "type": "float", "default": 1.4, "min": 0.2, "max": 4, "label": "浮雕深度" },
    "brushed": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "拉丝纹理" },
    "sweep": { "type": "float", "default": 0.5, "min": 0, "max": 1.5, "label": "扫光（通常由小节驱动）" }
  },
  "bindings": { "sweep": { "to": "bar", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：金属质感", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：浮雕是用模具把图案压进金属，亮处凸起、暗处凹下；光从左上方照来，朝光的斜面亮、背光的斜面暗。
// 金属表面经过拉丝处理，有细密的横向纹理；转动时一道高光滑过表面。

vec4 effect(vec2 uv) {
  vec2 o = 1.5 / uRes;
  // ① 高度 = 亮度；法线从高度梯度求（4 次采样）
  float hl = fxLuma(srcTex(uv - vec2(o.x, 0.)).rgb), hr = fxLuma(srcTex(uv + vec2(o.x, 0.)).rgb);
  float hd = fxLuma(srcTex(uv - vec2(0., o.y)).rgb), hu = fxLuma(srcTex(uv + vec2(0., o.y)).rgb);
  vec3 n = normalize(vec3((hl - hr) * relief, (hd - hu) * relief, .25));
  // ② 光照：左上方主光 + 环境光
  float diff = clamp(dot(n, normalize(vec3(-.6, .6, .55))), 0., 1.);
  float spec = pow(clamp(dot(reflect(-normalize(vec3(-.6, .6, .55)), n), vec3(0., 0., 1.)), 0., 1.), 24.);
  // ③ 拉丝：横向的细纹（高频噪声，横向拉长）
  float br = .85 + .15 * fxNoise(vec2(uv.x * uRes.x * .05, uv.y * uRes.y * 1.2)) * brushed + (1. - brushed) * .15;
  // ④ 扫光：每小节一道斜向高光
  vec2 p = uv * vec2(uRes.x / uRes.y, 1.);
  float s = (p.x + p.y) - fract(uBar + .1) * 3.5 + .5;
  float band = exp(-s * s * 30.) * sweep;
  vec3 c = metal * (.25 + .85 * diff) * br + vec3(1., .97, .9) * (spec * .6 + band * .5);
  return vec4(c, 1.);
}
