/*@effect
{
  "id": "type-rainbow-flow",
  "name": "彩虹流光字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "rainbow", "gradient", "hue cycle", "pride", "文字", "彩虹", "流光", "渐变字"],
  "summary": "亮色文字填上一条斜向流动的彩虹渐变，颜色沿字不断流过；每拍色带向前推一格。字外的画面不变。",
  "when": "派对/流行/儿童/彩虹主题、直播与综艺花字、电子乐、庆祝与“耶”的时刻。",
  "avoid": "严肃/商务/悲伤题材；需要品牌标准色的字。",
  "params": {
    "scale": { "type": "float", "default": 1.5, "min": 0.2, "max": 8, "label": "彩虹宽度（越大色带越密）" },
    "speed": { "type": "float", "default": 0.3, "min": -2, "max": 2, "label": "流动速度" },
    "saturation": { "type": "float", "default": 0.85, "min": 0, "max": 1, "label": "饱和度" },
    "advance": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "拍点推进（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "advance": { "to": "beat", "amount": 0.25 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：渐变字", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（印刷的“彩虹渐变墨”/综艺花字）：一条连续的色相渐变铺在字上，平移时颜色像在字里流动。
// 色相用连续的余弦调色板生成（无硬接缝），保留原字的明暗起伏以维持字形质感。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkOf(src);
  // ① 色相坐标：斜向 + 时间流动 + 拍点推进
  vec2 p = uv * vec2(uRes.x / uRes.y, 1.);
  float h = (p.x + p.y * .6) * scale - uTime * speed - advance;
  // ② 连续彩虹（余弦调色板）
  vec3 rb = .5 + .5 * cos(6.2832 * (h + vec3(0., .33, .67)));
  rb = mix(vec3(fxLuma(rb)), rb, saturation);
  // ③ 保留原字的明暗（亮的地方更亮），只换色相
  vec3 col = rb * (.55 + .6 * fxLuma(src));
  return vec4(mix(src, col, ink), 1.);
}
