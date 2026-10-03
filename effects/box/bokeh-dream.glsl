/*@effect
{
  "id": "bokeh-dream",
  "name": "光斑散景",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["bokeh", "defocus", "shallow depth of field", "dreamy", "散景", "焦外", "光斑"],
  "summary": "大光圈失焦：画面中心保持清晰，越往外越虚，亮点变成六边形的焦外光斑。",
  "when": "夜景灯光、婚礼与节日、回忆与梦境、产品主体居中的镜头；在副歌开头“对焦呼吸”一下。",
  "avoid": "需要看清画面边缘信息的镜头（字幕、界面截图）；本身已经很虚的画面效果不明显。",
  "params": {
    "radius": { "type": "float", "default": 0.022, "min": 0, "max": 0.06, "label": "最大虚化半径（画面高度比例）" },
    "focus": { "type": "float", "default": 0.18, "min": 0, "max": 0.7, "label": "清晰区大小" },
    "boost": { "type": "float", "default": 6, "min": 0, "max": 12, "label": "光斑增亮" },
    "blades": { "type": "float", "default": 0.8, "min": 0, "max": 1, "label": "光圈棱角（0 圆 / 1 六边形）" }
  },
  "bindings": { "radius": { "to": "kick", "amount": 0.012 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/cel-anime-80s 与 paper-popup：bokeh 描述", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：焦外的一个点光源在底片上不是一个点，而是光圈形状的一块“弥散圆”；光圈由 6 片叶片围成，
// 所以弥散圆是六边形。普通暗处的弥散圆互相叠加只是变糊，但亮点（灯、反光）的弥散圆亮度远高于周围，
// 于是清楚地浮现成一个个光斑。离焦平面越远，弥散圆越大。

// 六边形光圈：方向 a 上，叶片围成的边界到中心的距离（内切圆半径归一为 1 附近）
float aperture(float a) {
  float seg = mod(a, 1.0472) - .5236;
  return mix(1., .866 / cos(seg), blades);
}

vec4 effect(vec2 uv) {
  // ① 离焦量：以画面中心为焦点，越往外弥散圆越大（像大光圈拍主体居中的画面）。
  //    radius 挂鼓点：鼓点那一下整体虚一下再回到清晰——“对焦呼吸”。
  vec2 cc = (uv - .5) * vec2(uRes.x / uRes.y, 1.);
  float coc = radius * smoothstep(focus * .5, focus * .5 + .45, length(cc));

  // ② 弥散圆采样：在六边形光圈里用黄金角螺旋放 16 个点（每像素 16 次采样），
  //    整体按像素随机转一个角度，把规则的采样纹理打散成细颗粒。
  float rot = fxHash(floor(uv * uRes)) * 6.2832;
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  vec3 acc = vec3(0.);
  float wsum = 0.;
  for (int i = 0; i < 16; i++) {
    float a = float(i) * 2.39996 + rot;
    float r = sqrt((float(i) + .5) / 16.) * aperture(a);
    vec3 s = srcTex(uv + vec2(cos(a), sin(a)) * r * coc * asp).rgb;
    // ③ 高光权重：亮点的能量远大于普通像素（胶片/传感器记录的是线性光），
    //    给亮度的高次方额外权重，亮点就会“撑开”成光斑，而不是被平均掉。
    //    外圈样本再略加权：真实镜头的焦外光斑边缘常有一圈亮边（“肥皂泡”焦外）。
    float w = (1. + boost * pow(fxLuma(s), 4.)) * (1. + .6 * r);
    acc += s * w;
    wsum += w;
  }
  vec3 c = acc / wsum;

  // ④ 焦外光斑的亮度补偿：只把高光（光斑本身）再提亮一点，让光斑清亮；中间调与暗部不变，
  //    否则虚化区整体变亮，清晰的中心反而显得发暗。
  float blurAmt = smoothstep(0., max(radius, .001), coc);
  c += max(c - .6, 0.) * boost * .08 * blurAmt;
  return vec4(c, 1.);
}
