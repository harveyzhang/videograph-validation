/*@effect
{
  "id": "faded-print",
  "name": "褪色电影拷贝",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["faded film", "vintage print", "magenta shift", "70s", "褪色", "老拷贝", "偏品红"],
  "summary": "放了几十年的电影拷贝：青色染料褪掉、画面整体偏品红偏橙，黑位发灰、反差变低，片子上有偶尔闪过的白点和细划痕、轻微的亮度呼吸。",
  "when": "70/80 年代回忆、家庭录像式怀旧、复古广告、旧时代的故事段落、“时间流逝”的表达。",
  "avoid": "需要准确颜色的镜头；与 sepia-oldfilm（黑白泛黄）不同，这个仍然是彩色的——两者别叠用。",
  "params": {
    "fade": { "type": "float", "default": 0.65, "min": 0, "max": 1, "label": "褪色程度" },
    "magenta": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "偏品红" },
    "lift": { "type": "float", "default": 0.12, "min": 0, "max": 0.35, "label": "黑位发灰" },
    "damage": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "白点与划痕" },
    "breath": { "type": "float", "default": 0.02, "min": 0, "max": 0.08, "label": "亮度呼吸" }
  },
  "bindings": { "breath": { "to": "beat", "amount": 0.025 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/silent-film：老片观感", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：老式彩色电影拷贝的三种染料稳定性不同，青色染料最先褪，其次是黄色，品红最稳——
// 所以几十年后的拷贝整体偏品红/偏橙红，蓝天变紫灰，绿色变土黄；染料变淡也让黑位发灰、反差下降。
// 拷贝每次放映都会落灰、被片门刮花：白点（灰尘在负片上是白的）一闪而过，细竖线划痕时有时无；
// 老放映机的灯和快门不稳，画面亮度会轻微“呼吸”。

vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;

  // ① 染料褪色：青染料（控制红通道的“减法”）褪得最多 → 红通道变亮；黄染料（控制蓝）其次 → 蓝通道略亮。
  //    品红最稳，绿通道几乎不变 → 整体偏品红。
  c.r = mix(c.r, c.r * .75 + .3, fade * magenta);
  c.b = mix(c.b, c.b * .85 + .12, fade * .6);
  c.g = mix(c.g, c.g * .92, fade * magenta * .5);

  // ② 反差下降、黑位发灰（染料密度不够，最暗处也有光透过来）。
  c = mix(c, c * (1. - lift) + lift * vec3(.55, .42, .45), fade);
  c = mix(vec3(fxLuma(c)), c, 1. - fade * .3);

  // ③ 亮度呼吸：放映灯的轻微起伏。breath 挂每拍——每拍一次很小的亮度起伏（幅度很小，远低于光敏阈值）。
  c *= 1. + breath * (fxNoise(vec2(uTime * 3., 1.)) - .3);

  // ④ 灰尘白点：画面按 12 次/秒抽一个随机种子，少量位置出现不规则小白点（每帧不同位置，单点很小）。
  float frame = floor(uTime * 12.);
  vec2 cell = floor(uv * vec2(28., 16.));
  vec2 dpos = vec2(fxHash(cell + frame), fxHash(cell + frame + 7.));
  float dust = step(.985 - damage * .02, fxHash(cell * 1.3 + frame * 2.1)) * smoothstep(.012, .0, length((fract(uv * vec2(28., 16.)) - dpos) * vec2(28., 16.) / 16.));
  c = mix(c, vec3(.95, .92, .88), dust * damage);

  // ⑤ 片门划痕：1–2 条很细的竖线，位置在几秒内缓慢游走、时有时无。
  float sx = fxHash(vec2(floor(uTime * .5), 3.));
  float scratch = smoothstep(1.2, 0., abs(uv.x - sx - sin(uTime * 1.3) * .01) * uRes.x) * step(.4, fxHash(vec2(frame, 9.)));
  c = mix(c, vec3(.9, .88, .85), scratch * damage * .6);
  return vec4(clamp(c, 0., 1.), 1.);
}
