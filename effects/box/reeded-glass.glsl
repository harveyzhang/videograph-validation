/*@effect
{
  "id": "reeded-glass",
  "name": "棱纹玻璃",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["reeded glass", "fluted glass", "refraction", "ribbed", "aesthetic", "长虹玻璃", "棱纹玻璃", "折射", "高级感"],
  "summary": "像隔着一块竖条棱纹（长虹）玻璃看画面：每根玻璃棱把后面的景物压窄、轻微错位，棱与棱之间有细亮边；鼓点时玻璃整体滑动一下。",
  "when": "时尚/家居/香水/高端品牌、人像的朦胧感、转场前后的“隔着玻璃”镜头、音乐的抽象段落。",
  "avoid": "需要看清细节或读字的镜头；棱太密时会出现摩尔纹（调大 rib）。",
  "params": {
    "rib": { "type": "float", "default": 0.04, "min": 0.008, "max": 0.2, "label": "棱宽（画面高度比例）" },
    "power": { "type": "float", "default": 0.6, "min": 0, "max": 2, "label": "折射强度" },
    "shine": { "type": "float", "default": 0.25, "min": 0, "max": 1, "label": "棱边高光" },
    "slide": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "滑动（通常由节拍驱动）" }
  },
  "bindings": { "slide": { "to": "kick", "amount": 0.4 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/glass-product：玻璃质感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：长虹玻璃由一排半圆柱形的棱组成，每根棱都是一个小柱面透镜——它把身后一段更宽的景物压缩、翻转进这根棱的宽度里，
// 所以画面变成一条条错开的竖条；棱与棱的接缝处光线被折出一条亮线。

vec4 effect(vec2 uv) {
  float w = rib * uRes.y / uRes.x;                   // 棱宽（uv 单位）
  // ① 棱位置：slide 挂鼓点——鼓点时玻璃左右滑一下（整块玻璃相对画面移动）
  float x = uv.x + slide * w * .5;
  float f = fract(x / w) - .5;                         // 棱内 -0.5..0.5
  // ② 柱面折射：棱内位置越靠边，看到的景物越偏向棱中心外侧（压缩 + 错位），并带一点竖直方向的弯曲
  float off = f * w * power * 1.6;
  vec2 q = vec2(uv.x + off, uv.y + f * f * w * power * .3);
  // ③ 透过玻璃的轻微模糊：3 次竖向采样平均
  vec3 c = (srcTex(q).rgb * 2. + srcTex(q + vec2(0., 1.5 / uRes.y)).rgb + srcTex(q - vec2(0., 1.5 / uRes.y)).rgb) / 4.;
  // ④ 棱边：接缝处一条亮线 + 一侧暗线（立体感）
  float edge = smoothstep(.44, .5, abs(f));
  c += shine * edge * step(0., f) * .6;
  c *= 1. - shine * .5 * edge * step(f, 0.);
  c *= .96 + .06 * cos(f * 3.1416);                    // 棱中心略亮
  return vec4(c, 1.);
}
