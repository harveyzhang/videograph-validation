/*@effect
{
  "id": "hex-tiles",
  "name": "六边形瓷砖马赛克",
  "kind": "post",
  "category": "几何与图形",
  "tags": ["hexagon", "mosaic", "tiles", "honeycomb", "蜂巢", "六边形", "马赛克"],
  "summary": "画面铺成一块块六边形釉面瓷砖：每块平涂一色、带倒角高光，砖缝是浅色灰浆；鼓点时砖缝一收一放。",
  "when": "科技/蜂巢/网络主题、游戏地图、复古公共空间、片头标题衬底；大色块画面最好看。",
  "avoid": "小字与细节多的镜头；需要识别人脸的特写（砖太大会糊掉五官）。",
  "params": {
    "size": { "type": "float", "default": 22, "min": 6, "max": 80, "label": "六边形大小（像素）" },
    "grout": { "type": "float", "default": 0.08, "min": 0, "max": 0.3, "label": "砖缝宽度" },
    "groutColor": { "type": "color", "default": "#e8e2d4", "label": "灰浆颜色" },
    "glaze": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "釉面高光" }
  },
  "bindings": { "grout": { "to": "kick", "amount": 0.08 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：网格化/马赛克过渡", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：瓷砖马赛克是工匠按原稿颜色挑选一块块单色瓷砖贴在墙上，砖与砖之间用灰浆填缝；
// 每块瓷砖表面上釉，边缘烧制时略圆，所以边缘有一圈倒角高光/暗边，整面墙看起来像凹凸的格子。

vec4 effect(vec2 uv) {
  // ① 排砖：把像素坐标映射到六边形网格（尖顶朝上的蜂巢排布），求所在砖的中心和像素在砖内的位置。
  vec2 p = uv * uRes / size;
  vec2 r = vec2(1., 1.7320508);
  vec2 h = r * .5;
  vec2 a = mod(p, r) - h;
  vec2 b = mod(p - h, r) - h;
  vec2 gv = dot(a, a) < dot(b, b) ? a : b;    // 像素相对砖中心的位置
  vec2 center = p - gv;

  // ② 选砖：每块砖只取中心一点的颜色（真实马赛克就是一块一色），再按“砖库里只有有限种颜色”略微量化。
  vec3 col = srcTex(center * size / uRes).rgb;
  col = floor(col * 12. + .5) / 12.;
  col *= .96 + .08 * fxHash(center);          // 不同批次烧制的砖有轻微色差

  // ③ 到砖边的距离：六边形的“半径”是 0.5（边心距），dEdge 越小越靠近砖缝。
  vec2 q = abs(gv);
  float dHex = max(dot(q, normalize(vec2(1., 1.7320508))), q.x);
  float dEdge = .5 - dHex;

  // ④ 釉面倒角：砖边一圈，左上方的光照到倒角时亮、右下方暗；中心偏上有一点高光反射。
  float bevel = smoothstep(.12, 0., dEdge);
  float side = dot(normalize(gv + 1e-4), normalize(vec2(-1., 1.)));
  col *= 1. + bevel * side * .25 * glaze * 2.;
  col += glaze * .25 * exp(-dot(gv - vec2(-.12, .15), gv - vec2(-.12, .15)) * 30.);

  // ⑤ 灰浆：离砖边小于砖缝宽度的部分填灰浆（略带阴影）。grout 挂鼓点：鼓点时缝宽一涨，像墙面“呼吸”。
  float px = 1. / size;
  float g = smoothstep(grout * .5 + px, grout * .5, dEdge);
  col = mix(col, groutColor * (.85 + .15 * fxNoise(uv * uRes * .5)), g);
  return vec4(col, 1.);
}
