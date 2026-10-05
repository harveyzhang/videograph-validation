/*@effect
{
  "id": "type-handwriting-wipe",
  "name": "手写墨迹揭示",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "handwriting", "brush reveal", "ink", "calligraphy", "文字动画", "手写", "毛笔", "书法"],
  "summary": "文字被一支看不见的毛笔“写”出来：揭示前沿是一道带飞白和墨晕的笔触，从左到右、从上到下逐行推进；刚写出的部分墨色更浓，随后略微晕开。",
  "when": "书法/国风/诗词、手写信与日记、温情叙事、品牌签名与手写 Logo。",
  "avoid": "需要逐字精确对齐笔顺的书法教学（这里是按行推进的近似）；竖排文字。",
  "params": {
    "lines": { "type": "float", "default": 2, "min": 1, "max": 10, "label": "行数（按画面高度均分）" },
    "inEnd": { "type": "float", "default": 0.6, "min": 0.05, "max": 0.95, "label": "写完于镜头进度" },
    "dry": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "飞白" },
    "bleed": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "墨晕（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "darkText": { "type": "bool", "default": false, "label": "深色字（浅底，如宣纸黑字）" }
  },
  "bindings": { "bleed": { "to": "beat", "amount": 0.2 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/ink-wash：毛笔书写", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：毛笔写字，笔锋所到之处才有墨；行笔快、墨少时笔画中出现丝丝露白（飞白）；墨落纸后沿纤维略微晕开。
// 这里没有笔画顺序数据，用“行内从左到右、行间从上到下”的书写前沿近似，前沿边缘用纤维状噪声做出飞白。

float inkAt(vec2 p) {
  float l = fxLuma(srcTex(p).rgb);
  return darkText ? smoothstep(threshold + .08, threshold - .08, l) : smoothstep(threshold - .08, threshold + .08, l);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkAt(uv);
  // ① 书写前沿：总进度 → 第几行、行内 x
  float n = max(floor(lines + .5), 1.);
  float k = clamp(uProgress / inEnd, 0., 1.) * n;
  float row = floor((1. - uv.y) * n);
  float fx = clamp(k - row, 0., 1.);
  // ② 飞白：沿笔锋方向（横向）拉长的纤维噪声；在前沿附近才明显，写完后大部分被墨填实
  float fiber = fxNoise(vec2(uv.x * 40., uv.y * 400.));
  float nearFront = smoothstep(.15, 0., fx - uv.x);
  float written = smoothstep(fx + .01, fx - .01, uv.x + (fiber - .5) * .03);
  float hollow = step(fiber, dry * .5) * nearFront;
  float m = ink * written * (1. - hollow);
  // ③ 墨晕：刚写过的字周围轻微晕开（4 次采样的模糊墨量），bleed 挂每拍
  vec2 o = vec2(3. / uRes.x, 3. / uRes.y);
  float halo = (inkAt(uv + vec2(o.x, 0.)) + inkAt(uv - vec2(o.x, 0.)) + inkAt(uv + vec2(0., o.y)) + inkAt(uv - vec2(0., o.y))) * .25 * written;
  // ④ 合成：未写出的字擦成底色；写出的字刚写时更浓
  vec3 bgc = darkText ? max(src, vec3(fxLuma(src))) : src * .12;   // 未写出的字：只剩极淡的影子
  vec3 c = mix(src, bgc, ink);
  vec3 strong = darkText ? src * mix(.6, 1., 1. - nearFront) : src * mix(1.15, 1., 1. - nearFront);
  c = mix(c, strong, m);
  c = mix(c, darkText ? src * .85 : src * .5, halo * (1. - ink) * bleed);
  return vec4(c, 1.);
}
