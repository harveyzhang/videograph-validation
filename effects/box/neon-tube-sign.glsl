/*@effect
{
  "id": "neon-tube-sign",
  "name": "霓虹灯管",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["neon", "neon sign", "tube", "flicker", "cyberpunk", "霓虹灯", "灯牌"],
  "summary": "轮廓变成一根根发光的玻璃灯管（白热管芯 + 饱和色外壁 + 宽光晕），背景是被灯照亮的暗墙，偶尔有一段灯管接触不良地闪。",
  "when": "夜店、街头、赛博朋克、复古 diner、文字标题与 Logo；适合鼓点处灯管一亮的卡点。",
  "avoid": "白天大场景或细节繁杂的画面（轮廓太多会变成一团乱线）；需要看清人物表情时慎用。",
  "params": {
    "gasA": { "type": "color", "default": "#ff2a8a", "label": "灯管颜色 A（暖）" },
    "gasB": { "type": "color", "default": "#20d8ff", "label": "灯管颜色 B（冷）" },
    "thickness": { "type": "float", "default": 2.5, "min": 1, "max": 6, "label": "灯管粗细（像素）" },
    "glow": { "type": "float", "default": 0.8, "min": 0, "max": 2, "label": "光晕" },
    "wall": { "type": "float", "default": 0.18, "min": 0, "max": 0.6, "label": "墙面可见度" },
    "faulty": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "接触不良" }
  },
  "bindings": { "glow": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "lievan-video-prompts", "ref": "prompts/worlds：neon sign 场景描述", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：霓虹灯是把玻璃管弯成字形/轮廓，管里充惰性气体，高压放电时管芯最亮（发白），
// 管壁透出气体的饱和色，光再照到后面的墙上形成一大片柔和的光晕；老化的变压器会让某一段管时亮时暗。
// 和 neon-edges（发光描边）的区别：这里模拟“有粗细的灯管 + 墙面反光 + 分段故障”，背景不是原图而是暗墙。

// 在半径 r（像素）处的亮度梯度：|L(x+r)-L(x-r)| + |L(y+r)-L(y-r)|，r 越大得到的“边缘带”越宽
float edgeAt(vec2 uv, float r) {
  vec2 o = r / uRes;
  float gx = fxLuma(srcTex(uv + vec2(o.x, 0.)).rgb) - fxLuma(srcTex(uv - vec2(o.x, 0.)).rgb);
  float gy = fxLuma(srcTex(uv + vec2(0., o.y)).rgb) - fxLuma(srcTex(uv - vec2(0., o.y)).rgb);
  return abs(gx) + abs(gy);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 弯管：画面里的轮廓就是灯管走向。小半径梯度 = 管身，大半径梯度 = 管外的光（共 9 次采样）。
  float tube = smoothstep(.12, .45, edgeAt(uv, thickness));
  float halo = smoothstep(.02, .5, edgeAt(uv, thickness * 5.));

  // ② 充气颜色：每根管只能充一种气体。按大块区域（约 1/6 屏）哈希分配暖/冷两色，并参考原图冷暖。
  vec2 cell = floor(uv * vec2(4., 3.));
  float warm = step(.5, fxHash(cell + 7.) * .6 + (src.r - src.b) * .8 + .2);
  vec3 gas = mix(gasB, gasA, warm);

  // ③ 接触不良：只有少数格子（不是全屏）在某段时间里以约 6 次/秒的节奏亮暗，最暗也留 35%，避免光敏风险。
  float bad = step(1. - faulty * .35, fxHash(cell + floor(uTime * .5)));
  float stutter = mix(1., mix(.35, 1., step(.45, fxHash(cell + floor(uTime * 6.)))), bad);

  // ④ 放电发光：管芯发白 → 管壁饱和色 → 外部光晕（glow 挂鼓点：鼓点时整排灯管电压一冲）。
  vec3 core = mix(gas, vec3(1.), .65) * smoothstep(.55, 1., tube);
  vec3 body = gas * tube * 1.2;
  vec3 light = (core + body) * stutter + gas * halo * glow * .55 * stutter;

  // ⑤ 墙面：原图压暗、去饱和、偏冷，像夜里被灯照着的砖墙；砖缝用像素尺度的网格做极淡的纹理。
  vec2 bp = uv * uRes / 18.;
  bp.x += floor(bp.y) * .5;
  float mortar = smoothstep(.06, 0., min(fract(bp.x), fract(bp.y)) * .5);
  vec3 wallc = mix(vec3(fxLuma(src)), src, .4) * wall * vec3(.8, .85, 1.) * (1. - mortar * .4);

  return vec4(wallc + light, 1.);
}
