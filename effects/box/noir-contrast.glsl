/*@effect
{
  "id": "noir-contrast",
  "name": "黑色电影",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["film noir", "black and white", "high contrast", "venetian blinds", "detective", "黑色电影", "黑白", "百叶窗光", "侦探"],
  "summary": "40 年代黑色电影：高反差黑白、深重的阴影、强烈的硬光，画面上斜投一组百叶窗的光影条纹，带胶片颗粒与暗角；光影条纹随小节缓慢移动。",
  "when": "侦探/悬疑/犯罪、复古爵士、独白与回忆、冷峻的叙事。",
  "avoid": "明快温暖的题材；彩色是重点的镜头。",
  "params": {
    "contrast": { "type": "float", "default": 1.7, "min": 1, "max": 3, "label": "反差" },
    "blinds": { "type": "float", "default": 0.55, "min": 0, "max": 1, "label": "百叶窗光影" },
    "slats": { "type": "float", "default": 9, "min": 3, "max": 30, "label": "条纹数" },
    "angle": { "type": "float", "default": 0.5, "min": -1.2, "max": 1.2, "label": "光影角度" },
    "drift": { "type": "float", "default": 0, "min": 0, "max": 0.2, "label": "光影移动（通常由小节驱动）" },
    "grain": { "type": "float", "default": 0.06, "min": 0, "max": 0.15, "label": "颗粒" }
  },
  "bindings": { "drift": { "to": "bar", "amount": 0.05 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/silent-film 与 spy-titles：黑白与硬光", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（Film Noir）：低调布光——大面积阴影，只用几盏硬光；最标志性的是光透过百叶窗打在墙上和人物身上的平行条纹；
// 黑白胶片的颗粒与镜头暗角让画面更沉重。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 黑白 + 高反差（以 0.45 为中点的强 S 曲线）
  float l = fxLuma(src);
  l = clamp((l - .45) * contrast + .45, 0., 1.);
  l = l * l * (3. - 2. * l);
  // ② 百叶窗光影：斜向平行条纹，亮条照亮、暗条压暗；边缘略软（光源有尺寸）
  vec2 p = uv * vec2(uRes.x / uRes.y, 1.);
  float s = (p.x * cos(angle) + p.y * sin(angle)) * slats + drift * slats;
  float stripe = smoothstep(.35, .5, abs(fract(s) - .5));
  // 条纹只投在画面的一片区域（像从一侧窗户照进来）
  float area = smoothstep(.1, .6, uv.x + uv.y * .3);
  l *= 1. - blinds * .7 * (1. - stripe) * area;
  l += blinds * .12 * stripe * area * l;
  // ③ 颗粒（24 次/秒刷新，很小）+ 暗角
  l += (fxHash(floor(uv * uRes / 1.5) + floor(uTime * 24.)) - .5) * grain;
  l *= 1. - .5 * smoothstep(.35, 1.1, length((uv - .5) * vec2(uRes.x / uRes.y, 1.)));
  return vec4(vec3(clamp(l, 0., 1.)), 1.);
}
