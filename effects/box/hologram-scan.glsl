/*@effect
{
  "id": "hologram-scan",
  "name": "全息扫描",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["hologram", "hud", "scan", "sci-fi", "projection", "全息", "投影", "扫描"],
  "summary": "画面变成青蓝色半透明的全息投影：细密扫描线、轮廓发光、一道扫描光带反复自下而上扫过，鼓点时信号抖一下。",
  "when": "科幻、AI/科技产品、作战简报、角色“远程通话”、数据可视化标题。",
  "avoid": "需要准确颜色的产品镜头；温情/自然题材；画面已有大量细线时扫描线会产生摩尔纹（调大线距）。",
  "params": {
    "color": { "type": "color", "default": "#3fe0ff", "label": "投影色" },
    "lineGap": { "type": "float", "default": 3, "min": 2, "max": 10, "label": "扫描线间距（像素）" },
    "scanSpeed": { "type": "float", "default": 0.4, "min": 0, "max": 2, "label": "扫描光带速度（次/秒）" },
    "jitter": { "type": "float", "default": 0.002, "min": 0, "max": 0.03, "label": "信号抖动" },
    "transparency": { "type": "float", "default": 0.35, "min": 0, "max": 0.9, "label": "透明度" }
  },
  "bindings": { "jitter": { "to": "kick", "amount": 0.012 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/hologram-hud 与 scifi-toon", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 电影里的全息投影是这样“产生”的：投影器逐行扫描出单色光（所以有扫描线、只有一种颜色），
// 光打在空气里（所以是半透明的，暗部直接透出背后的黑），信号不稳时一些行会左右错开，
// 投影器刷新时一道更亮的光带扫过；物体轮廓处光叠得更厚，看起来边缘发亮（类菲涅尔）。

vec4 effect(vec2 uv) {
  // ① 信号抖动：按行（约 6 像素一组）随机左右错开，错开的行随时间换（每秒 8 次，只是局部的细条）。
  //    jitter 挂鼓点：鼓点那一帧整组行明显撕开，然后迅速恢复。
  float row = floor(uv.y * uRes.y / 6.);
  float tear = (fxHash(vec2(row, floor(uTime * 8.))) - .5) * step(.8, fxHash(vec2(row * .37, floor(uTime * 8.) + 3.)));
  vec2 u = uv + vec2(tear * jitter * 6. + sin(uv.y * 40. + uTime * 3.) * jitter * .15, 0.);

  // ② 单色投影：取亮度，压成投影色的明暗；暗部越暗越透明（直接透出背后的黑）。
  float l = fxLuma(srcTex(u).rgb);
  float lr = fxLuma(srcTex(u + vec2(1.5 / uRes.x, 0.)).rgb);
  float lu = fxLuma(srcTex(u + vec2(0., 1.5 / uRes.y)).rgb);

  // ③ 轮廓发亮：光在物体边缘叠得更厚（2 次额外采样求梯度）。
  float edge = clamp((abs(l - lr) + abs(l - lu)) * 4., 0., 1.);
  float body = smoothstep(.05, .9, l);

  // ④ 逐行扫描：细密扫描线（随时间缓慢上移），线间是空的。
  float scan = .55 + .45 * sin((uv.y * uRes.y / lineGap + uTime * 4.) * 3.1416);

  // ⑤ 刷新光带：一道柔和的亮带自下而上扫过，光带后面拖一点余辉。
  float bandPos = fract(uTime * scanSpeed) * 1.4 - .2;
  float dy = uv.y - bandPos;
  float band = exp(-dy * dy * 900.) + smoothstep(-.25, 0., dy) * step(dy, 0.) * .25;

  // ⑥ 合成：投影光 = 投影色 × （主体 × 扫描线 + 轮廓 + 光带）；背景是很暗的蓝黑并透出一点原图（透明度）。
  float lum = body * scan * (1. - transparency * .5) + edge * .9 + band * (.25 + body * .6);
  vec3 holo = color * lum + vec3(.8, 1., 1.) * edge * band * .5;
  vec3 bg = vec3(.01, .03, .05) + srcTex(uv).rgb * .12 * transparency;
  float grain = (fxHash(floor(uv * uRes) + floor(uTime * 24.)) - .5) * .04;   // 投影光里的细微颗粒（极低幅度）
  return vec4(bg + holo + grain * color, 1.);
}
