/*@effect
{
  "id": "gen-sunburst",
  "name": "放射光芒",
  "kind": "post",
  "category": "生成层",
  "tags": ["sunburst", "rays", "retro poster", "radial", "background", "放射", "光芒", "复古海报", "背景"],
  "summary": "从一个中心点向外辐射的两色交替光芒条缓慢旋转，只出现在画面的暗部背景里（亮的主体/文字压在光芒之上），像复古海报和漫画的冲击背景；每一拍光芒脉动一下。",
  "when": "复古/波普海报、漫画与综艺花字的强调背景、产品亮相、标题砸入、胜利与庆祝。",
  "avoid": "写实电影感画面；主体与背景亮度接近时（无法区分“背景”，光芒会盖到主体上）。",
  "params": {
    "rays": { "type": "float", "default": 16, "min": 4, "max": 60, "label": "光芒条数" },
    "spin": { "type": "float", "default": 0.08, "min": -1, "max": 1, "label": "旋转速度（圈/秒）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "中心 Y" },
    "colorA": { "type": "color", "default": "#ff4d12", "label": "光芒色 A" },
    "colorB": { "type": "color", "default": "#ffb36b", "label": "光芒色 B" },
    "behind": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "背景判定亮度（低于它的地方显示光芒）" },
    "lightBackground": { "type": "bool", "default": false, "label": "浅色背景（主体是深色剪影时打开：光芒画在亮部）" },
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "节拍脉动（通常由节拍驱动）" }
  },
  "bindings": { "pulse": { "to": "beat", "amount": 0.6 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/game-show 与 midcentury-toon：放射背景", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（印刷海报/漫画）：放射线背景（旭日纹）是从焦点向外的等角扇形，两种颜色交替——把视线引向中心的主体；
// 动态版本让它缓慢旋转、随拍呼吸。为了让主体“站在光芒前面”，这里只在画面的暗部（背景）画光芒。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 d = (uv - vec2(centerX, centerY)) * vec2(uRes.x / uRes.y, 1.);
  float r = length(d);

  // ① 扇区：角度 × 条数，奇偶交替两种颜色；整体随时间旋转。扇区边缘按像素宽度抗锯齿。
  float a = atan(d.y, d.x) / 6.2832 + uTime * spin;
  float s = fract(a * rays);
  float aa = fwidth(a * rays) * 1.5;
  float stripe = smoothstep(.5 - aa, .5 + aa, s) * smoothstep(1., 1. - aa, s);
  vec3 burst = mix(colorA, colorB, stripe);

  // ② 中心亮、边缘暗（光从中心发出）；pulse 挂每拍：每拍中心亮度与光芒长度呼吸一次。
  burst *= mix(1.15, .55, smoothstep(0., .9 - pulse * .15, r)) * (1. + pulse * .25 * exp(-r * 3.));

  // ③ 只在暗部显示：背景遮罩 = 原画面亮度低于 behind 的区域（柔和过渡），主体保持原样。
  float l = fxLuma(src);
  float bg = lightBackground ? smoothstep(1. - behind - .1, 1. - behind + .1, l) : smoothstep(behind + .1, behind - .1, l);
  vec3 c = mix(src, burst, bg);
  return vec4(c, 1.);
}
