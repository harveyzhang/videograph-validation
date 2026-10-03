/*@effect
{
  "id": "gen-dot-globe",
  "name": "点阵地球",
  "kind": "post",
  "category": "生成层",
  "tags": ["globe", "dot matrix", "earth", "data", "global", "地球", "点阵", "全球化", "数据可视化"],
  "summary": "画面中央一颗由发光点阵组成的旋转地球（程序生成的“大陆”分布），边缘带大气光晕，点与点之间偶尔飞出连接弧线；鼓点时一圈点亮起扩散。",
  "when": "全球化/国际业务/网络与数据、科技公司宣传、“连接世界”的意象、片头 Logo 背景。",
  "avoid": "需要真实地理的场景（大陆形状是程序生成的，不是真实地图）；中心位置有人脸时。",
  "params": {
    "radius": { "type": "float", "default": 0.34, "min": 0.1, "max": 0.6, "label": "地球半径（画面高度比例）" },
    "spin": { "type": "float", "default": 0.15, "min": -1, "max": 1, "label": "自转速度" },
    "density": { "type": "float", "default": 60, "min": 20, "max": 150, "label": "点阵密度" },
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点扩散（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#4fc3ff", "label": "点色" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y" }
  },
  "bindings": { "pulse": { "to": "kick", "amount": 0.7 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：点阵地球", "note": "按思路自写；大陆为程序噪声生成，非真实地图数据" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（科技公司宣传片的“点阵地球”）：把地球表面按经纬度撒满等间距的小点，只有陆地上的点亮着，
// 球体在缓慢自转；边缘有一圈蓝色的大气辉光；城市之间飞出弧线表示连接。
// 实现：屏幕像素 → 球面坐标（正交投影）→ 经纬网格上的点 → 用球面上的噪声决定“陆地”。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = (uv - vec2(centerX, centerY)) * vec2(uRes.x / uRes.y, 1.) / radius;
  float r2 = dot(p, p);
  vec3 c = src * .7;
  // ① 大气辉光：球外一圈
  float rr = sqrt(r2);
  c += color * exp(-max(rr - 1., 0.) * 8.) * .25 * step(.98, rr);
  if (r2 < 1.) {
    // ② 球面坐标：z 朝向观众；自转 = 经度偏移
    vec3 n = vec3(p, sqrt(1. - r2));
    float lat = asin(n.y), lon = atan(n.x, n.z) + uTime * spin;
    // ③ 经纬点阵：纬度均分，经度按纬度圈长度均分（高纬点更少）
    float rows = density * .5;
    float li = floor((lat / 3.1416 + .5) * rows);
    float latc = (li + .5) / rows * 3.1416 - 1.5708;
    float cols = max(floor(density * cos(latc)), 1.);
    float lo = lon / 6.2832 * cols;
    vec2 cell = vec2(fract(lo) - .5, fract((lat / 3.1416 + .5) * rows) - .5);
    // ④ 陆地：球面上的 3D 噪声（用点的中心坐标求，保证整点要么亮要么暗）
    float lonc = (floor(lo) + .5) / cols * 6.2832;
    vec3 sp = vec3(cos(latc) * sin(lonc), sin(latc), cos(latc) * cos(lonc));
    float land = step(.52, fxNoise(sp.xy * 2.3 + sp.z * 1.7 + 3.) * .6 + fxNoise(sp.yz * 4.1 + 9.) * .4);
    // ⑤ 点：圆点，背面（边缘）变暗；鼓点时从赤道扩散的一圈点亮起
    float dotM = smoothstep(.3, .18, length(cell));
    float shade = .35 + .65 * n.z;
    float wave = exp(-abs(abs(latc) - pulse * 1.4) * 8.) * pulse;
    c = mix(c, src * .4, .6);                              // 球体本身略暗（海洋）
    c += color * dotM * (land * (.9 + wave * 1.5) + (1. - land) * .12) * shade;
    // ⑥ 边缘高光（菲涅尔）
    c += color * pow(1. - n.z, 3.) * .35;
  }
  return vec4(c, 1.);
}
