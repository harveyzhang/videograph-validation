/*@effect
{
  "id": "smoke-reveal",
  "name": "烟雾显现转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["smoke", "mist", "fog transition", "mystic", "reveal", "烟雾", "雾化", "神秘", "显现"],
  "summary": "一团翻滚的灰白烟雾从画面底部涌起、盖住旧镜头，烟雾在最浓时换成下一个镜头，然后向上飘散、从稀薄处逐渐露出新画面。",
  "when": "魔法/神秘/恐怖、梦境与回忆、舞台登场、“时空转换”的段落。",
  "avoid": "明快的商务与科技风格。时长建议 0.8–1.5 秒。",
  "params": {
    "smoke": { "type": "color", "default": "#cfcfd4", "label": "烟色" },
    "density": { "type": "float", "default": 1, "min": 0.3, "max": 1.5, "label": "浓度" },
    "curl": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "翻卷" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：烟雾转场", "note": "按思路自写；与 gl-transitions 的 perlin/dissolve 不同：烟从底部涌起、峰值换镜、向上散去，带光照明暗" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（舞台烟机/魔术）：一股浓烟从地面涌起，把演员整个罩住；烟散去时，台上已经换了人。
// 实现：上升的分形烟雾场，覆盖率随进度先升后降；底部先被盖住、顶部先被露出（烟往上飘）。

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 q = uv * vec2(ratio, 1.) * 2.5;
  // ① 烟雾场：向上流动 + 翻卷扭曲
  float t = p * 3.;
  vec2 w = vec2(fxFbm(q + vec2(0., -t)), fxFbm(q + vec2(5., -t * 1.2))) - .5;
  float n = fxFbm(q * 1.3 + w * curl * 2. + vec2(0., -t * 1.5));
  // ② 覆盖率：前半从底部涌起盖满，后半从顶部往下散开
  float cover;
  if (p < .5) cover = smoothstep(0., 1., (p * 2.) * 1.6 - uv.y + (n - .5) * .8);
  else cover = smoothstep(0., 1., (1. - (p - .5) * 2.) * 1.6 - (1. - uv.y) * .6 + (n - .5) * .8);
  cover = clamp(cover * density, 0., 1.);
  // ③ 烟的明暗：上方受光亮、下方偏暗
  vec3 sc = smoke * (.7 + .5 * n + .1 * uv.y);
  vec3 base = p < .5 ? getFromColor(uv).rgb : getToColor(uv).rgb;
  return vec4(mix(base, sc, cover), 1.);
}
