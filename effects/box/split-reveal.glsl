/*@effect
{
  "id": "split-reveal",
  "name": "开门分割转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["split", "doors", "reveal", "slide apart", "diagonal", "分割", "开门", "斜切", "揭示"],
  "summary": "上一个镜头沿一条斜线被切成两半，两半向相反方向滑开（像推拉门），中间露出下一个镜头；切口边缘有一道强调色光条，下一个镜头同时从略微放大缓缓回到正常。",
  "when": "产品亮相、揭示新场景、时尚与发布会、段落之间利落的过渡。",
  "avoid": "需要柔和情绪的衔接。时长建议 0.6–1 秒。",
  "params": {
    "angle": { "type": "float", "default": 0.35, "min": -1.5708, "max": 1.5708, "label": "切线角度（弧度，0 = 竖切）" },
    "edge": { "type": "float", "default": 0.006, "min": 0, "max": 0.03, "label": "切口光条宽度" },
    "edgeColor": { "type": "color", "default": "#ff4d12", "label": "光条颜色" },
    "settle": { "type": "float", "default": 0.08, "min": 0, "max": 0.3, "label": "新镜头回落幅度" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/swiss-motion：斜切揭示", "note": "只参考风格名称与观感描述，代码为本项目自写；与 gl-transitions 的 doorway/HorizontalOpen 不同：任意斜角切线 + 光条 + 新镜头回落" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（舞台的推拉门/动态设计的“斜切揭示”）：画面沿一条斜线分成两块，两块沿着切线的法线方向分开，
// 露出后面的新画面；切口处常加一条亮色光条强调动作。

vec4 transition(vec2 uv) {
  float p = progress;
  float e = 1. - pow(1. - p, 3.);                         // 缓出
  vec2 asp = vec2(ratio, 1.);
  vec2 q = (uv - .5) * asp;
  vec2 n = vec2(cos(angle), sin(angle));                 // 切线的法线方向（两半沿它分开）
  float side = dot(q, n);
  float open = e * (ratio * .5 + .6);                    // 每一半移动的距离
  // ① 两半：正侧向 +n 移动，负侧向 -n 移动；当前像素在移动后的哪一半里？
  vec2 qa = q - n * open, qb = q + n * open;
  bool inA = dot(qa, n) > 0., inB = dot(qb, n) < 0.;
  // ② 新镜头：从放大 settle 回落到 1
  float z = 1. + settle * (1. - e);
  vec3 c = getToColor((uv - .5) / z + .5).rgb;
  if (inA) c = getFromColor(qa / asp + .5).rgb;
  if (inB) c = getFromColor(qb / asp + .5).rgb;
  // ③ 切口光条：两半的切边上
  float da = abs(dot(qa, n)), db = abs(dot(qb, n));
  float bar = (smoothstep(edge, 0., da) * (inA ? 1. : 0.) + smoothstep(edge, 0., db) * (inB ? 1. : 0.)) * step(.001, p) * step(p, .999);
  c = mix(c, edgeColor, clamp(bar, 0., 1.));
  return vec4(c, 1.);
}
