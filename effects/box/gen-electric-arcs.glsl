/*@effect
{
  "id": "gen-electric-arcs",
  "name": "电弧缠绕",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["electricity", "arcs", "tesla", "energy", "sparks", "电弧", "电流", "能量", "特斯拉"],
  "summary": "画面亮部的轮廓上爬满跳动的蓝白色电弧：电弧沿边缘不断改变路径、局部分叉，带强烈辉光；鼓点时电压一冲，电弧更亮更多。",
  "when": "超能力/觉醒/能量爆发、科幻与赛博、摇滚与电子乐 drop、“通电”的意象。",
  "avoid": "柔和温暖的题材；画面轮廓极多时会满屏电弧。",
  "params": {
    "density": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "电弧密度" },
    "jitter": { "type": "float", "default": 0.012, "min": 0, "max": 0.04, "label": "电弧跳动幅度" },
    "voltage": { "type": "float", "default": 0.4, "min": 0, "max": 1.5, "label": "亮度（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#8fd8ff", "label": "电弧颜色" }
  },
  "bindings": { "voltage": { "to": "kick", "amount": 0.9 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：能量电弧", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：高压放电沿着阻力最小的路径走，路径每一瞬间都在变（锯齿状、带分叉），亮度极高、周围空气发出蓝白辉光；
// 带电物体的边缘（曲率大的地方）最容易放电。实现：在被噪声扰动（每 1/20 秒换一次）的位置取画面轮廓，轮廓就成了跳动的电弧。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float frame = floor(uTime * 20.);
  // ① 扰动：每帧换一次的锯齿状位移（两层不同频率的噪声）
  vec2 p = uv * vec2(uRes.x / uRes.y, 1.);
  vec2 off = (vec2(fxNoise(p * 30. + frame * 1.7), fxNoise(p * 30. + frame * 2.3 + 9.)) - .5) * jitter
           + (vec2(fxNoise(p * 8. + frame), fxNoise(p * 8. - frame + 4.)) - .5) * jitter * 1.5;
  // ② 电弧：扰动后位置的轮廓（亮度梯度，4 次采样），只保留一部分（按噪声开关，模拟断续的放电）
  vec2 o = 1.5 / uRes;
  vec2 q = uv + off;
  float e = abs(fxLuma(srcTex(q + vec2(o.x, 0.)).rgb) - fxLuma(srcTex(q - vec2(o.x, 0.)).rgb)) + abs(fxLuma(srcTex(q + vec2(0., o.y)).rgb) - fxLuma(srcTex(q - vec2(0., o.y)).rgb));
  float arc = smoothstep(.12, .35, e) * step(1. - density, fxNoise(p * 6. + frame * .7));
  // ③ 辉光：电弧周围一圈（取原位置轮廓的柔和版本，4 次采样）
  vec2 o2 = 5. / uRes;
  float glow = (abs(fxLuma(srcTex(uv + vec2(o2.x, 0.)).rgb) - fxLuma(srcTex(uv - vec2(o2.x, 0.)).rgb)) + abs(fxLuma(srcTex(uv + vec2(0., o2.y)).rgb) - fxLuma(srcTex(uv - vec2(0., o2.y)).rgb))) * density;
  vec3 c = src + (vec3(1.) * arc * .8 + color * arc + color * glow * .35) * (voltage + .3);
  return vec4(c, 1.);
}
