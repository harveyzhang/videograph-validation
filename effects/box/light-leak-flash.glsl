/*@effect
{
  "id": "light-leak-flash",
  "name": "漏光闪白转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["light leak", "flash", "film burn", "warm flare", "transition", "漏光", "闪白", "胶片转场", "暖光"],
  "summary": "一团暖橙色的漏光从画面一侧涌进来，迅速铺满并过曝成一片暖白，在最亮时换成下一个镜头，再随漏光退去慢慢显现；光团边缘柔和、有胶片颗粒。",
  "when": "婚礼/旅行/回忆/青春、温暖的段落衔接、胶片感 vlog、章节转换。",
  "avoid": "冷峻科技与悬疑；连续多次使用（会腻）。时长建议 0.6–1.2 秒。",
  "params": {
    "color": { "type": "color", "default": "#ffb066", "label": "漏光颜色" },
    "fromSide": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "涌入方向（0 = 右侧，1 = 左侧）" },
    "peak": { "type": "float", "default": 0.85, "min": 0.3, "max": 1, "label": "最亮时过曝程度" },
    "grain": { "type": "float", "default": 0.05, "min": 0, "max": 0.15, "label": "颗粒" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：胶片漏光转场", "note": "按思路自写；与 gl-transitions 的 FilmBurn/Overexposure 不同：这里是有方向的光团涌入 + 峰值换镜" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：胶卷换卷或相机后盖漏光时，光从片窗一侧照进来，在底片上留下一大片橙红的过曝；
// 剪辑师常把这种漏光叠在两个镜头的接缝上：光涌进来盖住旧镜头，最亮时切换，光退去露出新镜头。

vec4 transition(vec2 uv) {
  vec3 a = getFromColor(uv).rgb, b = getToColor(uv).rgb;
  float p = progress;
  // ① 光团：从一侧涌入的柔和光区；shape = 离入光侧的距离（被低频噪声扰动成不规则漏光边缘）
  float x = mix(1. - uv.x, uv.x, fromSide);
  float shape = x + (fxNoise(uv * vec2(2., 3.) + p * 1.5) - .5) * .5 + (uv.y - .5) * .25;
  // ② 光的覆盖范围：前半从入光侧铺向对侧（前沿位置 0 → 1.5），后半从同一侧退去（-0.5 → 1）
  float reach = p < .5 ? mix(-.2, 1.6, p * 2.) : mix(1.6, -.4, (p - .5) * 2.);
  float cover = smoothstep(reach + .35, reach - .15, shape);
  // 总亮度包络：中间最亮（峰值处换镜）
  float env = sin(p * 3.1416);
  float L = clamp(cover * (.35 + .65 * env), 0., 1.) * peak;
  // ③ 底层画面：前半旧镜头，后半新镜头（在最亮处切换，观众看不到切点）
  vec3 base = p < .5 ? a : b;
  // ④ 漏光叠加：屏幕混合 + 过曝到暖白；颗粒
  vec3 c = 1. - (1. - base) * (1. - color * L);
  c = mix(c, vec3(1., .96, .9), smoothstep(.75, 1., L / max(peak, .01)) * peak);
  c += (fxHash(floor(uv * uRes / 2.) + floor(p * 60.)) - .5) * grain * env;
  return vec4(c, 1.);
}
