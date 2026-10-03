/*@effect
{
  "id": "scanner-drag",
  "name": "扫描仪拖影",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["scanner", "scan", "slit-scan", "flatbed", "smear", "扫描仪", "扫描拖影", "狭缝"],
  "summary": "像平板扫描仪扫的时候东西被挪动了：一条发光的扫描线自上而下走过，扫描线之后的画面被拉成平行的彩色拖丝，之前的部分已经定格。",
  "when": "实验影像、拼贴与艺术装置、复古办公、表现“记录/读取”的过程；适合作为一段的开场或揭示。",
  "avoid": "需要完整画面的镜头（拖影区会盖住内容）；节奏很快的段落（扫描是慢动作）。",
  "params": {
    "speed": { "type": "float", "default": 0.35, "min": 0.05, "max": 2, "label": "扫描速度（次/秒）" },
    "stretch": { "type": "float", "default": 0.8, "min": 0, "max": 1, "label": "拖影比例" },
    "lamp": { "type": "float", "default": 0.7, "min": 0, "max": 1.5, "label": "灯管亮度" },
    "rgbShift": { "type": "float", "default": 0.004, "min": 0, "max": 0.02, "label": "三色传感器错位" }
  },
  "bindings": { "lamp": { "to": "kick", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：扫描线揭示/狭缝扫描", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：平板扫描仪的灯管和一排线性传感器一起从上往下移动，每一刻只记录“一行”。
// 如果扫描时原稿被拖动，或扫描头停住不动，那么同一行的内容会被重复记录 → 变成一条条平行拉丝；
// 线性传感器的 R/G/B 三行在物理上错开一点，物体移动时三色对不齐，拖丝边缘出现彩边。

vec4 effect(vec2 uv) {
  // ① 扫描头位置：自上而下匀速移动（1 - fract），到底后从顶部重新开始。
  float head = 1. - fract(uTime * speed);

  // ② 扫描结果：扫描头已经经过的区域（uv.y > head）正常记录；还没扫到的区域（uv.y < head）
  //    在“原稿被拖动”的设定下全部是扫描头所在那一行被拉长的结果——拖影比例 stretch 控制拉长的多少。
  float below = step(uv.y, head);
  float yRead = mix(uv.y, head, below * stretch);

  // ③ 三色传感器错位：R/G/B 三行传感器在扫描方向上错开，拖丝区彩边更明显（3 次采样）。
  float s = rgbShift * (1. + below * 2.);
  vec3 c;
  c.r = srcTex(vec2(uv.x, yRead + s)).r;
  c.g = srcTex(vec2(uv.x, yRead)).g;
  c.b = srcTex(vec2(uv.x, yRead - s)).b;

  // ④ 拖丝纹理：同一行被反复记录时传感器噪声不同 → 竖向的细丝，亮度沿 x 有微小起伏（静止）。
  float fiber = fxHash(vec2(floor(uv.x * uRes.x), 3.));
  c *= 1. - below * stretch * (fiber - .5) * .12;

  // ⑤ 扫描灯：扫描头处一条明亮的冷白光带（带一点辉光），这条光带在画面中移动，不是整屏闪烁。
  //    lamp 挂鼓点：鼓点那一下灯管一亮。
  float d = (uv.y - head) * uRes.y;
  float lampLine = exp(-d * d * .05) + exp(-abs(d) * .12) * .2;
  c += vec3(.75, .9, 1.) * lampLine * lamp;
  return vec4(c, 1.);
}
