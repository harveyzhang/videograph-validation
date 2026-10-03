/*@effect
{
  "id": "gen-gradient-mesh",
  "name": "流体渐变背景",
  "kind": "post",
  "category": "生成层",
  "tags": ["gradient", "mesh gradient", "fluid", "background", "brand", "aurora gradient", "渐变", "流体", "背景", "品牌色"],
  "summary": "四团品牌色在背景里缓慢流动、互相融合成柔和的弥散渐变（类似系统壁纸的网格渐变），只替换画面的暗部背景，前景的亮字/主体保持不变；每小节颜色团涌动一次。",
  "when": "品牌宣传、科技发布、App/产品介绍的背景、文字卡与金句、轻松现代的广告；把纯黑背景变成有质感的彩色背景。",
  "avoid": "写实/纪实画面；前景与背景亮度接近时（无法区分前后，渐变会盖到主体上，调 behind）。",
  "params": {
    "c1": { "type": "color", "default": "#ff5e7e", "label": "颜色 1" },
    "c2": { "type": "color", "default": "#7a5cff", "label": "颜色 2" },
    "c3": { "type": "color", "default": "#2ec5ff", "label": "颜色 3" },
    "c4": { "type": "color", "default": "#ffb34d", "label": "颜色 4" },
    "speed": { "type": "float", "default": 0.12, "min": 0, "max": 1, "label": "流动速度" },
    "behind": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "背景判定亮度（1 = 整屏替换）" },
    "lightBackground": { "type": "bool", "default": false, "label": "浅色背景（主体是深色剪影时打开：替换亮部）" },
    "swirl": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "小节涌动（通常由节拍驱动）" }
  },
  "bindings": { "swirl": { "to": "bar", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：品牌渐变背景", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（设计软件里的“网格渐变/弥散渐变”）：在画布上放几个颜色控制点，每个像素的颜色按到各点的距离加权混合，
// 控制点缓慢移动，颜色就像液体一样流动融合。为避免 8 位输出的色带（banding），最后加极细的抖动颗粒。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float t = uTime * speed;

  // ① 四个控制点沿各自的利萨如曲线缓慢移动；swirl 挂小节——每小节开头控制点绕中心多转一点（涌动）。
  float tw = t + swirl * .6;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 k1 = vec2(.25 + .2 * sin(tw * 1.1), .3 + .2 * cos(tw * .9)) * asp;
  vec2 k2 = vec2(.75 + .2 * cos(tw * .8), .25 + .2 * sin(tw * 1.3)) * asp;
  vec2 k3 = vec2(.7 + .2 * sin(tw * .7 + 2.), .75 + .2 * cos(tw * 1.1)) * asp;
  vec2 k4 = vec2(.25 + .2 * cos(tw * 1.2 + 1.), .75 + .2 * sin(tw * .6)) * asp;

  // ② 反距离加权混合（指数 2.5 让每团颜色更“饱满”），再用低频噪声扭一下边界，像液体。
  vec2 q = p + (vec2(fxNoise(p * 2. + t), fxNoise(p * 2. - t + 5.)) - .5) * .25;
  float w1 = 1. / pow(length(q - k1) + .05, 2.5), w2 = 1. / pow(length(q - k2) + .05, 2.5);
  float w3 = 1. / pow(length(q - k3) + .05, 2.5), w4 = 1. / pow(length(q - k4) + .05, 2.5);
  vec3 grad = (c1 * w1 + c2 * w2 + c3 * w3 + c4 * w4) / (w1 + w2 + w3 + w4);

  // ③ 抖动颗粒：±1/255 的静态噪声，消除渐变色带。
  grad += (fxHash(floor(uv * uRes)) - .5) / 128.;

  // ④ 只替换背景：原画面亮度低于 behind 的区域（软过渡）显示渐变；behind = 1 时整屏替换。
  //    lightBackground：背景是浅色、主体是深色剪影时，改为替换亮部（判定阈值同样用 behind，取 1 - behind 的对称位置）。
  float l = fxLuma(src);
  float bgMask = behind >= .999 ? 1. : lightBackground ? smoothstep(1. - behind - .12, 1. - behind + .08, l) : smoothstep(behind + .12, behind - .08, l);
  return vec4(mix(src, grad, bgMask), 1.);
}
