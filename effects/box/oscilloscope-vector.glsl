/*@effect
{
  "id": "oscilloscope-vector",
  "name": "示波器矢量",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["oscilloscope", "vector display", "phosphor", "xy scope", "lissajous", "示波器", "矢量显示", "荧光"],
  "summary": "画面只剩轮廓，像被示波器的电子束描在绿色荧光屏上：线条发光、亮处有过曝白芯、带余辉拖尾，背景是刻度网格；鼓点时电子束电压一冲。",
  "when": "科幻、实验电子乐、复古科技与科研、雷达/控制室场景、“信号”主题。",
  "avoid": "画面轮廓很多很碎时会变成一团乱线；需要颜色或面积感的镜头。",
  "params": {
    "phosphor": { "type": "color", "default": "#3dff8a", "label": "荧光粉颜色" },
    "beam": { "type": "float", "default": 1, "min": 0.3, "max": 2.5, "label": "电子束亮度" },
    "persistence": { "type": "float", "default": 0.012, "min": 0, "max": 0.04, "label": "余辉拖尾" },
    "graticule": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "刻度网格" }
  },
  "bindings": { "beam": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：发光线条/矢量屏", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：示波器/矢量显示器没有像素，电子束直接在荧光屏上“画线”：束流打到的地方发光，
// 束流越强线越亮，过强时线芯发白；荧光粉有余辉，电子束离开后光会慢慢衰减（留下拖尾）；
// 屏幕前有一片刻着网格的玻璃（graticule）用来读数。和 neon-edges（彩色霓虹描边）不同：
// 这里是单色荧光 + 白热线芯 + 余辉 + 刻度，是仪器的质感。

float trace(vec2 uv) {
  // 电子束轨迹 = 画面轮廓：两点差分梯度（4 次采样），细而锐。
  vec2 o = 1.2 / uRes;
  float gx = fxLuma(srcTex(uv + vec2(o.x, 0.)).rgb) - fxLuma(srcTex(uv - vec2(o.x, 0.)).rgb);
  float gy = fxLuma(srcTex(uv + vec2(0., o.y)).rgb) - fxLuma(srcTex(uv - vec2(0., o.y)).rgb);
  return smoothstep(.06, .35, abs(gx) + abs(gy));
}

vec4 effect(vec2 uv) {
  // ① 电子束描线：当前位置的轮廓强度。
  float t0 = trace(uv);

  // ② 余辉：电子束沿着轮廓移动，刚扫过的地方还亮着。用“稍早时刻”的位置（沿一个缓慢旋转的方向偏移）取两次，
  //    逐级变暗，形成拖尾（共 3 × 4 = 12 次采样）。
  vec2 dir = vec2(cos(uTime * .7), sin(uTime * .7)) * persistence;
  float t1 = trace(uv + dir * .5);
  float t2 = trace(uv + dir);
  float glowLine = max(t0, max(t1 * .55, t2 * .3));

  // ③ 荧光与辉光：线条中心按束流强度从荧光色过渡到白（过曝），周围是同色的柔光。
  //    beam 挂鼓点：鼓点那一下电子束电压一冲，线条更亮更粗。
  float core = smoothstep(.6, 1., t0) * beam;
  vec3 col = phosphor * glowLine * beam * 1.2 + vec3(1.) * core * .45;

  // ④ 刻度网格：10×8 大格 + 每大格 5 条小刻度（只在中心十字线上）；网格是玻璃上的刻线，暗淡、略带荧光色。
  vec2 g = uv * vec2(10., 8.);
  vec2 gd = abs(fract(g) - .5);
  vec2 lw = fwidth(g) * 1.2;
  float grid = max(smoothstep(.5 - lw.x, .5, gd.x), smoothstep(.5 - lw.y, .5, gd.y));
  vec2 cd = abs(uv - .5) * vec2(10., 8.);
  float ticks = (step(cd.y, .08) * step(.42, abs(fract(uv.x * 50.) - .5)) + step(cd.x, .08) * step(.42, abs(fract(uv.y * 40.) - .5)));
  col += phosphor * (grid * .12 + ticks * .15) * graticule;

  // ⑤ 荧光屏底：不是纯黑，有一点点荧光粉本身的绿灰色和中心略亮的不均匀。
  col += phosphor * .02 * (1. - length(uv - .5));
  return vec4(col, 1.);
}
