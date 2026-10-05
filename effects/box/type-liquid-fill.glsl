/*@effect
{
  "id": "type-liquid-fill",
  "name": "液体灌字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "liquid fill", "water level", "progress", "wave", "文字", "灌水", "液面", "进度"],
  "summary": "文字像透明容器一样被液体从下往上灌满：液面带波浪起伏、表面一道亮线，液体里有上升的小气泡；空着的部分只剩淡淡的字形轮廓。液面随拍轻轻晃动。",
  "when": "进度/百分比/目标达成、饮料与水主题、“充能”的意象、可爱的标题入场。",
  "avoid": "细小的字（看不出液面）；文字不是亮色时（开 darkText）。",
  "params": {
    "fillEnd": { "type": "float", "default": 0.7, "min": 0.05, "max": 1, "label": "灌满于镜头进度" },
    "liquid": { "type": "color", "default": "#2ec5ff", "label": "液体颜色" },
    "wave": { "type": "float", "default": 0.015, "min": 0, "max": 0.05, "label": "波浪幅度" },
    "slosh": { "type": "float", "default": 0, "min": 0, "max": 0.03, "label": "节拍晃动（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "darkText": { "type": "bool", "default": false, "label": "深色字（浅底）" }
  },
  "bindings": { "slosh": { "to": "beat", "amount": 0.012 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：液体填充字", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：往透明的字形容器里灌水，水面从下往上升，水面因为倒水的扰动起伏，表面反光形成一条亮线；
// 水里混着小气泡往上冒。没灌到的地方是空的玻璃，只看得见轮廓。

float inkAt(vec2 p) {
  float l = fxLuma(srcTex(p).rgb);
  return darkText ? smoothstep(threshold + .08, threshold - .08, l) : smoothstep(threshold - .08, threshold + .08, l);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkAt(uv);
  // ① 液面高度：按镜头进度从画面下 20% 升到上 80%（字一般在中间）；波浪 + 节拍晃动
  float level = mix(.2, .82, clamp(uProgress / fillEnd, 0., 1.));
  float surf = level + sin(uv.x * 18. + uTime * 4.) * wave + sin(uv.x * 7. - uTime * 2.3) * wave * .6 + sin(uv.x * 11.) * slosh;
  float under = smoothstep(surf + .003, surf - .003, uv.y);
  // ② 空着的字：只剩轮廓（4 次采样的梯度）+ 很淡的玻璃色
  vec2 o = 1.5 / uRes;
  float edge = clamp(abs(inkAt(uv + vec2(o.x, 0.)) - inkAt(uv - vec2(o.x, 0.))) + abs(inkAt(uv + vec2(0., o.y)) - inkAt(uv - vec2(0., o.y))), 0., 1.);
  vec3 empty = mix(src * .1, vec3(.85), edge * .7) + .04;
  // ③ 液体：越深越浓的液体色，表面亮线，上升的小气泡
  vec3 liq = liquid * (.55 + .45 * smoothstep(level - .4, level, uv.y));
  liq += exp(-abs(uv.y - surf) * uRes.y / 2.) * .7;
  vec2 bp = vec2(uv.x * 60., uv.y * 20. - uTime * 2.);
  float bub = smoothstep(.12, .05, length(fract(bp) - .5)) * step(.85, fxHash(floor(bp)));
  liq += bub * .4;
  vec3 c = mix(src * mix(1., .1, ink), mix(empty, liq, under), ink);
  return vec4(c, 1.);
}
