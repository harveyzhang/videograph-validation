/*@effect
{
  "id": "type-cut-out-paper",
  "name": "剪纸贴字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "paper cutout", "sticker", "collage", "handmade", "文字", "剪纸", "贴纸", "拼贴"],
  "summary": "亮色文字变成剪下来贴在画面上的彩色卡纸字：带一圈白色的剪刀留边、纸张纤维纹理、右下方的投影和轻微的不平整；每个鼓点字像被按了一下（投影变短）。",
  "when": "手作/拼贴/zine 风格、儿童与教育、可爱的品牌、vlog 标题、复古剪报。",
  "avoid": "精致的高端品牌；很细的字体（留边会糊在一起）。",
  "params": {
    "paperColor": { "type": "color", "default": "#ffcf3f", "label": "卡纸颜色" },
    "border": { "type": "float", "default": 0.006, "min": 0, "max": 0.02, "label": "白边宽度（画面高度比例）" },
    "shadow": { "type": "float", "default": 0.008, "min": 0, "max": 0.03, "label": "投影距离" },
    "press": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点按压（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "press": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/paper-popup 与 papercut-red：剪纸质感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：用剪刀把字从彩色卡纸上剪下来，剪的时候沿字外面留一圈白边（像贴纸）；贴到画面上时纸片微微翘起，
// 在下面投出一道柔和的影子；纸面有纤维纹理。按一下纸片，它贴得更平，影子变短。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.y / uRes.x, 1.);
  float front = inkAt(uv);
  // ① 白边：在字外 border 半径内找字（8 个方向）→ 留边区域
  float rim = 0.;
  for (int i = 0; i < 8; i++) { float a = float(i) * .7854; rim = max(rim, inkAt(uv + vec2(cos(a), sin(a)) * border * asp)); }
  // 剪刀不规则：留边边缘用噪声扰动
  float cut = step(.5, rim * (.8 + .4 * fxNoise(uv * uRes * .05)));
  // ② 投影：整个纸片（字 + 白边）向右下偏移；按压时影子变短
  float sd = shadow * (1. - press * .6);
  float shPiece = 0.;
  for (int i = 0; i < 4; i++) { float a = float(i) * 1.5708; shPiece = max(shPiece, inkAt(uv - vec2(sd, -sd) * vec2(asp.x, 1.) + vec2(cos(a), sin(a)) * border * asp)); }
  vec3 c = src * (1. - .45 * shPiece * (1. - cut));
  // ③ 纸片：白边（米白）+ 字（卡纸色），纸纤维 + 轻微不平整的明暗
  float fiber = .93 + .07 * fxNoise(uv * uRes * vec2(.3, .8));
  float bend = .96 + .06 * fxNoise(uv * 6.);
  vec3 piece = mix(vec3(.97, .95, .9), paperColor, front) * fiber * bend;
  c = mix(c, piece, max(cut, front));
  return vec4(c, 1.);
}
