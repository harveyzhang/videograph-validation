/*@effect
{
  "id": "beat-strobe-outline",
  "name": "拍点描边频闪",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["strobe", "outline", "beat", "flash", "edge", "卡点", "描边", "频闪"],
  "summary": "每个鼓点让画面轮廓亮起一道彩色描边并向外扩一圈，随后迅速淡出；只有轮廓在闪、整体亮度不变，所以不会造成全屏频闪。",
  "when": "电子/嘻哈/摇滚的副歌卡点、标题文字砸入、舞蹈与运动镜头的重拍强调。",
  "avoid": "轮廓极多的复杂画面（满屏描边会乱）；安静段落；需要观众长时间阅读的字幕镜头。",
  "params": {
    "flash": { "type": "float", "default": 0, "min": 0, "max": 1.5, "label": "描边亮度（通常由节拍驱动）" },
    "colorA": { "type": "color", "default": "#ff3d7f", "label": "描边颜色 A" },
    "colorB": { "type": "color", "default": "#3dd6ff", "label": "描边颜色 B（隔拍交替）" },
    "spread": { "type": "float", "default": 6, "min": 1, "max": 16, "label": "外扩距离（像素）" },
    "base": { "type": "float", "default": 0.18, "min": 0, "max": 0.6, "label": "平时描边亮度" }
  },
  "bindings": { "flash": { "to": "kick", "amount": 1.1 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：拍点描边/闪白（限频）", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（剪辑手法）：MV 剪辑师在重拍上加一帧“描边闪光”——复制画面、只保留轮廓、加发光、放大一点叠上去再淡出。
// 安全设计：真正的全屏频闪（整屏明暗交替）是光敏风险；这里只有轮廓线在亮，画面平均亮度变化很小，
// 而且每拍只亮一次（120 BPM = 2 次/秒），低于 3 次/秒的安全上限。

float edgeAt(vec2 uv) {
  vec2 o = 1.5 / uRes;
  return abs(fxLuma(srcTex(uv + vec2(o.x, 0.)).rgb) - fxLuma(srcTex(uv - vec2(o.x, 0.)).rgb))
       + abs(fxLuma(srcTex(uv + vec2(0., o.y)).rgb) - fxLuma(srcTex(uv - vec2(0., o.y)).rgb));
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 拍点包络：flash 挂鼓点（瞬间起跳 + 指数衰减）。描边随衰减“向外扩散”：刚起跳时贴着轮廓，衰减时扩出去。
  float env = clamp(flash, 0., 1.5);
  float out1 = spread * (1.2 - min(env, 1.));            // 外扩：包络越弱（越晚）扩得越远

  // ② 取轮廓：原位轮廓 + 以画面中心为原点放大一点后的轮廓（外扩的那一圈），共 8 次采样。
  vec2 c = uv - .5;
  float e0 = smoothstep(.1, .4, edgeAt(uv));
  float e1 = smoothstep(.1, .4, edgeAt(.5 + c / (1. + out1 / uRes.y * 2.)));

  // ③ 交替颜色：奇数拍 A、偶数拍 B（用小节相位判断第几拍），让连续的卡点有变化。
  float beatIdx = floor(uBar * 4.);
  vec3 tint = mod(beatIdx, 2.) < .5 ? colorA : colorB;

  // ④ 合成：平时有很淡的描边（base），鼓点时内圈描边亮起、外圈描边随衰减扩散淡出。描边是加光（screen）。
  float glow = e0 * (base + env * .9) + e1 * env * .6;
  vec3 col = 1. - (1. - src) * (1. - clamp(tint * glow, 0., 1.));
  return vec4(col, 1.);
}
