/*@effect
{
  "id": "selective-color",
  "name": "单色保留",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["selective color", "color splash", "sin city", "isolate hue", "black and white", "单色保留", "局部彩色", "黑白留色", "罪恶之城"],
  "summary": "画面变成黑白，只保留一种颜色（默认红色）的区域仍是彩色，被保留的颜色还会被提饱和；保留的色相范围随拍轻轻扩张，像颜色在呼吸。",
  "when": "强调某个物体（红裙、红灯、品牌色产品）、黑色电影与漫画风、情绪化的独白镜头。",
  "avoid": "画面里没有目标颜色时（会变成纯黑白）；目标色在肤色附近时人脸也会被保留。",
  "params": {
    "hue": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "保留的色相（0 红、0.08 橙、0.16 黄、0.33 绿、0.5 青、0.66 蓝、0.83 品红）" },
    "range": { "type": "float", "default": 0.07, "min": 0.01, "max": 0.3, "label": "色相范围（通常由节拍驱动）" },
    "minSat": { "type": "float", "default": 0.25, "min": 0, "max": 0.9, "label": "最低饱和度（太灰的不算）" },
    "boost": { "type": "float", "default": 1.3, "min": 1, "max": 2, "label": "保留色提饱和" },
    "contrast": { "type": "float", "default": 1.2, "min": 0.6, "max": 2, "label": "黑白反差" }
  },
  "bindings": { "range": { "to": "beat", "amount": 0.03 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：调色", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（《辛德勒的名单》的红衣女孩、《罪恶之城》）：整片是黑白，只有一种颜色保留下来，观众的视线会被它牢牢抓住。
// 实现：把每个像素转到色相/饱和度，判断色相是否落在目标附近（环形距离），饱和度够高才保留。

vec3 rgb2hsv(vec3 c) {
  vec4 K = vec4(0., -1. / 3., 2. / 3., -1.);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  return vec3(abs(q.z + (q.w - q.y) / (6. * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec3 hsv = rgb2hsv(src);
  // ① 色相距离（色环上的最短距离）与饱和度门槛
  float dh = abs(fract(hsv.x - hue + .5) - .5);
  float keep = smoothstep(range + .02, range - .01, dh) * smoothstep(minSat - .05, minSat + .05, hsv.y);
  // ② 黑白：亮度 + 反差
  float l = clamp((fxLuma(src) - .5) * contrast + .5, 0., 1.);
  // ③ 保留的颜色提饱和
  vec3 vivid = clamp(mix(vec3(fxLuma(src)), src, boost), 0., 1.);
  return vec4(mix(vec3(l), vivid, keep), 1.);
}
