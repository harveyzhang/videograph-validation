/*@effect
{
  "id": "beat-stutter-freeze",
  "name": "拍点顿挫",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["stutter", "freeze frame", "beat", "stop motion feel", "choppy", "卡顿", "定格", "抽帧", "卡点"],
  "summary": "按拍（或半拍/四分之一拍）给画面一个“咔”的顿挫：拍点处画面猛地放大一点再衰减、上下错一像素，颗粒每个台阶才刷新一次，制造一顿一顿的机械节奏感（注意：后期栈拿不到过去的画面，不是真的抽帧定格）。",
  "when": "嘻哈/舞蹈/运动卡点、定格动画风格、制造机械感与节奏感的段落。",
  "avoid": "需要流畅运动的镜头；想要真正的抽帧定格时请在镜头场景代码里把时间 t 量化到拍点。",
  "params": {
    "division": { "type": "float", "default": 1, "min": 0.25, "max": 4, "label": "每拍更新次数（1 = 每拍、2 = 每半拍）" },
    "bpm": { "type": "float", "default": 120, "min": 40, "max": 240, "label": "歌曲 BPM（用于对齐拍点）" },
    "pop": { "type": "float", "default": 0, "min": 0, "max": 0.08, "label": "拍点放大（通常由节拍驱动）" },
    "grain": { "type": "float", "default": 0.04, "min": 0, "max": 0.15, "label": "定格颗粒" }
  },
  "bindings": { "pop": { "to": "kick", "amount": 0.03 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：抽帧", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（剪辑的“抽帧/stutter”）：把连续的画面每隔一拍才取一张，中间保持不动——运动变成一顿一顿的跳跃，与节拍咬合。
// 后期栈只能拿到“当前时刻”的画面，无法回到过去取帧；所以这里用“定格 = 对齐到拍点的放大与颗粒”近似：
// 画面本身仍在动，但每拍一次的放大冲击与颗粒刷新让观众感到一顿一顿的节奏。真正的抽帧请在镜头场景代码里把 t 量化到拍点。

vec4 effect(vec2 uv) {
  // ① 拍内阶梯：每 1/division 拍一个台阶
  float beatLen = 60. / bpm / max(division, .01);
  float stepIdx = floor(uTime / beatLen);
  float ph = fract(uTime / beatLen);
  // ② 台阶处的“咔”：放大从 pop 衰减到 0（指数），画面轻微上下错位一像素，像胶片卡了一下
  float z = 1. + pop * exp(-ph * 6.) + .01 * step(.5, fxHash(vec2(stepIdx, 1.)));
  vec2 q = (uv - .5) / z + .5 + vec2(0., (fxHash(vec2(stepIdx, 2.)) - .5) * 2. / uRes.y);
  vec3 c = srcTex(q).rgb;
  // ③ 颗粒：每个台阶换一次（同一台阶内静止 = 定格感）
  c += (fxHash(floor(uv * uRes / 2.) + stepIdx * 3.1) - .5) * grain;
  return vec4(c, 1.);
}
