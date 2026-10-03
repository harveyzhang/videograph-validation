/*@effect
{
  "id": "rgb-tear-cut",
  "name": "RGB 撕裂切换",
  "kind": "transition",
  "category": "转场",
  "tags": ["glitch", "rgb split", "tear", "digital cut", "cyber", "故障转场", "RGB 分离", "撕裂", "数字切换"],
  "summary": "切换时画面被横向撕成很多条，每条红/绿/蓝通道各自向不同方向错开，新旧镜头的条带交错闪现，几帧之后整齐地合成到下一个镜头。",
  "when": "赛博朋克/电子乐/游戏、科技发布、信号切换的叙事、卡点硬切的加强版。",
  "avoid": "温柔抒情的衔接；对闪烁敏感的观众（条带交错仅在中段约 0.2 秒内）。时长建议 0.3–0.6 秒。",
  "params": {
    "strips": { "type": "float", "default": 18, "min": 4, "max": 60, "label": "撕裂条数" },
    "shift": { "type": "float", "default": 0.08, "min": 0, "max": 0.3, "label": "最大错开" },
    "split": { "type": "float", "default": 0.02, "min": 0, "max": 0.06, "label": "通道分离" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：故障转场", "note": "按思路自写；与 gl-transitions 的 GlitchDisplace/GlitchMemories 不同：按条带交错新旧镜头 + 三通道独立错位" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（数字故障美学）：信号切换时，解码器在两路信号之间短暂混乱——有的扫描行来自旧画面、有的来自新画面，
// 三原色通道也没对齐。这种混乱只持续几帧，然后新画面稳定下来。

vec4 transition(vec2 uv) {
  float p = progress;
  // ① 混乱程度：中间最乱（钟形包络）
  float chaos = sin(p * 3.1416);
  chaos = chaos * chaos;
  float s = floor(uv.y * strips);
  float seed = floor(p * 20.);                            // 每 5% 进度换一组撕裂（时间上是几帧一跳）
  // ② 每条来自新还是旧镜头：随进度越来越多的条来自新镜头
  float useNew = step(fxHash(vec2(s, seed)) * .9 + .05, p);
  // ③ 错开与通道分离
  float off = (fxHash(vec2(s, seed + 3.)) - .5) * 2. * shift * chaos;
  float sp = split * chaos;
  vec2 q = vec2(uv.x + off, uv.y);
  vec3 c;
  if (useNew > .5) c = vec3(getToColor(q + vec2(sp, 0.)).r, getToColor(q).g, getToColor(q - vec2(sp, 0.)).b);
  else c = vec3(getFromColor(q + vec2(sp, 0.)).r, getFromColor(q).g, getFromColor(q - vec2(sp, 0.)).b);
  // ④ 少量条带变成扫描线噪声（局部、很淡）
  c = mix(c, vec3(fxHash(vec2(floor(uv.x * uRes.x / 3.), s + seed))), step(.94, fxHash(vec2(s, seed + 9.))) * chaos * .5);
  return vec4(c, 1.);
}
