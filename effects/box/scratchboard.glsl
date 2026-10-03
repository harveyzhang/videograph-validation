/*@effect
{
  "id": "scratchboard",
  "name": "刮刮画",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["scratchboard", "scraperboard", "scratch art", "white line", "刮画", "刮刮画", "白线版画"],
  "summary": "黑色涂层上用刀刮出白线：亮部是密集的平行刮痕，暗部保持纯黑，刮痕方向随形体转动；鼓点时刮痕变粗一瞬。",
  "when": "暗黑童话、悬疑、复古科普插图、威士忌/手工品牌、夜景与剪影镜头。",
  "avoid": "整体很亮的画面（会变成满屏白线，失去刮画的黑底感）；需要颜色的镜头（可用 under 改刮出的底色）。",
  "params": {
    "spacing": { "type": "float", "default": 6, "min": 2.5, "max": 14, "label": "刮痕间距（像素）" },
    "angle": { "type": "float", "default": 0.6, "min": 0, "max": 3.1416, "label": "主刮痕方向（弧度）" },
    "width": { "type": "float", "default": 0.4, "min": 0.1, "max": 0.9, "label": "刮痕粗细" },
    "under": { "type": "color", "default": "#f3ead6", "label": "刮出的底色" },
    "coat": { "type": "color", "default": "#0d0c0c", "label": "涂层颜色" }
  },
  "bindings": { "width": { "to": "kick", "amount": 0.15 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/engraving 与 woodcut：线刻观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：刮画板是白色陶土板上覆一层黑墨，画家用刀从黑里“刮出光”——亮的地方刮得密，暗的地方不刮。
// 和铜版刻线（engraving-hatch：白底黑线）正好相反：这里是黑底白线。
// 画家会让刮痕顺着形体的明暗走向转动方向，最亮处再刮一层交叉线；刀尖入刀和收刀时线变细。

vec4 effect(vec2 uv) {
  // ① 读明暗；画家下刀时线条会顺着形体略微弯曲——用两层低频噪声把“刮痕坐标”轻轻扭弯（只弯不转向，
  //    否则在大坐标处角度的微小变化会被放大成指纹状的摩尔纹）。
  float l = fxLuma(srcTex(uv).rgb);
  vec2 p = uv * uRes;
  float bend = (fxNoise(uv * 2.5) - .5) * 3. + (fxNoise(uv * 7. + 4.) - .5) * .8;

  // ② 第一层刮痕：平行线；越亮刮得越宽（线宽 ∝ 亮度）。刀痕沿长度方向有入刀/收刀的粗细变化（噪声调制）。
  //    width 挂鼓点：鼓点那一下所有刮痕变粗，画面整体一亮再回落。
  vec2 d1 = vec2(cos(angle), sin(angle));
  float t1 = dot(p, vec2(-d1.y, d1.x)) / spacing + bend;
  float along1 = dot(p, d1) / spacing;
  float taper1 = .6 + .4 * fxNoise(vec2(floor(t1) * 3.1, along1 * .15));
  float w1 = smoothstep(.12, .85, l) * width * taper1;
  float line1 = smoothstep(w1, w1 - .18, abs(fract(t1) - .5));

  // ③ 第二层交叉刮痕：只在最亮处出现（画家最后刮出的高光），方向与第一层成约 70°。
  vec2 d2 = vec2(cos(angle + 1.2), sin(angle + 1.2));
  float t2 = dot(p, vec2(-d2.y, d2.x)) / (spacing * 1.15) + bend * .7;
  float w2 = smoothstep(.62, .95, l) * width * .9;
  float line2 = smoothstep(w2, w2 - .18, abs(fract(t2) - .5));

  // ④ 刮痕边缘：刀刮过的白线边缘不完全干净，有细小的毛刺（像素级噪声，静止）。
  float scratch = max(line1, line2);
  scratch *= .85 + .15 * fxHash(floor(p * .9));

  // ⑤ 合成：黑色涂层 + 刮出的底色（略带陶土的暖白）。
  vec3 c = mix(coat, under, clamp(scratch, 0., 1.));
  return vec4(c, 1.);
}
