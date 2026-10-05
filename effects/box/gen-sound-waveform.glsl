/*@effect
{
  "id": "gen-sound-waveform",
  "name": "声波线",
  "kind": "post",
  "category": "生成层",
  "tags": ["waveform", "audio wave", "sound line", "podcast", "visualizer", "声波", "波形", "音频可视化", "播客"],
  "summary": "画面中部（或底部）横贯一条发光的声波线：多条相位不同的正弦叠加成起伏的波形，振幅随音乐能量与鼓点涨落，两端渐隐；可选上下镜像成对称的“声纹”。",
  "when": "播客/电台/语音、音乐可视化与歌词视频、AI 语音助手、科技发布会。",
  "avoid": "需要波形与真实音频逐样本一致的场合（这里由节拍与能量驱动，是装饰性的波形）。",
  "params": {
    "posY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "位置 Y" },
    "amp": { "type": "float", "default": 0.06, "min": 0, "max": 0.3, "label": "基础振幅" },
    "level": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "能量（通常由音乐能量驱动）" },
    "punch": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点涨幅（通常由节拍驱动）" },
    "mirror": { "type": "bool", "default": true, "label": "上下镜像" },
    "colorA": { "type": "color", "default": "#4fe3ff", "label": "颜色 A" },
    "colorB": { "type": "color", "default": "#b45bff", "label": "颜色 B" }
  },
  "bindings": { "level": { "to": "energy", "amount": 0.5 }, "punch": { "to": "kick", "amount": 0.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：音频可视化", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（示波器/录音软件的波形显示）：声音的波形是许多频率叠加的振动，响的时候振幅大、安静时几乎是一条直线。
// 宿主没有逐样本音频数据，这里用几条不同频率、随时间移动的正弦叠加出“像声音”的波形，振幅由能量与鼓点控制。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float x = uv.x;
  // ① 波形：5 个频率叠加，各自以不同速度移动
  float t = uTime;
  float w = sin(x * 18. + t * 5.) * .5 + sin(x * 41. - t * 7.) * .25 + sin(x * 7. + t * 2.) * .6 + sin(x * 83. + t * 11.) * .12 + (fxNoise(vec2(x * 60., t * 3.)) - .5) * .4;
  // ② 振幅：能量 + 鼓点，两端渐隐
  float env = sin(x * 3.1416);
  float A = amp * (.3 + level * 1.2 + punch * 1.5) * env * env;
  float y = uv.y - posY;
  float d = abs(y - w * A);
  float px = 1.5 / uRes.y;
  float line = smoothstep(px * 1.5, 0., d) + exp(-d / (px * 8.)) * .4;
  if (mirror) { float d2 = abs(y + w * A); line += smoothstep(px * 1.5, 0., d2) * .7 + exp(-d2 / (px * 8.)) * .25; line += smoothstep(abs(w * A), 0., abs(y)) * .08; }
  vec3 col = mix(colorA, colorB, x);
  vec3 c = 1. - (1. - src) * (1. - clamp(col * line, 0., 1.));
  return vec4(c, 1.);
}
