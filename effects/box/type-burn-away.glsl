/*@effect
{
  "id": "type-burn-away",
  "name": "文字燃烧（烧出 / 烧尽）",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text animation", "burn", "dissolve", "embers", "fire", "文字动画", "燃烧", "烧掉", "消散"],
  "summary": "文字从边缘开始被看不见的火烧掉：燃烧前沿是一圈发亮的橙红火边，烧过的地方变成焦黑后消失，火边上跳出零星火星；默认是入场“烧出”文字；关掉 reverse 并把时间设到镜头末尾就是出场“烧尽”。",
  "when": "告别/毁灭/愤怒的歌词、悬疑揭示、片尾消失、复仇与战争题材。",
  "avoid": "温柔可爱的风格；文字压在亮色背景上（焦黑过渡在浅底上显脏）。",
  "params": {
    "burnStart": { "type": "float", "default": 0.02, "min": 0, "max": 0.95, "label": "开始燃烧的镜头进度" },
    "burnEnd": { "type": "float", "default": 0.45, "min": 0.05, "max": 1, "label": "烧完的镜头进度" },
    "reverse": { "type": "bool", "default": true, "label": "烧出（开）/ 烧尽（关）：开 = 从无到有烧出文字，关 = 把文字烧掉" },
    "edge": { "type": "float", "default": 0.05, "min": 0.01, "max": 0.2, "label": "火边宽度" },
    "flare": { "type": "float", "default": 0.4, "min": 0, "max": 1.5, "label": "火边亮度（通常由节拍驱动）" },
    "fire": { "type": "color", "default": "#ff6a1a", "label": "火色" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" },
    "bg": { "type": "color", "default": "#0d0d0f", "label": "烧掉后的底色" }
  },
  "bindings": { "flare": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：燃烧溶解", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：纸上的字被火烧，火从纸的缺口处沿着纤维不规则地推进；火焰前沿最亮（橙黄），刚烧过的地方是发红的炭，
// 再往后变成黑灰剥落。实现：用分形噪声作为“燃烧先后顺序图”，阈值随时间推进，阈值附近是火边。

float inkOf(vec3 c) { return smoothstep(threshold - .08, threshold + .08, fxLuma(c)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkOf(src);
  // ① 燃烧顺序：噪声 + 一点从右下往左上的方向性（火从一角烧起）
  vec2 p = uv * vec2(uRes.x / uRes.y, 1.);
  float order = fxFbm(p * 5.) * .7 + (1. - uv.x * .6 - uv.y * .4) * .3;
  // ② 燃烧阈值随时间推进；reverse 时倒放（从无到有）
  float t = clamp((uProgress - burnStart) / max(burnEnd - burnStart, .01), 0., 1.);
  if (reverse) t = 1. - t;
  float th = mix(-.1, 1.1, t);
  float d = order - th;                          // >0 还没烧到；<0 已烧掉
  float alive = smoothstep(-edge * .2, 0., d);   // 字还在的比例
  float rim = exp(-pow(d / edge, 2.)) ;          // 火边
  float char = smoothstep(edge, 0., d) * alive;  // 将烧未烧的焦化
  // ③ 火星：火边附近随机跳出的小亮点（每 1/12 秒换位置）
  vec2 g = floor(uv * uRes / 3.);
  float spark = step(.985, fxHash(g + floor(uTime * 12.))) * rim;
  // ④ 合成：烧掉的字 → 底色；焦化 → 字变暗变红；火边与火星发光（只在字的笔画上）
  vec3 c = mix(src, bg, ink * (1. - alive));
  c = mix(c, mix(c, vec3(.15, .04, .02), .8), ink * char);
  c += fire * (rim * (1. + flare) + spark * 2.) * ink;
  return vec4(c, 1.);
}
