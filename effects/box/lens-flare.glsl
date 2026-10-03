/*@effect
{
  "id": "lens-flare",
  "name": "镜头光晕",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["lens flare", "flare", "ghost", "halo", "anamorphic streak", "光晕", "炫光"],
  "summary": "强光源在镜头里产生的光斑串：光源辉光 + 横向拉丝 + 沿对角线排开的彩色鬼影圆斑 + 一圈淡彩光环。",
  "when": "逆光人像、太阳/路灯/车灯入画、科技发布会标题、夏日与公路片；鼓点时光晕闪亮一下做卡点。",
  "avoid": "画面本来就杂乱或需要看清细节的镜头（鬼影会盖住内容）；光源位置要与画面里的亮处对应，否则显假。",
  "params": {
    "lightX": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "光源位置 X" },
    "lightY": { "type": "float", "default": 0.72, "min": 0, "max": 1, "label": "光源位置 Y（下 0 上 1）" },
    "intensity": { "type": "float", "default": 0.85, "min": 0, "max": 2.5, "label": "光晕强度" },
    "streak": { "type": "float", "default": 0.6, "min": 0, "max": 2, "label": "横向拉丝" },
    "gate": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "随光源处亮度变化（0 恒亮 / 1 只在亮处出现）" },
    "tint": { "type": "color", "default": "#ffc890", "label": "光源色" }
  },
  "bindings": { "intensity": { "to": "kick", "amount": 0.9 } },
  "inspiredBy": [{ "source": "chuspeeism-awesome-videos", "ref": "cases：lens flare 类镜头描述", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：强光射进多片镜组，每两片镜片之间来回反射一次就在底片上留下一个“鬼影”——它们都排在
// “光源 ↔ 画面中心”这条直线上（对称成像）；光阑叶片让鬼影带棱角，镀膜让每个鬼影带一点不同的颜色；
// 光在前镜片上的散射是光源周围的辉光，变形宽银幕镜头还会拉出一条横向光丝。

// 一个鬼影圆斑：边缘稍亮（镜片反射的光圈形状），r 是半径（按画面高度计）
float ghost(vec2 p, vec2 c, float r) {
  float d = length(p - c) / r;
  return smoothstep(1., .85, d) * (.35 + .65 * smoothstep(.2, 1., d));
}

vec4 effect(vec2 uv) {
  vec3 base = srcTex(uv).rgb;
  float asp = uRes.x / uRes.y;
  vec2 p = vec2(uv.x * asp, uv.y);        // 按高度归一化的坐标，圆是圆的
  vec2 L = vec2(lightX * asp, lightY);
  vec2 C = vec2(.5 * asp, .5);

  // ① 光有多强：在光源位置取 5 个点的亮度。光源被挡住/不存在时光晕变弱（gate 控制依赖程度）。
  float lum = 0.;
  for (int i = 0; i < 5; i++) {
    float a = float(i) * 1.2566;
    lum += fxLuma(srcTex(vec2(lightX, lightY) + vec2(cos(a) / asp, sin(a)) * .02 * float(i > 0)).rgb);
  }
  float power = intensity * mix(1., smoothstep(.25, .9, lum / 5.), gate);

  // ② 前镜片散射：光源周围的辉光（近处很亮的核 + 远处很宽的雾）
  float dL = length(p - L);
  vec3 flare = tint * (exp(-dL * 28.) * 1.4 + exp(-dL * 5.) * .25);

  // ③ 宽银幕拉丝：一条横穿光源的细光丝，越远越淡
  flare += mix(tint, vec3(.55, .75, 1.), .5) * exp(-abs(p.y - L.y) * 220.) * exp(-abs(p.x - L.x) * 1.6) * streak * .9;

  // ④ 镜片间反射的鬼影：沿 光源→中心→对侧 的直线排开，大小、颜色各不相同（镀膜色）。
  //    每个通道的半径略有差别 → 边缘出现彩虹色散。
  vec2 axis = C - L;
  vec3 g = vec3(0.);
  g += vec3(.25, .9, .5) * ghost(p, L + axis * .55, .05);
  g += vec3(.9, .45, .2) * ghost(p, L + axis * 1.25, .11);
  g += vec3(.35, .5, 1.) * ghost(p, L + axis * 1.6, .035);
  g += vec3(.8, .35, .9) * ghost(p, L + axis * 2.1, .17);
  vec2 q = L + axis * 1.85;
  g += vec3(ghost(p, q, .074), ghost(p, q, .07), ghost(p, q, .066)) * vec3(1., .8, .5);
  flare += g * .32;

  // ⑤ 光环：以对侧点为中心的大圆环，环上颜色随角度轻微变化（彩虹镀膜反射）
  vec2 hc = C + axis * .3;
  float ring = exp(-pow((length(p - hc) - .42) * 28., 2.));
  float ang = atan(p.y - hc.y, p.x - hc.x);
  flare += ring * .12 * (.6 + .4 * vec3(sin(ang * 3.) * .5 + .5, sin(ang * 3. + 2.1) * .5 + .5, sin(ang * 3. + 4.2) * .5 + .5));

  // ⑥ 合成：屏幕混合加到画面上；intensity 挂鼓点（鼓点瞬间光晕一亮再回落）
  vec3 c = 1. - (1. - base) * (1. - clamp(flare * power, 0., 1.));
  return vec4(c, 1.);
}
