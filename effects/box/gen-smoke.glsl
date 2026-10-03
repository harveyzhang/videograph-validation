/*@effect
{
  "id": "gen-smoke",
  "name": "升腾烟雾",
  "kind": "post",
  "category": "生成层",
  "tags": ["smoke", "steam", "haze", "rising", "volumetric", "烟雾", "蒸汽", "升腾", "氛围"],
  "summary": "从画面底部升起翻卷的烟雾：烟柱边缘被湍流卷成涡旋、越往上越稀薄散开；烟本身半透明，被画面亮处照亮；音乐越激烈烟越浓、升得越快。",
  "when": "舞台/演唱会、摇滚与嘻哈 MV、神秘与魔法、蒸汽（咖啡/拉面/温泉）、战场与工业。",
  "avoid": "需要清爽通透的画面；画面下部有重要字幕时（调低 height）。",
  "params": {
    "density": { "type": "float", "default": 0.95, "min": 0, "max": 1.5, "label": "浓度" },
    "height": { "type": "float", "default": 0.7, "min": 0.1, "max": 1.2, "label": "升腾高度" },
    "rise": { "type": "float", "default": 0.08, "min": 0, "max": 0.4, "label": "上升速度" },
    "curl": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "卷曲程度" },
    "boost": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量变浓（通常由音乐能量驱动）" },
    "color": { "type": "color", "default": "#b8b4ae", "label": "烟色" }
  },
  "bindings": { "boost": { "to": "energy", "amount": 0.4 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：氛围生成层", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：热烟比空气轻，从源头升起后进入湍流，被卷成一个个涡旋（卷曲），同时与空气混合变稀薄，越高越淡、越散开。
// 实现：让分形噪声“往上流”（采样坐标随时间下移），并用另一层噪声做旋度式的扭曲（卷曲），浓度从底部向上衰减。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float sp = rise * (1. + boost);

  // ① 卷曲：用低频噪声把采样坐标扭一下（越往上扭得越厉害，像涡旋逐渐展开）。
  vec2 q = p * vec2(2.2, 1.6) - vec2(0., uTime * sp * 2.);
  vec2 warp = vec2(fxFbm(q * .8 + uTime * .05), fxFbm(q * .8 + 5.2 - uTime * .04)) - .5;
  q += warp * curl * (.6 + p.y * 1.2);

  // ② 烟体：分形噪声 + 第二层更细的噪声，取阈值形成团块。
  float n = fxFbm(q) * .7 + fxFbm(q * 2.3 + 3.) * .3;
  float body = smoothstep(.38, .75, n);

  // ③ 高度衰减：底部最浓，到 height 处消散；随能量变浓。
  float fall = smoothstep(height, 0., p.y) * (density + boost * .5);
  float a = clamp(body * fall, 0., .9);

  // ④ 光照：烟被画面亮处照亮（取原画面亮度），暗处的烟偏暗；半透明叠加。
  vec3 lit = color * (.55 + .7 * fxLuma(src));
  return vec4(mix(src, lit, a), 1.);
}
