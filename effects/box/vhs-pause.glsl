/*@effect
{
  "id": "vhs-pause",
  "name": "录像带暂停",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["vhs pause", "tracking", "freeze", "noise bar", "retro", "录像带暂停", "跟踪噪带", "复古", "定格"],
  "summary": "像按下录像机的暂停键：画面上下轻微抖动，一两条带噪点的白色跟踪干扰带横在画面里缓慢游走，带附近的画面被横向撕扯，右上角显示“PAUSE”与双竖线图标；鼓点时干扰带跳一下。",
  "when": "复古回忆、“暂停一下”的叙事节点、搞笑定格、蒸汽波与 90 年代怀旧。",
  "avoid": "现代精致的商业画面；与 vhs-tape（播放中的磁带质感）同时使用会重复。",
  "params": {
    "bars": { "type": "float", "default": 1, "min": 1, "max": 4, "label": "干扰带条数" },
    "barH": { "type": "float", "default": 0.025, "min": 0.01, "max": 0.15, "label": "干扰带高度" },
    "jitter": { "type": "float", "default": 0.004, "min": 0, "max": 0.02, "label": "上下抖动" },
    "label": { "type": "bool", "default": true, "label": "显示 PAUSE 字样" },
    "jump": { "type": "float", "default": 0, "min": 0, "max": 0.3, "label": "鼓点跳带（通常由节拍驱动）" }
  },
  "bindings": { "jump": { "to": "kick", "amount": 0.12 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/ascii-crt：录像带界面", "note": "只参考风格名称与观感描述；PAUSE 字样为本项目自绘点阵" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：VHS 暂停时，磁头停在一条磁迹上反复读取，但磁头与磁迹不完全对齐，于是画面上出现一两条噪声干扰带（跟踪误差），
// 整个画面上下轻颤；录像机还会在屏幕角落叠上“PAUSE”字样。

// 5×7 点阵的 P A U S E（本项目自绘）
const int PA[5] = int[5](509487, 1033774, 575025, 459838, 492607);
const int PB[5] = int[5](1057, 17969, 14897, 15888, 31777);

float pauseText(vec2 px, vec2 o, float dp) {
  vec2 q = (px - o) / dp;
  if (q.y < 0. || q.y >= 7. || q.x < 0. || q.x >= 30.) return 0.;
  int i = int(floor(q.x / 6.));
  int col = int(floor(q.x)) - i * 6, row = int(floor(q.y));
  if (col > 4) return 0.;
  int bits = row < 4 ? PA[i] : PB[i];
  int idx = row < 4 ? row * 5 + col : (row - 4) * 5 + col;
  return float((bits >> idx) & 1);
}

vec4 effect(vec2 uv) {
  float frame = floor(uTime * 30.);
  // ① 上下轻颤（按帧跳动）
  float dy = (fxHash(vec2(frame, 1.)) - .5) * jitter * 2.;
  vec2 q = uv + vec2(0., dy);
  // ② 干扰带：缓慢向下游走，鼓点时位置跳一下
  float band = 0.;
  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    if (fi >= bars) break;
    float y0 = fract(.3 + fi * .37 - uTime * .04 + jump * fxHash(vec2(fi, floor(uTime * 2.))));
    band = max(band, smoothstep(barH, 0., abs(q.y - y0)));
  }
  // ③ 带附近横向撕扯（每行不同偏移，按帧变化）
  float row = floor(q.y * uRes.y / 2.);
  q.x += band * (fxHash(vec2(row, frame)) - .5) * .06;
  vec3 c = srcTex(q).rgb;
  // ④ 干扰带：白色噪点 + 略提亮
  float noise = fxHash(vec2(floor(uv.x * uRes.x / 2.), row + frame * 13.));
  c = mix(c, vec3(noise * .9 + .1), band * .55 * step(.55, noise));
  // ⑤ PAUSE 字样与双竖线（右上角，白色带黑描边感）
  if (label) {
    vec2 px = vec2(uv.x, 1. - uv.y) * uRes;
    float dp = uRes.y * .006;
    vec2 o = vec2(uRes.x - dp * 30. - uRes.y * .06, uRes.y * .06);
    float t = pauseText(px, o, dp);
    vec2 io = o - vec2(dp * 7., 0.);
    float icon = (step(abs(px.x - io.x - dp), dp * .8) + step(abs(px.x - io.x - dp * 4.), dp * .8)) * step(io.y, px.y) * step(px.y, io.y + dp * 7.);
    c = mix(c, vec3(.95), clamp(t + icon, 0., 1.));
  }
  return vec4(c, 1.);
}
