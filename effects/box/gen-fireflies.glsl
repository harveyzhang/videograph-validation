/*@effect
{
  "id": "gen-fireflies",
  "name": "萤火虫",
  "kind": "post",
  "category": "生成层",
  "tags": ["fireflies", "glow", "particles", "magic", "night", "萤火虫", "光点", "魔法", "夜晚"],
  "summary": "暖黄色的小光点在画面下半部缓慢游走，每只萤火虫按自己的节奏一明一灭、带柔和光晕；每一拍有一部分同时亮起。",
  "when": "夏夜、森林、童话与魔法、温柔抒情、回忆与梦境。",
  "avoid": "白天强光画面（光点看不见）；快节奏动作段落。",
  "params": {
    "count": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "数量" },
    "size": { "type": "float", "default": 0.006, "min": 0.002, "max": 0.02, "label": "光点大小（画面高度比例）" },
    "height": { "type": "float", "default": 0.65, "min": 0.1, "max": 1, "label": "分布高度（从底部算）" },
    "glow": { "type": "float", "default": 1, "min": 0, "max": 2, "label": "亮度" },
    "sync": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "随拍同步亮起（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#ffd76a", "label": "光色" }
  },
  "bindings": { "sync": { "to": "beat", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：发光粒子", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：萤火虫在低处慢慢飞，尾部发光是“闪”的——亮一两秒、暗几秒，各自节奏不同；
// 有些种类的萤火虫会同步闪烁（这里用节拍让一部分同步亮起）。光点很小但有一圈大光晕（夜里眼睛/镜头的散射）。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float cs = .12;
  vec2 g = p / cs;
  vec2 base = floor(g);
  float light = 0.;

  // ① 每格一只萤火虫（按数量概率存在）；位置 = 格内随机点 + 两个慢速正弦的游走（会跑出本格，所以查 3×3 邻格）。
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = base + vec2(float(i), float(j));
      float h = fxHash(id);
      if (h > count) continue;
      vec2 ctr = id + .5 + .45 * vec2(sin(uTime * (.3 + h * .4) + h * 30.), cos(uTime * (.25 + h * .35) + h * 50.));
      // 只在画面下部 height 范围内出现
      float yy = ctr.y * cs;
      float inRange = smoothstep(height, height - .1, yy);

      // ② 闪烁：每只自己的周期（亮约 1/3 时间，缓起缓落）；sync 挂每拍——每拍让一半萤火虫一起亮一下。
      float ph = fract(uTime * (.25 + h * .3) + h * 7.);
      float blink = smoothstep(0., .15, ph) * smoothstep(.45, .2, ph);
      blink = max(blink, sync * step(.5, fxHash(id + 3.)));

      // ③ 光点 + 光晕：核心很小、光晕 6 倍大。
      float d = length((g - ctr) * cs);
      float core = smoothstep(size, size * .3, d);
      float halo = exp(-d / (size * 6.)) * .35;
      light += (core + halo) * blink * inRange;
    }
  }

  // ④ 合成：加光（screen），并给周围一点点暖色的环境光。
  vec3 c = 1. - (1. - src) * (1. - clamp(color * light * glow, 0., 1.));
  return vec4(c, 1.);
}
