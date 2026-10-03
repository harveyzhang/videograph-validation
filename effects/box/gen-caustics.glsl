/*@effect
{
  "id": "gen-caustics",
  "name": "水面焦散",
  "kind": "post",
  "category": "生成层",
  "tags": ["caustics", "underwater", "pool", "water light", "ripple", "焦散", "水下", "泳池", "水光"],
  "summary": "画面上投下一层流动的水面焦散光网（像阳光穿过泳池水面照到池底），同时画面随水波轻微折射晃动；每一拍水面被拨动一下。",
  "when": "水下/泳池/海边/夏日、清凉饮料与护肤品、梦境与漂浮感。",
  "avoid": "需要稳定细节的文字镜头（折射会让字晃）；干燥的沙漠与室内场景。",
  "params": {
    "scale": { "type": "float", "default": 6, "min": 2, "max": 20, "label": "光网密度" },
    "brightness": { "type": "float", "default": 0.55, "min": 0, "max": 1.5, "label": "光网亮度" },
    "refract": { "type": "float", "default": 0.004, "min": 0, "max": 0.02, "label": "折射晃动" },
    "ripple": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "拨水（通常由节拍驱动）" },
    "tint": { "type": "color", "default": "#bff6ff", "label": "水光颜色" }
  },
  "bindings": { "ripple": { "to": "beat", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：水光/焦散", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：起伏的水面像一堆不断变形的小透镜，把阳光汇聚成池底那张明亮的网（焦散），网格边缘最亮、
// 网眼里偏暗；同一片水面也让我们透过它看到的东西轻微晃动（折射）。
// 实现：两层移动的“细胞”图案（到最近两点的距离差），在细胞边界处亮——近似焦散网；两层相乘更像真实的交叠光纹。

// 细胞边界亮度：到最近与次近随机点的距离差越小越亮（3×3 邻格，纯计算）
float cells(vec2 p, float t) {
  vec2 ip = floor(p);
  float d1 = 9., d2 = 9.;
  for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
    vec2 id = ip + vec2(float(i), float(j));
    vec2 o = .5 + .45 * sin(t * (.6 + fxHash(id) * .6) + 6.2832 * vec2(fxHash(id + 1.), fxHash(id + 2.)));
    float d = length(p - id - o);
    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
  }
  return 1. - smoothstep(0., .18, d2 - d1);
}

vec4 effect(vec2 uv) {
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y) * scale;

  // ① 水面：两层不同速度/方向的细胞网；ripple 挂每拍——每拍水面被拨动，网格一下子加速变形。
  float t = uTime * (1. + ripple * 1.5);
  float a = cells(p + vec2(t * .1, 0.), t);
  float b = cells(p * 1.3 - vec2(0., t * .08) + 4.7, t * 1.2);
  float net = pow(a * .6 + b * .4, 2.) + a * b * .6;

  // ② 折射：同一张水面的起伏让画面轻微偏移（偏移方向取自两层网的差，1 次采样）。
  vec2 off = vec2(a - b, b - a * .7) * refract * (1. + ripple);
  vec3 src = srcTex(uv + off).rgb;

  // ③ 合成：焦散光是加上去的（screen），暗部受影响更明显（水光照在阴影里最显眼）。
  vec3 c = 1. - (1. - src) * (1. - clamp(tint * net * brightness, 0., 1.));
  return vec4(c, 1.);
}
