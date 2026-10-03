/*@effect
{
  "id": "led-dot-matrix",
  "name": "LED 点阵屏",
  "kind": "post",
  "category": "几何与图形",
  "tags": ["led", "dot matrix", "jumbotron", "stadium screen", "billboard", "点阵", "LED 屏", "大屏"],
  "summary": "画面变成近距离看的 LED 大屏：黑底上一颗颗圆形发光灯珠，颜色分级量化，每颗灯珠有柔光；鼓点时灯珠亮度一冲。",
  "when": "演唱会、体育场、街头广告牌、电竞与发布会大屏、“画面在屏幕上播放”的镜中镜效果。",
  "avoid": "需要细节的特写（点阵会吃掉细节）；与 halftone 网点类效果连用会显杂。",
  "params": {
    "pitch": { "type": "float", "default": 9, "min": 4, "max": 30, "label": "灯珠间距（像素）" },
    "dotSize": { "type": "float", "default": 0.38, "min": 0.15, "max": 0.5, "label": "灯珠大小" },
    "bloom": { "type": "float", "default": 0.4, "min": 0, "max": 1.5, "label": "灯珠柔光" },
    "drive": { "type": "float", "default": 0.9, "min": 0.5, "max": 2.5, "label": "亮度驱动" },
    "steps": { "type": "float", "default": 14, "min": 2, "max": 32, "label": "灰阶级数" }
  },
  "bindings": { "drive": { "to": "kick", "amount": 0.3 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：屏中屏/大屏质感", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：LED 大屏由一颗颗独立的发光二极管组成，按固定间距（点距）排列；每颗灯珠只显示一种颜色，
// 驱动芯片的灰阶有限（尤其低成本屏），近看能看到黑色的底板、圆形灯珠和灯珠周围的一圈光晕。
// 和 halftone（网点大小随明暗变化）不同：LED 的灯珠大小固定，变化的是亮度。

vec4 effect(vec2 uv) {
  // ① 点距采样：每个灯珠格取一次原图颜色（灯珠中心）。
  vec2 g = uv * uRes / pitch;
  vec2 id = floor(g);
  vec2 f = fract(g) - .5;
  vec3 col = srcTex((id + .5) * pitch / uRes).rgb;

  // ② 驱动与灰阶：亮度乘驱动系数（drive 挂鼓点：鼓点那一下整屏灯珠更亮），再按有限灰阶量化。
  col = floor(clamp(col * drive, 0., 1.) * steps + .5) / steps;

  // ③ 灯珠形状：圆形发光体，中心最亮、边缘略软；灯珠之间是黑底板。
  float d = length(f);
  float dotMask = smoothstep(dotSize, dotSize - .08, d);
  float hot = smoothstep(dotSize * .6, 0., d) * .25;     // 二极管芯片在中心形成的小亮点

  // ④ 柔光：相邻 4 颗灯珠的光晕渗到当前位置（4 次采样），让屏幕看起来在“发光”而不是印刷。
  vec3 halo = vec3(0.);
  for (int k = 0; k < 4; k++) {
    vec2 o = vec2(k == 0 ? 1. : k == 1 ? -1. : 0., k == 2 ? 1. : k == 3 ? -1. : 0.);
    vec3 nc = floor(clamp(srcTex((id + o + .5) * pitch / uRes).rgb * drive, 0., 1.) * steps + .5) / steps;
    halo += nc * exp(-length(f - o) * 3.5);
  }
  halo += col * exp(-d * 3.5);

  // ⑤ 合成：底板不是纯黑（有一点环境反光），灯珠 + 芯片亮点 + 柔光。
  vec3 board = vec3(.02, .022, .028);
  vec3 c = board + col * dotMask * (1. + hot) + halo * bloom * .12;
  return vec4(c, 1.);
}
