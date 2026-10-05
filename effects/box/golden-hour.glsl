/*@effect
{
  "id": "golden-hour",
  "name": "黄金时刻",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["golden hour", "sunset grade", "warm glow", "magic hour", "backlight", "黄金时刻", "夕阳", "暖光", "逆光"],
  "summary": "把画面调成日落前的“黄金时刻”：整体暖金色调、暗部偏一点洋红、高光柔和泛光，再从画面一角加一层斜射的暖色逆光与轻微光晕；每小节光线强弱轻轻呼吸。",
  "when": "人像/情侣/婚礼、旅行与生活方式、温暖怀旧、品牌故事的抒情段落。",
  "avoid": "冷峻科技与悬疑；本身已经很暖很黄的画面（会过火，调低 warmth）。",
  "params": {
    "warmth": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "暖度" },
    "sunX": { "type": "float", "default": 0.85, "min": -0.2, "max": 1.2, "label": "逆光位置 X" },
    "sunY": { "type": "float", "default": 0.8, "min": -0.2, "max": 1.2, "label": "逆光位置 Y" },
    "glow": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "逆光强度（通常由小节驱动）" },
    "haze": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "高光柔化" }
  },
  "bindings": { "glow": { "to": "bar", "amount": 0.2 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：调色", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：日落前一小时，太阳很低，光穿过更厚的大气，蓝光被散射掉，剩下金黄与橙红；光线从侧后方斜射，
// 人物与景物的轮廓被勾出一圈暖光，空气中的尘埃让逆光方向泛起一片柔光；阴影因为天空的散射光而带一点洋红紫。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float l = fxLuma(src);
  // ① 分区调色：高光偏金、暗部偏洋红紫
  vec3 c = src;
  c *= mix(vec3(1.), mix(vec3(1.02, .92, 1.02), vec3(1.12, 1., .78), smoothstep(.2, .8, l)), warmth);
  // ② 高光柔化：亮部向外泛（4 次采样）
  vec2 o = 4. / uRes;
  vec3 bl = (srcTex(uv + vec2(o.x, 0.)).rgb + srcTex(uv - vec2(o.x, 0.)).rgb + srcTex(uv + vec2(0., o.y)).rgb + srcTex(uv - vec2(0., o.y)).rgb) * .25;
  c += max(bl - .65, 0.) * vec3(1., .8, .5) * haze;
  // ③ 逆光：从 sun 位置斜射的暖色光，越靠近越强（屏幕混合）
  vec2 d = (uv - vec2(sunX, sunY)) * vec2(uRes.x / uRes.y, 1.);
  float sun = exp(-length(d) * 1.8) * glow;
  c = 1. - (1. - c) * (1. - vec3(1., .7, .35) * sun);
  return vec4(clamp(c, 0., 1.), 1.);
}
