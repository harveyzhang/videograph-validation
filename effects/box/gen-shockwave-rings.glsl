/*@effect
{
  "id": "gen-shockwave-rings",
  "name": "冲击波圆环",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["shockwave", "rings", "pulse", "beat", "sonar ping", "冲击波", "圆环", "脉冲", "卡点"],
  "summary": "每个拍点从画面中心放出一圈细细的发光圆环，向外扩大并变淡，同时多圈叠在一起像声波；鼓点那圈最粗最亮。只画圆环，不扭曲画面。",
  "when": "电子/嘻哈卡点、Logo 落版、“信号发出”的意象、副歌节奏强调。",
  "avoid": "安静的段落；中心是人脸的特写（圆环穿过脸，调 centerX/centerY）。",
  "params": {
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y" },
    "speed": { "type": "float", "default": 0.9, "min": 0.2, "max": 3, "label": "扩散速度（每拍扩散的画面高度倍数）" },
    "width": { "type": "float", "default": 0.006, "min": 0.001, "max": 0.02, "label": "圆环粗细" },
    "punch": { "type": "float", "default": 0, "min": 0, "max": 1.5, "label": "鼓点那圈加强（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#ffffff", "label": "圆环颜色" }
  },
  "bindings": { "punch": { "to": "kick", "amount": 1 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：拍点圆环", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（动态图形的“脉冲圆环”）：每个节拍从中心放出一个圆环，像声音的波前或雷达的 ping；
// 圆环越往外越大越淡，前几拍的圆环还在外圈继续扩散，于是画面里同时有几圈。和 kick-ripple 不同：这里只画线，不折射画面。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 d = (uv - vec2(centerX, centerY)) * vec2(uRes.x / uRes.y, 1.);
  float r = length(d);
  float light = 0.;
  // ① 当前拍与前 3 拍各一圈：半径 = (拍内相位 + 拍数) × 速度
  for (int i = 0; i < 4; i++) {
    float age = uBeat + float(i);
    float R = age * speed * .5;
    float fade = exp(-age * 1.2);
    // ② 鼓点那圈（i = 0）更粗更亮（punch 挂 kick）
    float w = width * (1. + (i == 0 ? punch * 2. : 0.)) * (1. + age * .5);
    light += smoothstep(w, 0., abs(r - R)) * fade * (1. + (i == 0 ? punch : 0.));
    light += exp(-abs(r - R) / (w * 6.)) * fade * .15;
  }
  vec3 c = 1. - (1. - src) * (1. - clamp(color * light, 0., 1.));
  return vec4(c, 1.);
}
