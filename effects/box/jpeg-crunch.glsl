/*@effect
{
  "id": "jpeg-crunch",
  "name": "低码率压缩块",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["jpeg", "compression artifacts", "macroblock", "low bitrate", "deep fried", "压缩块", "低码率", "马赛克噪"],
  "summary": "被压到极低码率的视频：8×8 块状色块、块内只剩几条余弦波纹、边缘有振铃，色度块更大更糊；鼓点时码率骤降，块更粗。",
  "when": "网络梗、讽刺与“过度转发”的画面、迷因风剪辑、低保真/蒸汽波、表现网络卡顿。",
  "avoid": "正式的品牌宣传；需要细节与字的镜头；与 pixel-art 叠用（两种块打架）。",
  "params": {
    "quality": { "type": "float", "default": 0.35, "min": 0.05, "max": 1, "label": "画质（越低块越明显）" },
    "chromaBlock": { "type": "float", "default": 2, "min": 1, "max": 4, "label": "色度块倍数" },
    "ringing": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "边缘振铃" },
    "blockPx": { "type": "float", "default": 8, "min": 4, "max": 24, "label": "块大小（像素）" }
  },
  "bindings": { "quality": { "to": "kick", "amount": -0.25 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：压缩伪影/低保真", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：JPEG/H.264 把画面切成 8×8 的块，每块做离散余弦变换（DCT），只保留低频系数、高频按码率丢掉。
// 码率越低：块内只剩平均色 + 一两条最低频的明暗渐变；块与块之间的边界接不上（块效应）；
// 锐利边缘附近因丢掉高频出现一圈波纹（振铃）；色度先被降到半分辨率（4:2:0），颜色块是亮度块的两倍大。
// 和 pixel-art（均匀像素格 + 调色板抖动）不同：这里块内有渐变和振铃，块边缘不齐。

vec4 effect(vec2 uv) {
  // quality 挂鼓点（负值）：鼓点那一下码率骤降，块更粗、波纹更少，随后恢复。
  float q = clamp(quality, .05, 1.);
  float bpx = blockPx;
  vec2 px = uv * uRes;

  // ① 亮度块：所在 8×8 块的四个角 + 中心取样（5 次），拟合“平均值 + 横向/纵向最低频余弦”——这就是 DCT 只留前 3 个系数。
  vec2 b0 = floor(px / bpx) * bpx;
  vec2 f = (px - b0) / bpx;                       // 块内 0..1
  float lC = fxLuma(srcTex((b0 + bpx * .5) / uRes).rgb);
  float lL = fxLuma(srcTex((b0 + vec2(bpx * .15, bpx * .5)) / uRes).rgb);
  float lR = fxLuma(srcTex((b0 + vec2(bpx * .85, bpx * .5)) / uRes).rgb);
  float lD = fxLuma(srcTex((b0 + vec2(bpx * .5, bpx * .15)) / uRes).rgb);
  float lU = fxLuma(srcTex((b0 + vec2(bpx * .5, bpx * .85)) / uRes).rgb);
  float dc = (lC * 2. + lL + lR + lD + lU) / 6.;
  float acX = (lL - lR) * .5, acY = (lD - lU) * .5;
  // 系数量化：码率越低量化步长越大（系数被“取整”得越狠）
  float stepQ = mix(.25, .03, q);
  dc = floor(dc / (stepQ * .5) + .5) * stepQ * .5;
  acX = floor(acX / stepQ + .5) * stepQ;
  acY = floor(acY / stepQ + .5) * stepQ;
  float luma = dc + acX * cos(f.x * 3.1416) + acY * cos(f.y * 3.1416);

  // ② 振铃：被丢掉的高频在边缘留下一圈波纹——块内存在强梯度时，叠加一个更高频的余弦。
  float edge = abs(lL - lR) + abs(lD - lU);
  luma += ringing * smoothstep(.15, .6, edge) * .06 * (cos(f.x * 9.42) + cos(f.y * 9.42)) * (1. - q);

  // ③ 色度块：颜色按更大的块（chromaBlock 倍）只取一个平均（4:2:0 降采样），再量化（2 次采样）。
  float cpx = bpx * floor(chromaBlock + .5);
  vec2 c0 = floor(px / cpx) * cpx;
  vec3 cs = (srcTex((c0 + cpx * .3) / uRes).rgb + srcTex((c0 + cpx * .7) / uRes).rgb) * .5;
  vec3 chroma = cs - fxLuma(cs);
  chroma = floor(chroma / (stepQ * .6) + .5) * stepQ * .6;

  // ④ 重建：亮度 + 色度；块边界略微接不上（每块的 dc 量化误差不同已经造成台阶）。
  vec3 c = clamp(vec3(luma) + chroma * 1.1, 0., 1.);

  // ⑤ 低码率还会把高光压平、整体略偏灰（码率分给了平均色）。
  c = mix(c, vec3(fxLuma(c)), (1. - q) * .1);
  return vec4(c, 1.);
}
