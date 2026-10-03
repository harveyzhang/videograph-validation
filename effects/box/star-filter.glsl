/*@effect
{
  "id": "star-filter",
  "name": "星芒镜",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["star filter", "cross screen", "sparkle", "glint", "星芒", "十字星", "闪光"],
  "summary": "画面里的高光点拉出四道十字星芒，像在镜头前加了一片星光滤镜；星芒随鼓点伸长，随时间轻轻闪烁。",
  "when": "珠宝、香水、灯光夜景、舞台、节日烟花、偶像与 MV 的“bling”时刻；鼓点处星芒一闪。",
  "avoid": "画面大面积高亮（星芒会铺满整片亮区）；严肃纪实题材；没有亮点的暗画面几乎看不出效果。",
  "params": {
    "threshold": { "type": "float", "default": 0.62, "min": 0.3, "max": 0.98, "label": "起芒亮度" },
    "reach": { "type": "float", "default": 0.07, "min": 0.01, "max": 0.15, "label": "星芒长度（画面高度比例）" },
    "intensity": { "type": "float", "default": 1.4, "min": 0, "max": 3, "label": "星芒强度" },
    "density": { "type": "float", "default": 0.8, "min": 0.05, "max": 1, "label": "星芒密度" },
    "angle": { "type": "float", "default": 0.35, "min": 0, "max": 1.5708, "label": "星芒角度（弧度）" }
  },
  "bindings": { "reach": { "to": "kick", "amount": 0.05 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：高光闪烁/星芒点缀", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：星光镜是一片刻了细密交叉网格的玻璃。网格对光产生衍射，每个足够亮的点会沿着与刻线垂直的方向
// 拉出光芒（两组刻线 → 四道芒），芒从中心向外衰减；暗处的衍射太弱，看不见。人眼看到的是画面里
// “最亮的那些点”各自开出一朵十字星，而不是整片亮区都在拉丝。

vec4 effect(vec2 uv) {
  vec3 base = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp;                       // 按画面高度归一化，星芒不会被拉伸

  // ① 找高光点：把画面分成格子（格宽 = 星芒长度的 0.8 倍），每格在随机位置“取一个点”当候选光点。
  //    只看自己和 8 个邻格（9 次采样），所以星芒最长约 1.5 格，越界不会被截断。
  float cell = max(reach, .01) * .8;
  vec2 g = floor(p / cell);
  float ca = cos(angle), sa = sin(angle);
  vec3 star = vec3(0.);
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = g + vec2(float(i), float(j));
      vec2 c = (id + .2 + .6 * vec2(fxHash(id), fxHash(id + 17.3))) * cell;   // 格内随机位置
      vec3 s = srcTex(c / asp).rgb;
      // ② 只有足够亮的点能衍射出星芒；density 决定多少比例的亮格真的开花（避免排成整齐的网格）。
      float lit = smoothstep(threshold, 1., fxLuma(s)) * step(fxHash(id + 5.1), density);

      // ③ 闪烁：每颗星有自己的相位，缓慢地（约 1–2 秒一个周期）亮暗，像珠宝转动时反光。
      float tw = .55 + .45 * sin(uTime * (2. + 2. * fxHash(id + 9.)) + fxHash(id + 3.) * 6.2832);

      // ④ 衍射芒：转到刻线坐标系，两条正交的细线（越往外越细）+ 中心一个小光点。
      //    reach 挂鼓点：鼓点时所有星芒“唰”地伸长，然后缩回。
      vec2 d = p - c;
      d = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y);
      vec2 ad = abs(d) / reach;
      float px = 1. / uRes.y / reach;      // 一个像素在归一化坐标里的大小，芒最细约一像素
      float armX = exp(-ad.x * 1.8) * smoothstep(px * 1.5 + .025 * max(1. - ad.x, 0.), 0., ad.y);
      float armY = exp(-ad.y * 1.8) * smoothstep(px * 1.5 + .025 * max(1. - ad.y, 0.), 0., ad.x);
      float core = exp(-dot(ad, ad) * 60.) + exp(-length(ad) * 5.) * .18;   // 光点 + 一圈柔和的玻璃散射晕

      // ⑤ 色散：衍射对不同波长偏折不同，芒的尾部偏冷、靠近光点偏暖。
      vec3 hue = mix(vec3(1., .93, .82), vec3(.8, .9, 1.15), clamp(length(ad) * 1.5, 0., 1.));
      star += (armX + armY + core * 1.5) * hue * mix(s, vec3(1.), .6) * lit * tw;
    }
  }

  // ⑥ 滤镜玻璃的杂散光：多了一片玻璃，画面整体反差略降、暗部微微发灰（这是星光镜的“副作用”，也是它的味道）。
  base = mix(base, base * .9 + .05, .6);

  // ⑦ 合成：光是叠加的（屏幕混合），原图细节保留。
  vec3 c = 1. - (1. - base) * (1. - clamp(star * intensity, 0., 1.));
  return vec4(c, 1.);
}
