/*@effect
{
  "id": "beat-camera-swing",
  "name": "拍点镜头甩动",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["camera swing", "dutch angle", "beat", "rotate", "handheld", "甩镜", "荷兰角", "倾斜", "卡点"],
  "summary": "镜头每拍左右交替倾斜一个角度（荷兰角）并带一点推镜，像摄影师随音乐甩动机身；拍内用弹簧缓动回正，边缘用镜像填补不露黑边。",
  "when": "嘻哈/摇滚/舞曲的主歌律动、街头与运动题材、紧张不安的情绪（大角度）。",
  "avoid": "需要稳定观看的信息镜头；与其他运动类效果叠用会晕。",
  "params": {
    "angle": { "type": "float", "default": 0, "min": 0, "max": 0.25, "label": "倾斜角度（弧度，通常由节拍驱动）" },
    "zoom": { "type": "float", "default": 0.06, "min": 0, "max": 0.2, "label": "附带推镜（防止露边）" },
    "spring": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "回弹（0 = 平滑回正，1 = 弹两下）" }
  },
  "bindings": { "angle": { "to": "kick", "amount": 0.07 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：甩镜", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：手持摄影师跟着节奏把机身向一侧甩，画面倾斜（荷兰角）然后回正；交替方向会形成摇摆的律动感。
// 角度挂鼓点（冲击 + 衰减），方向按拍号奇偶交替；回正时可以带一点弹簧的过冲。

vec4 effect(vec2 uv) {
  float beatN = floor(uTime * 2.);
  float dir = mod(beatN, 2.) < 1. ? 1. : -1.;
  // ① 弹簧：角度本身来自 kick 包络（已衰减），这里再叠加一个拍内阻尼振荡让回正带过冲
  float osc = mix(1., cos(uBeat * 9.) * exp(-uBeat * 2.), spring);
  float a = angle * dir * osc;
  // ② 旋转 + 推镜（围绕画面中心）；镜像外推填边
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = (uv - .5) * asp;
  p = fxRot(a) * p / (1. + zoom + abs(a) * .6);
  vec2 q = p / asp + .5;
  q = 1. - abs(1. - abs(q));
  return vec4(srcTex(q).rgb, 1.);
}
