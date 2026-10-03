/*@effect
{
  "id": "cross-process",
  "name": "交叉冲印",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["cross processing", "xpro", "e6 in c41", "lomo", "交叉冲印", "反转片负冲", "LOMO"],
  "summary": "反转片用负片药水冲：高反差、饱和度爆、高光发黄绿、暗部发青蓝、肤色偏黄，每个通道的曲线都被拧过；鼓点时反差再抬一下。",
  "when": "夏日、街头、潮流与时尚、独立音乐 MV、LOMO 风格的青春片段。",
  "avoid": "需要自然肤色的人像；本来就高饱和的画面会过火（降 strength）。",
  "params": {
    "strength": { "type": "float", "default": 0.85, "min": 0, "max": 1, "label": "强度" },
    "contrast": { "type": "float", "default": 1.2, "min": 0.8, "max": 1.8, "label": "反差" },
    "greenHi": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "高光黄绿" },
    "cyanShadow": { "type": "float", "default": 0.55, "min": 0, "max": 1, "label": "暗部青蓝" }
  },
  "bindings": { "contrast": { "to": "kick", "amount": 0.18 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：胶片调色", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：反转片（E-6）本该冲成正片，故意用负片药水（C-41）冲，三层染料的反差都被拉高且不一致：
// 红层曲线变成很陡的 S、绿层整体抬高、蓝层暗部抬起高光被压——结果是高反差、高饱和、高光黄绿、暗部青蓝。
// 由于没有负片的橙色片基，正片看起来不需要反相，但颜色已经“拧”了。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 三层染料各自的冲洗曲线（以 0.5 为中心的 S 曲线，陡度不同）：红层最陡。
  //    contrast 挂鼓点：鼓点那一下整体反差再拉高，然后回落。
  vec3 k = vec3(1.35, 1.15, .9) * contrast;
  vec3 c = .5 + (src - .5) * k;
  c = c * c * (3. - 2. * clamp(c, 0., 1.));     // 软 S 形：中间更陡、两端压缩

  // ② 绿层整体抬高（高光发黄绿），蓝层暗部抬起高光压低（暗部发青蓝、高光发黄）。
  float l = fxLuma(src);
  c.g += greenHi * .08 * smoothstep(.35, 1., l);
  c.b = mix(c.b, c.b * .78 + .12, smoothstep(.4, 1., l));                       // 高光蓝少 → 黄
  c.b += cyanShadow * .16 * smoothstep(.55, 0., l);                              // 暗部蓝多
  c.g += cyanShadow * .06 * smoothstep(.55, 0., l);                              // 暗部偏青
  c.r -= cyanShadow * .05 * smoothstep(.5, 0., l);

  // ③ 饱和度被药水“冲”高了。
  float lc = fxLuma(c);
  c = mix(vec3(lc), c, 1.3);

  // ④ 负冲的颗粒比正常冲洗更粗一点（静止颗粒，不闪）。
  c += (fxHash(floor(uv * uRes * .6)) - .5) * .03;

  return vec4(mix(src, clamp(c, 0., 1.), strength), 1.);
}
