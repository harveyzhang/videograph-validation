/*@effect
{
  "id": "ink-bleed-reveal",
  "name": "墨水晕开转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["ink", "bleed", "wash", "watercolor", "reveal", "墨水", "晕开", "水墨转场"],
  "summary": "一滴墨落在纸上向外洇开，被墨浸到的地方显出下一个镜头；墨的边缘是不规则的毛细纹路，前沿有一圈更深的积墨。",
  "when": "国风/水墨题材、回忆与梦境、手作与绘画类内容、抒情段落之间的柔和过渡。",
  "avoid": "快节奏卡点（晕开是慢的，时长建议 ≥0.8 秒）；冷峻科技题材。",
  "params": {
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "落墨点 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "落墨点 Y" },
    "roughness": { "type": "float", "default": 0.35, "min": 0, "max": 0.8, "label": "边缘毛糙" },
    "ink": { "type": "color", "default": "#141418", "label": "墨色" },
    "rim": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "前沿积墨" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/ink-wash 与 watercolor", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：墨滴落在宣纸上，靠纸纤维的毛细作用向四周渗开——渗得快慢取决于纤维走向，所以边缘是不规则的“毛刺”；
// 墨里的颗粒被水带到前沿堆积，形成一圈比中间更深的边（咖啡环效应）。
// 节拍：转场进度由宿主按转场时长驱动，本质是一个连续过程，不挂节拍（bindings 为空）。

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.);
  vec2 d = (uv - vec2(centerX, centerY)) * asp;

  // ① 渗开半径：随进度增长，最终覆盖到最远的角（缓入缓出：开始慢、中间快、最后慢慢铺满）。
  float far = length(max(abs(vec2(centerX, centerY) - .5) + .5, vec2(0.)) * asp) + .1;
  float p = progress * progress * (3. - 2. * progress);
  float radius = p * (far + roughness * .4);

  // ② 毛细边缘：纸纤维让不同方向渗得快慢不同——用两层噪声扰动“到墨心的距离”（大尺度的花瓣形 + 细碎毛刺）。
  float n = fxFbm(uv * 4. + 3.) * .7 + fxNoise(uv * 40.) * .3;
  float dist = length(d) + (n - .5) * roughness * .5;
  float wet = smoothstep(radius, radius - .015, dist);        // 1 = 已被墨浸到

  // ③ 墨的显现：被浸到的地方先是墨色，墨淡下去后露出下一个镜头（离前沿越远越透）。
  float behind = clamp((radius - dist) / .18, 0., 1.);
  vec4 from = getFromColor(uv), to = getToColor(uv);
  vec3 c = mix(from.rgb, ink, wet * (1. - behind));
  c = mix(c, to.rgb, wet * behind);

  // ④ 前沿积墨：在湿区边界内侧一圈更深的墨（咖啡环），带毛刺。
  float ring = smoothstep(.03, 0., abs(dist - radius + .012)) * wet * rim * (1. - progress * .6);
  c = mix(c, ink, ring);
  return vec4(c, 1.);
}
