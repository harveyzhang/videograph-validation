/*@effect
{
  "id": "type-stroke-draw",
  "name": "描边生长",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "stroke", "draw on", "write on", "outline reveal", "文字动画", "描边", "书写", "线条生长"],
  "summary": "文字先以发光的描边从左到右“写”出来，笔头处有一颗亮点，描边写完后字的实心部分再淡入；结尾描边从右往左收回。鼓点时笔头更亮。",
  "when": "Logo 与标题演绎、签名/手写感片头、科技线框风、品牌名揭示。",
  "avoid": "画面主体不是清晰的字形或图标（描边会画出一堆杂乱轮廓）；字极小。",
  "params": {
    "inEnd": { "type": "float", "default": 0.45, "min": 0.1, "max": 0.9, "label": "实心淡入完成于镜头进度" },
    "outStart": { "type": "float", "default": 0.92, "min": 0.4, "max": 1, "label": "收回开始（1 = 不收回）" },
    "width": { "type": "float", "default": 2.5, "min": 1, "max": 8, "label": "描边粗细（像素）" },
    "glow": { "type": "float", "default": 0.5, "min": 0, "max": 2, "label": "笔头亮度（通常由节拍驱动）" },
    "lineColor": { "type": "color", "default": "#ffb36b", "label": "描边颜色" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.1, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "glow": { "to": "kick", "amount": 0.9 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/one-line 与 whiteboard：一笔书写", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（AE 的 Trim Paths / 描边动画）：设计师把字转成路径，让描边从 0% 长度生长到 100%，笔头处常加一个亮点；
// 描边写完后实心填色再淡入。没有矢量路径时，这里用“字形边缘 + 从左到右的书写前沿（带一点手写的波动）”近似这一过程。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 字形边缘（4 次采样）与实心（1 次）。
  vec2 o = width / uRes;
  float front = inkAt(uv);
  float edge = clamp(abs(inkAt(uv + vec2(o.x, 0.)) - inkAt(uv - vec2(o.x, 0.))) + abs(inkAt(uv + vec2(0., o.y)) - inkAt(uv - vec2(0., o.y))), 0., 1.);

  // ② 书写前沿：入场前 60% 的时间里从左写到右；前沿不是直线，而是随高度和噪声起伏（像手写一笔一笔推进）。
  float p = uProgress;
  float drawT = clamp(p / (inEnd * .6), 0., 1.);
  float outT = outStart < .999 ? clamp((p - outStart) / (1. - outStart), 0., 1.) : 0.;
  float lead = (uv.x + (fxNoise(uv * vec2(3., 9.)) - .5) * .08);
  float frontPos = drawT * 1.15 - .05 - outT * 1.2;
  float drawn = step(lead, frontPos) * step(lead, 1.15 - outT * 1.2);   // 收回时从右往左擦掉
  drawn = outT > 0. ? step(lead, 1.1 - outT * 1.2) : step(lead, frontPos);

  // ③ 笔头：前沿附近的描边更亮（像墨还湿着/激光正在刻），glow 挂鼓点。
  float tip = exp(-pow((lead - frontPos) * 30., 2.)) * step(drawT, .999) * (1. - step(.001, outT));

  // ④ 实心淡入：描边写完后（后 40% 入场时间）字的实心部分淡入；收回时实心先淡出。
  float fillA = clamp((p - inEnd * .6) / (inEnd * .4), 0., 1.) * (1. - clamp(outT * 3., 0., 1.));

  // ⑤ 合成：背景（原画面去掉字：字的位置先压成背景暗色）→ 实心字淡入 → 发光描边 → 笔头。
  vec3 c = mix(src, src * .08, front * (1. - fillA));
  c += lineColor * edge * drawn * (.9 + tip * glow * 1.5);
  c += lineColor * tip * edge * glow * .5;
  return vec4(c, 1.);
}
