/*@effect
{
  "id": "motion-echo",
  "name": "动态残影",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["echo", "ghost", "trail", "streak", "motion blur", "残影", "拖影", "重影", "动感"],
  "summary": "画面拖出一串沿某个方向排开、逐渐变淡的彩色重影（亮部更明显），像高速运动留下的视觉残留；鼓点时重影拉得更远。",
  "when": "舞蹈与运动、速度感与冲刺、迷幻与醉意、电子乐与嘻哈的副歌。",
  "avoid": "需要清晰阅读的镜头；整体很亮的画面（重影会让画面发白）。",
  "params": {
    "spacing": { "type": "float", "default": 0.03, "min": 0, "max": 0.1, "label": "残影间距" },
    "angle": { "type": "float", "default": 0, "min": -3.1416, "max": 3.1416, "label": "残影方向（弧度）" },
    "fade": { "type": "float", "default": 0.6, "min": 0.2, "max": 0.95, "label": "每层衰减" },
    "tint": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "残影上色" },
    "kick": { "type": "float", "default": 0, "min": 0, "max": 0.08, "label": "鼓点拉远（通常由节拍驱动）" }
  },
  "bindings": { "kick": { "to": "kick", "amount": 0.03 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：残影", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（长曝光 + 频闪/视频反馈）：物体移动时，前几个时刻的影像还留在底片或屏幕余辉里，形成一串逐渐变淡的重影；
// 后期栈拿不到过去的画面，所以这里沿一个方向复制 6 层画面并逐层变淡、换色，模拟残影的观感。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 dir = vec2(cos(angle), sin(angle)) * vec2(uRes.y / uRes.x, 1.);
  float L = spacing + kick;
  // ① 6 层重影：越远越淡，只取亮部（暗部的重影看不见，避免整片发灰），颜色沿色环轮换
  vec3 acc = vec3(0.);
  float w = 1.;
  for (int i = 1; i <= 6; i++) {
    w *= fade;
    vec3 s = srcTex(uv - dir * L * float(i)).rgb;
    float bright = smoothstep(.15, .6, fxLuma(s));
    vec3 col = mix(s, (.5 + .5 * cos(6.2832 * (float(i) * .15 + vec3(0., .33, .67)))) * fxLuma(s) * 1.5, tint);
    col *= 1. - fxLuma(srcTex(uv).rgb) * .6;     // 原画面本身很亮的地方重影少叠一点，免得发白
    acc = max(acc, col * bright * w);
  }
  // ② 合成：重影以“滤色”叠在画面上（像余辉的光叠加），彩色重影在原画面的暗部与边缘最明显
  vec3 c = 1. - (1. - src) * (1. - acc * .9);
  return vec4(c, 1.);
}
