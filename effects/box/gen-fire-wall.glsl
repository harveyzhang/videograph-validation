/*@effect
{
  "id": "gen-fire-wall",
  "name": "火焰墙",
  "kind": "post",
  "category": "生成层",
  "tags": ["fire", "flames", "burning", "inferno", "heat", "火焰", "燃烧", "火墙", "烈火"],
  "summary": "画面底部燃起一排翻腾的火焰：火舌向上蹿动、边缘撕裂成小火苗，火焰从底部的白黄到顶端的橙红再到暗红烟气；音乐能量越高火越高越猛。",
  "when": "摇滚/金属/嘻哈的燃向段落、战争与毁灭、热情与愤怒、节日篝火、标题“燃”起来。",
  "avoid": "清凉/水/冬季题材；画面下部有重要内容时（调低 height）。",
  "params": {
    "height": { "type": "float", "default": 0.35, "min": 0.05, "max": 1, "label": "火焰高度" },
    "speed": { "type": "float", "default": 1, "min": 0.2, "max": 3, "label": "翻腾速度" },
    "detail": { "type": "float", "default": 4, "min": 1, "max": 10, "label": "火舌细碎程度" },
    "rage": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量增大（通常由音乐能量驱动）" }
  },
  "bindings": { "rage": { "to": "energy", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：火焰生成", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：火焰是上升的热气流里发光的碳微粒——底部温度最高（白黄），往上冷却（橙→红→暗红），最后变成烟；
// 湍流把火焰撕成一条条火舌，不断向上蹿。实现：向上流动的噪声作“燃料密度”，减去高度衰减，再按“温度”上色（黑体色带）。

vec3 fireColor(float t) {
  return clamp(vec3(1.6 * t, 1.6 * t * t * .9, pow(t, 4.) * .9), 0., 1.) ;
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float H = height * (1. + rage * .6);
  // ① 燃料：向上流动的分形噪声（流速随能量），横向略被拉窄成火舌
  vec2 q = vec2(p.x * detail, p.y * detail * .6 - uTime * speed * (1.5 + rage));
  float n = fxFbm(q + fxFbm(q * .5 + uTime * .3) * .8);
  // ② 温度：底部高、往上按高度衰减，减去噪声撕出火舌
  float temp = 1. - uv.y / H + (n - .5) * 1.2;
  temp = clamp(temp, 0., 1.);
  float flame = smoothstep(.05, .35, temp);
  // ③ 黑体上色 + 火苗顶端的暗红烟
  vec3 fc = fireColor(temp);
  vec3 c = 1. - (1. - src) * (1. - fc * flame);
  // 火焰上方的热光照亮画面（暖色泛光）
  c += vec3(1., .4, .1) * smoothstep(H * 1.5, 0., uv.y) * .08 * (1. + rage);
  return vec4(c, 1.);
}
