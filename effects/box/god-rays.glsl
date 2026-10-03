/*@effect
{
  "id": "god-rays",
  "name": "体积光（耶稣光）",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["god rays", "volumetric light", "light shafts", "crepuscular", "体积光", "丁达尔"],
  "summary": "画面里的亮部向光源方向拉出一束束光柱，暗部挡光形成阴影条纹，像雾里的丁达尔效应。",
  "when": "逆光、日出日落、教堂窗光、舞台追光、标题从光里浮现；情绪上用于神圣、希望、揭晓。",
  "avoid": "整体很暗且没有亮部的镜头（无光可散）；满屏高亮时会整体发灰发白，先降低强度或提高阈值。",
  "params": {
    "lightX": { "type": "float", "default": 0.62, "min": 0, "max": 1, "label": "光源位置 X" },
    "lightY": { "type": "float", "default": 0.66, "min": 0, "max": 1, "label": "光源位置 Y（下 0 上 1）" },
    "reach": { "type": "float", "default": 0.55, "min": 0.05, "max": 1, "label": "光柱长度" },
    "threshold": { "type": "float", "default": 0.45, "min": 0, "max": 0.95, "label": "发光阈值" },
    "intensity": { "type": "float", "default": 0.65, "min": 0, "max": 3, "label": "光柱强度" },
    "tint": { "type": "color", "default": "#ffd9a0", "label": "光色" }
  },
  "bindings": { "intensity": { "to": "kick", "amount": 0.35 } },
  "inspiredBy": [{ "source": "xrayluan-video-prompts", "ref": "README：god rays / volumetric light 类提示词", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：光穿过有雾/尘的空气，被微粒散射进镜头；光路上有遮挡物的地方没有散射光，于是出现一条条明暗光柱。
// 镜头里每个像素看到的散射光 = 它与光源之间这段“光路”上所有亮处的累加（越靠近光源衰减越少）。
vec4 effect(vec2 uv) {
  vec3 base = srcTex(uv).rgb;

  // ① 光路：从当前像素朝光源走 15 步（加上原图共 16 次采样），步长 = 到光源距离 × 光柱长度 / 15。
  //    起点按 4×4 有序抖动错开（比纯随机颗粒更细更匀），把 15 步的离散台阶融成连续的雾。
  vec2 L = vec2(lightX, lightY);
  vec2 stepv = (L - uv) * reach / 15.;
  vec2 p = uv + stepv * fxBayer4(floor(uv * uRes));

  // ② 散射：只有“亮到能当光源”的像素才贡献光（阈值以上的部分），暗处等于挡光物。
  //    每走一步衰减一次（雾里的光会被吸收），离光源越远的部分越淡。
  vec3 acc = vec3(0.);
  float w = 1., wsum = 0.;
  for (int i = 0; i < 15; i++) {
    vec3 s = srcTex(p).rgb;
    float m = smoothstep(threshold, 1., fxLuma(s));
    acc += mix(s, vec3(fxLuma(s)), .4) * m * w;
    wsum += w;
    w *= .93;
    p += stepv;
  }
  acc /= wsum;

  // ③ 光源附近的空气更亮：以光源为中心再加一层很淡的径向雾，让光柱有“出处”。
  float haze = exp(-3.5 * distance(uv * vec2(uRes.x / uRes.y, 1.), L * vec2(uRes.x / uRes.y, 1.)));

  // ④ 合成：散射光是加到画面上的（屏幕混合，亮处不会爆成死白），乘光色；intensity 挂鼓点——鼓点那一下光柱“喷”出来再回落。
  vec3 rays = (acc * 1.7 + haze * .12) * tint * intensity;
  vec3 c = 1. - (1. - base) * (1. - clamp(rays, 0., 1.));
  return vec4(c, 1.);
}
