/*@effect
{
  "id": "type-sparkler",
  "name": "仙女棒写字",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["sparkler", "light painting", "write on", "sparks", "celebration", "仙女棒", "光绘", "写字", "火花"],
  "summary": "文字像被一根点燃的仙女棒在夜空里写出来：写字前沿是一团迸射火花的亮点，写过的笔画留下暖橙色的光迹并轻微抖动发光；写完后光迹慢慢冷却成稳定的暖光。",
  "when": "新年/生日/婚礼/节日、庆祝与浪漫、夜景文字、手写感的标题。",
  "avoid": "白天/浅底画面（光迹看不出）；需要立即读到全部文字的快节奏镜头。",
  "params": {
    "inEnd": { "type": "float", "default": 0.55, "min": 0.05, "max": 0.95, "label": "写完于镜头进度" },
    "glow": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "光迹辉光（通常由节拍驱动）" },
    "hot": { "type": "color", "default": "#fff3c4", "label": "火花色" },
    "trail": { "type": "color", "default": "#ff9a3c", "label": "光迹色" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "glow": { "to": "beat", "amount": 0.35 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：光绘写字", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（光绘摄影）：长曝光下挥动仙女棒写字，燃烧头是迸射火花的亮点，划过的路径在底片上留下一道光；
// 刚写过的部分最亮最热（偏白黄），越早写的越暗越红。这里没有笔画路径，用“从左到右的书写前沿（带手写起伏）”近似。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float ink = inkAt(uv);
  // ① 书写前沿：从左到右，前沿随高度与噪声起伏（手的上下运动）
  float front = clamp(uProgress / inEnd, 0., 1.) * 1.1 - .05;
  float lead = uv.x + (fxNoise(vec2(uv.y * 8., 2.)) - .5) * .05;
  float written = step(lead, front);
  // ② 光迹温度：刚写过（离前沿近）偏白热，越早越红越暗；写完后整体冷却到稳定暖光
  float age = clamp((front - lead) * 4., 0., 1.);
  vec3 col = mix(hot, trail, age) * (1.2 - age * .4);
  // ③ 辉光：周围 4 点的墨量（只算已写部分）
  vec2 o = vec2(5. / uRes.x, 5. / uRes.y);
  float halo = (inkAt(uv + vec2(o.x, 0.)) + inkAt(uv - vec2(o.x, 0.)) + inkAt(uv + vec2(0., o.y)) + inkAt(uv - vec2(0., o.y))) * .25 * written;
  // ④ 火花：前沿附近随机迸射的亮点（每 1/20 秒换一批，只在前沿 4% 宽的带里）
  vec2 g = floor(uv * uRes / 2.);
  float near = exp(-pow((lead - front) * 25., 2.)) * step(front, 1.02);
  float spark = step(.97, fxHash(g + floor(uTime * 20.))) * near;
  vec3 c = src * .35;                                     // 夜色：画面整体压暗
  c = mix(c, col, ink * written);
  c += trail * halo * glow * (1. - ink);
  c += hot * (spark * 2. + near * ink * .8);
  return vec4(c, 1.);
}
