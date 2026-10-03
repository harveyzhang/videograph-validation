/*@effect
{
  "id": "luma-pixel-dissolve",
  "name": "按亮度像素溶解",
  "kind": "transition",
  "category": "转场",
  "tags": ["pixel dissolve", "luma", "mosaic", "bright first", "digital", "像素溶解", "亮度", "马赛克转场"],
  "summary": "画面先碎成方块，亮的方块最先翻成下一个镜头、暗的最后翻，方块在翻转时短暂亮一下；结束时方块再细化回清晰画面。",
  "when": "科技/数字主题、游戏感过场、数据可视化之间的切换、从明亮场景切到明亮场景。",
  "avoid": "两个镜头都很暗（亮度顺序不明显）；需要柔和情绪的段落。",
  "params": {
    "block": { "type": "float", "default": 24, "min": 6, "max": 80, "label": "最大方块（像素）" },
    "order": { "type": "float", "default": 0.8, "min": 0, "max": 1, "label": "亮度决定顺序（0 = 纯随机）" },
    "spark": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "翻转亮光" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：马赛克/像素化过场", "note": "按思路自写；与 gl-transitions 的 luma（灰度遮罩）、pixelize（统一像素化）不同：这里是按块、按亮度排序翻转" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（数字视觉）：早期电脑的“溶解”是按块逐个替换像素；把替换顺序交给画面亮度，亮的地方先变，
// 就像光先“穿过”了画面——观众的视线会被亮处带着走，比纯随机更有方向感。
// 节拍：转场本身由进度驱动，不挂节拍。

vec4 transition(vec2 uv) {
  // ① 方块化：进度 0→0.5 方块从 1 像素长到 block，0.5→1 再缩回（先碎后合）。
  float tri = 1. - abs(progress * 2. - 1.);
  float size = max(1., floor(mix(1., block, smoothstep(0., 1., tri))));
  vec2 cell = floor(uv * uRes / size);
  vec2 cuv = (cell + .5) * size / uRes;

  // ② 顺序：每块的“翻转时刻” = 亮度（两个镜头亮度的平均，越亮越早）与随机数的混合。
  float lum = (fxLuma(getFromColor(cuv).rgb) + fxLuma(getToColor(cuv).rgb)) * .5;
  float rnd = fxHash(cell + 3.7);
  float when = mix(rnd, 1. - lum, order) * .8 + .1;    // 0.1..0.9 之间翻完

  // ③ 翻转：进度越过该块的时刻就换成下一个镜头；翻转前后约 0.06 的时间里块亮一下（像素刷新的闪光）。
  float flipped = step(when, progress);
  vec3 a = getFromColor(size > 1.5 ? cuv : uv).rgb;
  vec3 b = getToColor(size > 1.5 ? cuv : uv).rgb;
  vec3 col = mix(a, b, flipped);
  col += spark * .5 * exp(-pow((progress - when) / .03, 2.)) * vec3(.9, .95, 1.);

  // ④ 方块之间留极细的暗缝（只在方块大于 4 像素时），让“块”可读。
  vec2 f = fract(uv * uRes / size);
  float seam = (step(f.x, 1. / size) + step(f.y, 1. / size)) * step(4., size);
  col *= 1. - seam * .25;
  return vec4(col, 1.);
}
