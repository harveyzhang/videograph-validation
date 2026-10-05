/*@effect
{
  "id": "gen-kaleido-mandala",
  "name": "旋转曼陀罗",
  "kind": "post",
  "category": "生成层",
  "tags": ["mandala", "sacred geometry", "rotating", "pattern", "psychedelic", "曼陀罗", "神圣几何", "图案", "冥想"],
  "summary": "在画面中心生成一个由多层花瓣、圆环和点阵组成的发光曼陀罗图案，各层以不同速度反向旋转，颜色取自画面本身；每拍一层花瓣向外绽放。只覆盖暗部背景，主体保持原样。",
  "when": "冥想/瑜伽/灵性、迷幻与电子乐、民族与宗教题材、Logo 背景装饰。",
  "avoid": "写实叙事；中心是人脸的特写。",
  "params": {
    "petals": { "type": "float", "default": 8, "min": 3, "max": 24, "label": "花瓣数" },
    "radius": { "type": "float", "default": 0.45, "min": 0.1, "max": 1, "label": "大小（画面高度比例）" },
    "spin": { "type": "float", "default": 0.15, "min": -1, "max": 1, "label": "旋转速度" },
    "color": { "type": "color", "default": "#ffcf6e", "label": "主色" },
    "behind": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "背景判定亮度（1 = 覆盖整屏）" },
    "bloom": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "节拍绽放（通常由节拍驱动）" }
  },
  "bindings": { "bloom": { "to": "beat", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：几何图案生成", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：曼陀罗是以中心向外的同心多层对称图案——每一层由 N 重旋转对称的花瓣/圆点/弧线组成。
// 实现：极坐标下把角度折叠到一个扇区（N 重对称），每层用简单的距离场画花瓣与环线，层与层反向旋转。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = (uv - .5) * vec2(uRes.x / uRes.y, 1.) / radius;
  float r = length(p);
  float a = atan(p.y, p.x);
  float light = 0.;
  float N = floor(petals + .5);
  // ① 四层：每层自己的半径、花瓣形状、旋转方向
  for (int k = 0; k < 4; k++) {
    float K = float(k);
    float R = .25 + K * .22 + (k == 1 ? bloom * .08 : 0.);
    float rot = uTime * spin * (mod(K, 2.) < 1. ? 1. : -1.) * (1. + K * .3);
    float n = N * (1. + mod(K, 2.));
    float sec = 6.2832 / n;
    float fa = mod(a + rot, sec) - sec * .5;                 // 折叠到一个扇区
    vec2 q = vec2(cos(fa), sin(fa)) * r;
    // 花瓣：以 (R, 0) 为中心的椭圆轮廓线
    float pet = length((q - vec2(R, 0.)) / vec2(.11, .045 + .03 * K)) - 1.;
    light += smoothstep(.12, 0., abs(pet)) * .7;
    // 环线与环上的点
    light += smoothstep(.006, 0., abs(r - R - .12)) * .5;
    light += smoothstep(.022, .01, length(q - vec2(R + .12, 0.))) * .8;
  }
  light += smoothstep(.08, .0, r) + smoothstep(.01, 0., abs(r - .1)) * .6;   // 中心
  light *= smoothstep(1.25, 1., r);
  // ② 颜色：主色与画面颜色混合（让图案与画面协调）
  vec3 col = mix(color, src * 1.5 + .1, .3);
  float bg = behind >= .999 ? 1. : smoothstep(behind + .12, behind - .08, fxLuma(src));
  vec3 c = src + col * clamp(light, 0., 1.5) * bg * .8;
  return vec4(c, 1.);
}
