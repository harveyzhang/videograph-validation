/*@effect
{
  "id": "gen-nebula",
  "name": "星云背景",
  "kind": "post",
  "category": "生成层",
  "tags": ["nebula", "space", "galaxy", "cosmic", "background", "星云", "宇宙", "银河", "星空背景"],
  "summary": "在画面的暗部背景里生成一片缓慢翻涌的彩色星云（紫/青/洋红的气体层次 + 暗尘带 + 细密星点），前景的亮部主体保持原样；音乐能量越高星云越亮。",
  "when": "太空/科幻/梦幻题材、宏大的开场、冥想与氛围音乐、把纯黑背景变成宇宙。",
  "avoid": "前景与背景亮度接近的画面（无法区分前后）；写实地面场景。",
  "params": {
    "colorA": { "type": "color", "default": "#7a3cff", "label": "星云色 A" },
    "colorB": { "type": "color", "default": "#18c6e8", "label": "星云色 B" },
    "colorC": { "type": "color", "default": "#ff3d8b", "label": "星云色 C" },
    "brightness": { "type": "float", "default": 0.7, "min": 0, "max": 1.5, "label": "亮度" },
    "stars": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "星点" },
    "behind": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "背景判定亮度（1 = 整屏）" },
    "glow": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量增亮（通常由音乐能量驱动）" }
  },
  "bindings": { "glow": { "to": "energy", "amount": 0.4 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：宇宙背景", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：星云是被附近恒星照亮的星际气体与尘埃——电离的氢发红/品红光、氧发青绿光；尘埃不发光而是遮挡，形成暗带；
// 长时间曝光的天文照片里，星云层层叠叠、边缘卷曲，前景布满密密麻麻的星。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  float t = uTime * .02;
  // ① 气体：两层扭曲的分形噪声（域扭曲让边缘卷曲）
  vec2 w = vec2(fxFbm(p * 1.5 + t), fxFbm(p * 1.5 - t + 4.));
  float g1 = fxFbm(p * 2. + w * 1.8 + t * 2.);
  float g2 = fxFbm(p * 3.2 - w * 1.2 + 8.);
  // ② 上色：不同气体层混合三种颜色
  vec3 neb = colorA * smoothstep(.35, .85, g1) + colorB * smoothstep(.45, .9, g2) * .8 + colorC * smoothstep(.55, .95, g1 * g2 * 1.8) * .9;
  // ③ 尘埃暗带：另一层噪声挖暗
  float dust = smoothstep(.45, .7, fxFbm(p * 2.5 + w * 2.5 + 2.));
  neb *= 1. - dust * .75;
  neb *= brightness * (1. + glow);
  // ④ 星点：大小不一，少量带十字光芒
  vec2 gs = floor(uv * uRes / 2.);
  float h = fxHash(gs);
  float st = step(.996, h) * (.5 + .5 * sin(uTime * 2. + h * 50.)) + step(.9995, h) * 1.5;
  neb += vec3(.9, .95, 1.) * st * stars;
  // ⑤ 只替换背景
  float bg = behind >= .999 ? 1. : smoothstep(behind + .12, behind - .08, fxLuma(src));
  vec3 c = mix(src, max(src, neb), bg);
  return vec4(c, 1.);
}
