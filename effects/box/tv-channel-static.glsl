/*@effect
{
  "id": "tv-channel-static",
  "name": "老电视换台雪花",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["tv static", "snow", "channel surf", "analog tv", "no signal", "雪花", "换台", "模拟电视"],
  "summary": "模拟电视调台时信号时有时无：画面被雪花噪点、滚动的场同步黑条和横向撕扯盖住，鼓点那一下信号丢失最多，随后画面重新“锁上”。",
  "when": "回忆闪回、频道切换感的剪辑点、恐怖与悬疑、复古电视题材、表现“信号/连接中断”。",
  "avoid": "需要长时间看清内容的镜头（雪花会盖住画面）；对光敏感的观众场景要把 loss 调低。",
  "params": {
    "loss": { "type": "float", "default": 0.2, "min": 0, "max": 1, "label": "信号丢失程度" },
    "roll": { "type": "float", "default": 0.35, "min": 0, "max": 2, "label": "场滚动速度" },
    "tear": { "type": "float", "default": 0.5, "min": 0, "max": 1.5, "label": "横向撕扯" },
    "mono": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "褪色（信号弱时色度先丢）" }
  },
  "bindings": { "loss": { "to": "kick", "amount": 0.35 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：模拟信号故障/换台", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：模拟电视靠同步脉冲把每一行、每一场对齐。信号弱时：①天线收到的热噪声被放大成“雪花”；
// ②场同步丢了，画面上下滚动，场消隐期那条黑带也跟着滚进画面；③行同步抖动，某些行被横向扯开；
// ④色度副载波最先丢失，所以信号差时画面先变黑白。和 vhs-tape（磁带磨损）不同：这里是“空中信号”的问题。

vec4 effect(vec2 uv) {
  // ① 场滚动：画面整体缓慢向上滚，滚动带上有一条黑色的场消隐带。滚动速度随信号丢失加快。
  float rollY = fract(uTime * roll * (.3 + loss));
  vec2 u = vec2(uv.x, fract(uv.y + rollY * loss * .6));
  float vbar = smoothstep(.475, .455, abs(fract(uv.y + rollY) - .5));   // 1 = 正常区，0 = 消隐黑带（约 5% 屏高）

  // ② 行同步抖动：按行（每 3 像素一组）横向偏移，偏移量用低频噪声 + 少量突跳（局部，不整屏）。
  float row = floor(uv.y * uRes.y / 3.);
  float jitter = (fxNoise(vec2(row * .08, uTime * 4.)) - .5) * .02 * tear;
  jitter += step(.97, fxHash(vec2(row, floor(uTime * 15.)))) * (fxHash(vec2(row, 1.)) - .5) * .12 * tear * loss;
  u.x += jitter;

  // ③ 解码：取画面；色度丢失 → 向黑白过渡；画面对比度随信号变弱而下降（AGC 自动增益拉不住）。
  vec3 c = srcTex(u).rgb;
  float l = fxLuma(c);
  c = mix(c, vec3(l), clamp(mono + loss * .6, 0., 1.));
  c = mix(c, vec3(.45), loss * .35);

  // ④ 雪花：每帧刷新的像素噪声（按 24 次/秒量化时间，是“噪声颗粒”在变，不是整屏明暗在变 → 没有全屏闪烁）。
  //    颗粒横向略拉长（模拟电视的水平带宽比垂直方向低）。
  vec2 sp = floor(uv * uRes / vec2(2., 1.));
  float snow = fxHash(sp + floor(uTime * 24.) * 17.13);
  snow = mix(snow, fxHash(sp + vec2(1., 0.) + floor(uTime * 24.) * 17.13), .5);
  // loss 挂鼓点：鼓点那一下雪花猛增、画面几乎被盖住，然后信号重新锁上。
  float amount = clamp(loss * 1.1, 0., .9);
  c = mix(c, vec3(snow), amount);

  // ⑤ 场消隐黑带 + 显像管暗角。
  c *= mix(.12, 1., vbar);
  c *= 1. - .35 * dot(uv - .5, uv - .5) * 2.;
  return vec4(c, 1.);
}
