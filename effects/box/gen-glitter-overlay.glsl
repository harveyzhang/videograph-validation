/*@effect
{
  "id": "gen-glitter-overlay",
  "name": "亮片闪烁",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["glitter", "sequins", "sparkle", "shimmer", "glam", "亮片", "闪粉", "闪耀", "奢华"],
  "summary": "画面亮部表面覆盖一层细密的亮片：每粒亮片随“角度”变化在不同时刻反射出彩色的强光点（带小十字光芒），像亮片礼服或闪粉化妆品；鼓点时一大片同时闪起。",
  "when": "时尚/美妆/派对/颁奖礼、珠宝与香水、偶像舞台、节日。",
  "avoid": "朴素自然的题材；画面整体很暗时亮片几乎不出现（亮片只在亮部反光）。",
  "params": {
    "size": { "type": "float", "default": 0.016, "min": 0.002, "max": 0.02, "label": "亮片大小（画面高度比例）" },
    "density": { "type": "float", "default": 0.25, "min": 0.01, "max": 0.3, "label": "同时闪光的比例" },
    "rainbow": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "彩虹色程度" },
    "flare": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点齐闪（通常由节拍驱动）" },
    "threshold": { "type": "float", "default": 0.2, "min": 0, "max": 0.9, "label": "只在亮于此的区域出现" }
  },
  "bindings": { "flare": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：高光闪烁", "note": "按思路自写；与 star-filter（少量大星芒）不同：这里是密集的小亮片随机闪" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：亮片是一个个小镜面，朝向各不相同，只有恰好把光反射进镜头的那几片会亮成一个耀眼的光点；
// 人或镜头稍微一动，亮起的就换成另一批。彩虹亮片的镀膜让反光带上不同颜色。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float spx = size * uRes.y;
  vec2 g = uv * uRes / spx;
  vec2 id = floor(g), f = fract(g) - .5;
  // ① 这粒亮片现在是否“对准”镜头：按每粒自己的节奏（相位随机），在短时间窗内亮起；鼓点时门槛降低（齐闪）
  float h = fxHash(id);
  float ph = fract(uTime * (.6 + h * .8) + h * 10.);
  float on = smoothstep(density + flare * .25, 0., ph) ;
  // ② 只在画面亮部（亮片受光的地方）
  float lit = smoothstep(threshold, threshold + .3, fxLuma(src));
  // ③ 光点：中心亮点 + 十字光芒（光芒长度 ≈ 1.5 格）
  float core = smoothstep(.35, 0., length(f));
  float cross = smoothstep(.08, 0., abs(f.x)) * smoothstep(1.5, 0., abs(f.y)) + smoothstep(.08, 0., abs(f.y)) * smoothstep(1.5, 0., abs(f.x));
  vec3 col = mix(vec3(1.), .55 + .45 * cos(6.2832 * (h * 3. + vec3(0., .33, .67))), rainbow);
  vec3 c = src + col * (core * 1.5 + cross * .5) * on * lit;
  return vec4(c, 1.);
}
