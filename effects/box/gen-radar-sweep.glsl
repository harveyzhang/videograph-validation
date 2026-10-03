/*@effect
{
  "id": "gen-radar-sweep",
  "name": "雷达扫描",
  "kind": "post",
  "category": "生成层",
  "tags": ["radar", "sonar", "sweep", "scan", "military", "雷达", "声呐", "扫描", "探测"],
  "summary": "画面变成绿色雷达屏：同心刻度圈与十字线，一道扫描臂匀速旋转、身后留下渐暗的余辉扇区；画面里的亮处在被扫到时显示为发亮的回波点，然后慢慢熄灭。",
  "when": "军事/潜艇/航空/科幻、搜索与定位的意象、悬疑追踪、科技数据开场。",
  "avoid": "温暖手作/自然题材；需要正常颜色的画面。",
  "params": {
    "period": { "type": "float", "default": 2, "min": 0.5, "max": 8, "label": "扫一圈的时间（秒）" },
    "rings": { "type": "float", "default": 5, "min": 2, "max": 10, "label": "刻度圈数" },
    "persist": { "type": "float", "default": 0.35, "min": 0.05, "max": 1, "label": "余辉长度（圈）" },
    "echo": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "回波亮度（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#3dff7a", "label": "雷达色" }
  },
  "bindings": { "echo": { "to": "kick", "amount": 0.5 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/hologram-hud：仪表界面", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（PPI 平面位置显示器）：雷达天线旋转，屏幕上一条亮线跟着转；被扫到的目标反射回波在屏幕上亮成一个点，
// 荧光屏的余辉让它慢慢变暗，直到下一圈再被点亮。屏幕上有距离刻度圈和方位十字线。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = (uv - .5) * asp;
  float r = length(p);
  float a = fract(atan(p.y, p.x) / 6.2832);
  // ① 扫描臂角度与“距上次被扫到过了多久”（以圈为单位）
  float arm = fract(uTime / period);
  float since = fract(arm - a);                         // 0 = 刚扫过
  // ② 余辉扇区 + 扫描臂亮线
  float trail = exp(-since / persist * 3.) * .35;
  float armLine = smoothstep(.006, 0., since * r * 6.2832) ;
  // ③ 回波：画面亮处被扫到时亮起，随余辉衰减（只在雷达圆内）
  float target = smoothstep(.35, .7, fxLuma(src));
  float blip = target * exp(-since / persist * 2.5) * echo;
  // ④ 刻度圈与十字线（细线），雷达圆外压暗
  float ringD = abs(fract(r / .5 * rings + .5) - .5) * .5 / rings * 2.;
  float grid = smoothstep(.0025, 0., ringD) * .5 + (smoothstep(.0015, 0., abs(p.x)) + smoothstep(.0015, 0., abs(p.y))) * .4;
  float inside = smoothstep(.505, .495, r);
  vec3 base = vec3(fxLuma(src)) * color * .18;
  vec3 c = base + color * (trail + armLine + blip * 1.4 + grid) * inside;
  c = mix(src * .15, c, inside);
  return vec4(c, 1.);
}
