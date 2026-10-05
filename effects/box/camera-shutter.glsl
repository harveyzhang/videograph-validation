/*@effect
{
  "id": "camera-shutter",
  "name": "相机快门转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["shutter", "aperture blades", "camera", "photo", "snap", "快门", "光圈叶片", "拍照", "相机"],
  "summary": "像相机快门一样：六片光圈叶片从四周旋转着合拢遮住旧镜头（伴随一下轻微白闪），再旋转张开露出下一个镜头。",
  "when": "摄影/拍照/定格瞬间、照片合集、旅行 vlog、“咔嚓”的节奏点。",
  "avoid": "需要柔和连续的情绪衔接。时长建议 0.4–0.8 秒。",
  "params": {
    "blades": { "type": "float", "default": 6, "min": 4, "max": 10, "label": "叶片数" },
    "bladeColor": { "type": "color", "default": "#3a3c44", "label": "叶片颜色" },
    "flash": { "type": "float", "default": 0.25, "min": 0, "max": 0.6, "label": "合拢瞬间白闪" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：快门转场", "note": "按思路自写；gl-transitions 无叶片快门转场" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：镜头里的光圈由几片弧形金属叶片组成，转动拨环时叶片同时向中心旋入，开口从大圆变成越来越小的多边形，直到完全闭合。
// 实现：开口是一个随叶片转动而旋转的正多边形，半径随进度先缩到 0 再张开；多边形以外是叶片（带叶片之间的分界线与明暗）。

vec4 transition(vec2 uv) {
  float p = progress;
  bool second = p > .5;
  float t = second ? (p - .5) * 2. : 1. - p * 2.;          // 开口大小 1 → 0 → 1
  float e = t * t * (3. - 2. * t);
  vec2 d = (uv - .5) * vec2(ratio, 1.);
  float r = length(d);
  float a = atan(d.y, d.x);
  float n = floor(blades + .5);
  // ① 开口多边形（随开合旋转）：正 n 边形的距离
  float rot = (1. - e) * 1.2;
  float sec = 6.2832 / n;
  float fa = mod(a + rot, sec) - sec * .5;
  float poly = r * cos(fa) / cos(sec * .5);
  float R = e * 1.15;
  float open = smoothstep(R + .003, R - .003, poly);
  vec3 scene = second ? getToColor(uv).rgb : getFromColor(uv).rgb;
  // ② 叶片：扇形分区明暗交替 + 叶片之间的分界线（沿螺旋）
  float bladeIdx = floor((a + rot * 2. + r * 2.) / sec);
  vec3 bc = bladeColor * (.8 + .4 * fxHash(vec2(bladeIdx, 1.)));
  float seam = smoothstep(.02, 0., abs(fract((a + rot * 2. + r * 2.) / sec) - .5) - .48);
  bc = mix(bc, bc * .4, seam);
  // 叶片的金属光泽：随角度变化的高光，让叶片在任何画面上都看得清
  bc += .12 * pow(max(cos(a * 2. + rot * 3.), 0.), 6.) + .05;
  // 开口边缘一圈亮线（叶片的切边反光）
  bc += smoothstep(.012, 0., abs(poly - R)) * .3;
  vec3 c = mix(bc, scene, open);
  // ③ 合拢瞬间的白闪（局部，中心最亮）
  c += flash * exp(-pow((p - .5) / .05, 2.)) * exp(-r * 2.);
  return vec4(c, 1.);
}
