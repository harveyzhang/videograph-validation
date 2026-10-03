/*@effect
{
  "id": "gen-light-sweep",
  "name": "高光扫过",
  "kind": "post",
  "category": "生成层",
  "tags": ["light sweep", "shine", "glint", "logo reveal", "metallic", "扫光", "高光", "金属光泽", "Logo"],
  "summary": "一道斜向的白色高光带每小节从左到右扫过画面一次，只在亮的物体（Logo、文字、产品）上反光，像光扫过金属/玻璃表面；背景不受影响。",
  "when": "Logo 落版、产品亮相、标题定格、金属/玻璃/珠宝质感、片尾品牌卡。",
  "avoid": "整片都很亮的画面（会变成整屏闪过一道光）；柔和手绘风格。",
  "params": {
    "width": { "type": "float", "default": 0.09, "min": 0.01, "max": 0.3, "label": "光带宽度" },
    "angle": { "type": "float", "default": 0.5, "min": -1.5, "max": 1.5, "label": "倾斜角度（弧度）" },
    "intensity": { "type": "float", "default": 0.9, "min": 0, "max": 2, "label": "亮度" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.05, "max": 0.95, "label": "反光的亮度阈值" },
    "sweeps": { "type": "float", "default": 1, "min": 0.25, "max": 4, "label": "每小节扫几次" },
    "gloss": { "type": "float", "default": 0.25, "min": 0, "max": 1, "label": "常驻光泽（亮面上的固定渐变高光）" },
    "tint": { "type": "color", "default": "#ffffff", "label": "高光颜色" }
  },
  "bindings": { "intensity": { "to": "bar", "amount": 0.4 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：Logo 扫光", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：拍金属/玻璃物体时移动光源（或转动物体），一条明亮的反射高光会从表面滑过——广告片里叫“扫光”。
// 只有光滑、明亮的表面会把这道光反射进镜头，所以这里只在亮度高于阈值的像素上加高光。
// 节拍：扫光位置跟着小节相位走（每小节扫 sweeps 次），intensity 再挂小节——小节开头那一扫最亮。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;

  // ① 光带位置：沿倾斜方向的坐标，扫过范围略大于画面（前后各留 0.3，光带完整进出）。
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = (uv - .5) * asp;
  float s = dot(p, vec2(cos(angle), sin(angle))) / (asp.x * .5 + .5);
  //    小节开头光带正好扫到画面中央偏左（下拍时观众能看到高光），随后扫出右侧，再从左侧进来。
  float pos = fract(uBar * sweeps + .3) * 2. - 1.;          // 光带中心在 ±1 之间往返（画面对角范围约 ±0.75，光带宽度让它完整进出）

  // ② 光带剖面：中心亮、两侧柔和衰减，再加一条更细的锐利亮线（镜面的硬高光）。
  float x = (s - pos) / width;
  float band = exp(-x * x * 2.) * .7 + exp(-x * x * 30.) * .6;

  // ③ 只在亮面上反光：遮罩 = 亮度超过阈值的程度（软过渡）。
  float shiny = smoothstep(threshold, threshold + .25, fxLuma(src));
  //    高光强度按表面自身亮度缩放（反射的是光源，亮面反射更多），避免把整片区域冲成死白。
  vec3 c = src + tint * band * shiny * intensity * (.5 + .5 * fxLuma(src));
  // ④ 常驻光泽：光滑表面即使没有扫光，也总带一层上亮下暗的环境反射（让 Logo/字有金属感），光带扫过时再叠加。
  c += tint * shiny * gloss * (smoothstep(-.6, .6, s) * .5 + .25 * (uv.y - .3));
  return vec4(c, 1.);
}
