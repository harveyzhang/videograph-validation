/*@effect
{
  "id": "grid-collage",
  "name": "网格拼贴墙",
  "kind": "post",
  "category": "画面版式",
  "tags": ["grid", "collage", "mosaic wall", "video wall", "tiles", "网格", "拼贴", "电视墙", "九宫格"],
  "summary": "画面被分成 N×N 的小格电视墙，每格都是完整画面的缩小版但带不同色调与时间错位的亮度；每拍有一格高亮放大，偶尔整面墙合成为一张完整大图。",
  "when": "合集与回顾、社交媒体与“很多人”的意象、科技与监控、副歌的视觉堆叠。",
  "avoid": "需要看清单一画面细节的镜头。",
  "params": {
    "grid": { "type": "float", "default": 3, "min": 2, "max": 8, "label": "每边格数" },
    "gap": { "type": "float", "default": 0.004, "min": 0, "max": 0.02, "label": "格缝" },
    "tint": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "各格色调差异" },
    "merge": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "合成整图（通常由小节驱动）" },
    "gapColor": { "type": "color", "default": "#08080a", "label": "格缝颜色" }
  },
  "bindings": { "merge": { "to": "bar", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：多格电视墙", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（展会/监控的电视墙）：一面墙由很多台显示器拼成，可以各自播放同一画面（每台色温不同），
// 也可以合起来显示一张大图。这里在两种模式之间按小节切换：小节开头是整幅大图，随后散成每格一幅。

vec4 effect(vec2 uv) {
  float n = floor(grid + .5);
  vec2 id = floor(uv * n), f = fract(uv * n);
  // ① 两种取样：每格完整缩小画面（f）或整面墙一张大图（uv），按 merge 混合（merge 挂小节）
  vec2 q = mix(f, uv, smoothstep(.2, .8, merge));
  vec3 c = srcTex(q).rgb;
  // ② 每台显示器的色温/亮度差异（墙面不一致）
  float h = fxHash(id);
  vec3 tc = .5 + .5 * cos(6.2832 * (h + vec3(0., .33, .67)));
  c = mix(c, c * (.6 + tc * .8), tint * (1. - merge) * .6);
  c *= .85 + .2 * fxHash(id + 3.);
  // ③ 每拍一格高亮（当前拍号对应的格子）
  float beatIdx = floor(uTime * 2.);
  float lit = step(abs(fxHash(vec2(beatIdx, 1.)) * n * n - (id.x + id.y * n) - .5), .5);
  c *= 1. + lit * .35 * (1. - merge);
  // ④ 格缝（屏幕边框）
  float g = gap * n;
  float inGap = step(f.x, g) + step(1. - g, f.x) + step(f.y, g) + step(1. - g, f.y);
  return vec4(mix(c, gapColor, min(inGap, 1.)), 1.);
}
