/*@effect
{
  "id": "type-glitch-slice",
  "name": "文字切片故障",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "glitch", "slice", "rgb split", "cyberpunk", "文字", "故障", "切片", "错位"],
  "summary": "只对文字做故障：文字被横切成几条，在鼓点上各自向左右错开并分离出红/青两色重影，随后迅速归位；背景保持不动。",
  "when": "赛博朋克/电子乐/游戏的标题与歌词、口号强调、科技发布、信号干扰的叙事。",
  "avoid": "文字压在复杂背景上（文字错开后的原位用补底色填）；需要长时间安静阅读的字幕。",
  "params": {
    "amount": { "type": "float", "default": 0.1, "min": 0, "max": 1, "label": "故障强度（通常由节拍驱动）" },
    "slices": { "type": "float", "default": 9, "min": 2, "max": 40, "label": "切片数（每屏高）" },
    "shift": { "type": "float", "default": 0.05, "min": 0, "max": 0.2, "label": "最大错开距离" },
    "split": { "type": "float", "default": 0.008, "min": 0, "max": 0.03, "label": "色彩分离" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "文字原位的补底色" }
  },
  "bindings": { "amount": { "to": "kick", "amount": 0.9 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：文字故障", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（数字故障美学）：视频信号的行同步出错时，一段段扫描行会整体左右错开，三原色通道也可能错位；
// 设计师把这种错误只施加在文字上，让字“被干扰”，背景保持干净。和 glitch-blocks（全画面块状故障）不同，这里只动字。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 切片：横向切成 slices 条，每条的错开量 = 随机方向 × 随机大小；每 1/12 秒换一组（只有部分切片会动）。
  float sl = floor(uv.y * slices);
  float seed = floor(uTime * 12.);
  float moving = step(fxHash(vec2(sl, seed)), .35 + amount * .5);
  float off = (fxHash(vec2(sl, seed + 7.)) - .5) * 2. * shift * amount * moving;

  // ② 色彩分离：红、青两个通道分别再偏一点（3 次采样）。
  float sp = split * amount * (.5 + moving);
  vec3 a = srcTex(uv - vec2(off + sp, 0.)).rgb;
  vec3 b = srcTex(uv - vec2(off, 0.)).rgb;
  vec3 d = srcTex(uv - vec2(off - sp, 0.)).rgb;
  float inkR = inkOf(a), inkG = inkOf(b), inkB = inkOf(d);

  // ③ 合成：原位的字先擦掉（补底色），再把错开后的字按通道盖回去——红通道来自左移样本、青来自右移样本。
  vec3 c = mix(src, bg, inkOf(src));
  vec3 glitched = vec3(a.r, b.g, d.b);
  float m = max(inkG, max(inkR, inkB));
  c = mix(c, vec3(mix(c.r, glitched.r, inkR), mix(c.g, glitched.g, inkG), mix(c.b, glitched.b, inkB)), step(.01, m));
  return vec4(c, 1.);
}
