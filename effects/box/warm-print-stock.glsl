/*@effect
{
  "id": "warm-print-stock",
  "name": "暖调彩色相纸",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["warm film", "portra-like", "golden hour", "print stock", "film look", "暖调", "胶片味", "彩色负片放大"],
  "summary": "像柔和的彩色负片放大到暖调相纸上：肤色温润、高光柔和不炸、暗部带一点暖棕、绿色偏橄榄、蓝色偏青，整体低反差的金色胶片感。",
  "when": "人像、婚礼、生活方式、旅行与家庭回忆、温暖的品牌故事；黄金时刻的外景最好看。",
  "avoid": "冷峻科技与悬疑；需要强烈对比的动作镜头；已经很黄的画面会过暖。",
  "params": {
    "warmth": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "暖度" },
    "softness": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "高光柔和" },
    "olive": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "绿色偏橄榄" },
    "exposure": { "type": "float", "default": 0, "min": -0.3, "max": 0.3, "label": "曝光" }
  },
  "bindings": { "exposure": { "to": "bar", "amount": 0.05 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：胶片调色", "note": "按思路自写；不模仿任何商标胶片的专有配方" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：人像用的彩色负片宽容度很大、反差低，放大到暖调相纸上时：高光是被“肩部”曲线慢慢压住的（不会死白），
// 暗部有“趾部”抬起（不会死黑），整体偏暖；染料的串色让绿色偏橄榄黄、蓝色偏青，肤色因为红/黄染料干净而显得温润。
// 和 teal-orange（数字调色的青橙分离）不同：这是化学的、低反差、整体偏暖的“胶片味”。

vec3 filmCurve(vec3 x) {
  // 趾部 + 肩部：暗部抬起一点、高光柔和压缩（softness 越大肩部越早开始）
  vec3 toe = x * x * (1.6 - .6 * x);
  vec3 sh = 1. - exp(-x * (2.2 - softness * .9));
  sh /= 1. - exp(-(2.2 - softness * .9));
  return mix(toe, sh, smoothstep(.15, .6, x)) * .94 + .035;
}

vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;

  // ① 曝光：负片宽容度大，曝光变化表现为整体平缓地亮/暗。exposure 挂小节：每小节开头轻轻“呼吸”一下。
  c *= exp2(exposure);

  // ② 胶片曲线：趾部与肩部，整体反差降低。
  c = filmCurve(clamp(c, 0., 1.5));

  // ③ 染料串色：绿色偏橄榄（混入红）、蓝色偏青（混入绿），红色保持干净（肤色好看的原因）。
  float g2o = olive * .18;
  c = vec3(c.r, c.g * (1. - g2o) + c.r * g2o * .6 + c.b * g2o * .4, c.b * .9 + c.g * .1);

  // ④ 暖调相纸：整体向暖偏（高光偏金、暗部偏暖棕），饱和度略收。
  float l = fxLuma(c);
  vec3 warmHi = vec3(1.05, 1., .86), warmLo = vec3(1.04, .98, .9);
  c *= mix(vec3(1.), mix(warmLo, warmHi, l), warmth);
  c = mix(vec3(fxLuma(c)), c, .92);

  // ⑤ 极细的颗粒（静止），给数字画面一点有机感。
  c += (fxHash(floor(uv * uRes)) - .5) * .018;
  return vec4(clamp(c, 0., 1.), 1.);
}
