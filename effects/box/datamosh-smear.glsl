/*@effect
{
  "id": "datamosh-smear",
  "name": "数据弯曲拖影",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["datamosh", "databending", "compression", "p-frame", "pixel drift", "数据弯曲", "关键帧丢失", "拖影"],
  "summary": "像视频丢了关键帧：画面按压缩块被运动矢量一块块“推着走”，颜色从旧位置拖出彩色涂抹和块状边界；鼓点时拖得最远，平时缓慢流动。",
  "when": "电子/实验音乐、迷幻转折、网络文化与故障艺术、表现“记忆崩坏/现实融化”。",
  "avoid": "需要清晰内容的镜头；与 glitch-blocks 连用会重复（那个是块状错位跳变，这个是连续流动的涂抹）。",
  "params": {
    "drift": { "type": "float", "default": 0.04, "min": 0, "max": 0.15, "label": "拖动距离" },
    "block": { "type": "float", "default": 16, "min": 8, "max": 48, "label": "压缩块大小（像素）" },
    "bleed": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "色度溢出" },
    "keep": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "保留原画面" }
  },
  "bindings": { "drift": { "to": "kick", "amount": 0.06 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：数据故障/拖影", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：压缩视频大多数帧（P 帧）不存画面，只存“每个宏块从上一帧哪里搬过来”（运动矢量）。
// 删掉关键帧后，解码器把新镜头的运动矢量用在旧画面上，于是旧画面的像素被一块一块推着流动，
// 块边界清楚，颜色在流动方向上拉成涂抹；色度分辨率比亮度低，所以颜色溢出得比明暗更远。
// （本效果无帧间状态：用“沿运动矢量回溯多步取样”近似连续多帧的累积搬运。）

vec2 motion(vec2 cell, float t) {
  // 每个宏块的运动矢量：大尺度的流场（相邻块方向相近）+ 少量随机块乱跑；随时间缓慢变化。
  vec2 flow = vec2(fxNoise(cell * .15 + t * .2), fxNoise(cell * .15 + 9. - t * .17)) - .5;
  vec2 rnd = vec2(fxHash(cell + floor(t)), fxHash(cell + 3. + floor(t))) - .5;
  return normalize(flow + rnd * .6 + 1e-4) * (.6 + .8 * fxHash(cell + 7.));
}

vec4 effect(vec2 uv) {
  // ① 宏块划分：画面按 block 像素分块，同一块内所有像素共用一个运动矢量（块状边界的来源）。
  vec2 cell = floor(uv * uRes / block);
  vec2 mv = motion(cell, uTime * .5);
  vec2 asp = vec2(uRes.y / uRes.x, 1.);

  // ② 多帧累积搬运：沿运动矢量往回走 6 步，每一步都是“上一帧”的画面；越早的帧权重越低。
  //    drift 挂鼓点：鼓点那一下矢量被放大，像整段丢帧，画面被拖得最远。
  vec3 acc = vec3(0.);
  float wsum = 0.;
  for (int i = 0; i < 6; i++) {
    float t = float(i) / 5.;
    vec2 p = uv - mv * drift * t * asp;
    float w = 1. - t * .6;
    acc += srcTex(p).rgb * w;
    wsum += w;
  }
  vec3 smear = acc / wsum;

  // ③ 色度溢出：颜色（色度）在运动方向上额外再拖远一截（3 次采样），而明暗（亮度）保持块内的值。
  vec3 far = (srcTex(uv - mv * drift * 1.4 * asp).rgb + srcTex(uv - mv * drift * 1.8 * asp).rgb + srcTex(uv - mv * drift * 2.2 * asp).rgb) / 3.;
  float ly = fxLuma(smear);
  vec3 chroma = mix(smear - ly, far - fxLuma(far), bleed);
  vec3 moshed = ly + chroma * 1.25;

  // ④ 块边界：宏块边上有一条细的“接缝”，块内亮度略有台阶（量化误差）。
  vec2 f = fract(uv * uRes / block);
  float seam = step(f.x, 1. / block) + step(f.y, 1. / block);
  moshed *= 1. - seam * .08;
  moshed = floor(moshed * 24.) / 24.;

  // ⑤ 混合：一部分块已经刷新到当前帧（保留原画面），按块随机决定，每秒变一次。
  float fresh = step(1. - keep, fxHash(cell + floor(uTime * 1.) * 5.3));
  vec3 c = mix(moshed, srcTex(uv).rgb, fresh * .85);
  return vec4(c, 1.);
}
