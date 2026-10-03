/*@effect
{
  "id": "type-decode-scramble",
  "name": "乱码解码",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "decode", "scramble", "hacker", "cipher", "文字动画", "乱码", "解密", "揭示"],
  "summary": "文字先以跳动的乱码字块出现，再从左到右逐格“解密”成真实文字；鼓点时少量已解开的格子又闪回乱码；结尾反向加密退场。",
  "when": "科技/网络安全/AI 主题的标题、数据揭示、悬疑线索、产品参数登场。",
  "avoid": "柔和抒情的段落；画面没有文字或文字极小（格子比字大时看不出解码）。",
  "params": {
    "cell": { "type": "float", "default": 0.035, "min": 0.008, "max": 0.15, "label": "字格大小（画面高度比例）" },
    "inEnd": { "type": "float", "default": 0.4, "min": 0.05, "max": 0.8, "label": "解码完成于镜头进度" },
    "outStart": { "type": "float", "default": 0.9, "min": 0.4, "max": 1, "label": "加密退场开始（1 = 不退场）" },
    "glitch": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "闪回乱码比例（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.4, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "darkText": { "type": "bool", "default": false, "label": "深色字（浅底）" },
    "accent": { "type": "color", "default": "#3dff8a", "label": "乱码颜色" }
  },
  "bindings": { "glitch": { "to": "kick", "amount": 0.35 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：文字乱码解码揭示", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（电影片头/黑客界面的经典手法）：屏幕上每个字符位置先快速轮换随机字符，
// 然后按顺序“锁定”到正确字符——观众看到文字像被逐个破解出来。
// 这里每个字格先显示程序生成的 3×5 伪字形（每 1/15 秒换一个，局部小格在变，不是整屏闪烁），到时刻后显示真实画面。

float inkAt(vec2 p) {
  float l = fxLuma(srcTex(p).rgb);
  return darkText ? smoothstep(threshold + .1, threshold - .1, l) : smoothstep(threshold - .1, threshold + .1, l);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 字格：按像素划分格子；格子里有没有字 = 格心与两个角点的最大墨量（3 次采样）。
  float cpx = cell * uRes.y;             // 字格边长（像素）
  vec2 g = uv * uRes / cpx;
  vec2 id = floor(g), f = fract(g);
  vec2 cuv = (id + .5) * cpx / uRes;
  float has = max(inkAt(cuv), max(inkAt((id + vec2(.25, .3)) * cpx / uRes), inkAt((id + vec2(.75, .7)) * cpx / uRes)));

  // ② 解码顺序：阅读顺序（从上到下、从左到右）+ 少量随机，映射到 0..inEnd 的时间里。
  float cols = uRes.x / cpx, rows = uRes.y / cpx;
  float order = clamp(((rows - 1. - id.y) * .35 / rows + id.x / cols) / 1.35 + (fxHash(id) - .5) * .12, 0., 1.);
  float p = uProgress;
  float decoded = step(order * inEnd, p);
  if (outStart < .999) decoded *= 1. - step(outStart + order * (1. - outStart), p);

  // ③ 闪回：鼓点时一部分已解码的格子短暂回到乱码（glitch 挂 kick），像信号受到干扰。
  float flick = step(fxHash(id + floor(uTime * 8.)), glitch * .3);
  float scrambled = has * max(1. - decoded, flick);

  // ④ 伪字形：每格 3×5 点阵，比特由哈希给出，每 1/15 秒换一次；字形四周留边距像真正的字符。
  vec2 q = (f - vec2(.2, .12)) / vec2(.6, .76);
  float bit = 0.;
  if (q.x >= 0. && q.x < 1. && q.y >= 0. && q.y < 1.) {
    vec2 b = floor(q * vec2(3., 5.));
    bit = step(.45, fxHash(id * 7.3 + b * 1.7 + floor(uTime * 15.)));
  }

  // ⑤ 合成：未解码的有字格 = 背景压暗 + 乱码字形（主题色，带一点辉光）；已解码 = 真实画面。
  vec3 bg = src * (1. - has * .85);
  vec3 code = bg + accent * bit * 1.1 + accent * .12 * has;
  return vec4(mix(src, code, scrambled), 1.);
}
