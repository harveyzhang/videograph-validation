/*@effect
{
  "id": "type-shadow-sweep",
  "name": "长投影扫转",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "long shadow", "flat design", "rotating light", "3d", "文字", "长投影", "扁平化", "光源旋转"],
  "summary": "亮色文字身后拖出一条很长的扁平风格投影（一直延伸出画面），光源绕着画面缓慢转动，投影方向随之扫转；每个小节光源猛转一下。",
  "when": "扁平化设计、Logo 与标题演绎、App/科技品牌、“时间流逝”（像日晷）的意象。",
  "avoid": "文字很多的段落（投影互相交叠）；写实电影感画面。",
  "params": {
    "reach": { "type": "float", "default": 0.25, "min": 0.02, "max": 0.6, "label": "投影长度（画面高度比例）" },
    "speed": { "type": "float", "default": 0.15, "min": -1, "max": 1, "label": "光源转速（弧度/秒）" },
    "kick": { "type": "float", "default": 0, "min": 0, "max": 1.5, "label": "小节猛转（通常由小节驱动）" },
    "shadowColor": { "type": "color", "default": "#ff4d12", "label": "投影颜色" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.1, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "kick": { "to": "bar", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：扁平长投影", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（扁平化设计的“长投影”）：想象一个极低角度的光源，把字的影子拉得很长；扁平风格里投影是一块硬边实色、
// 沿 45° 方向直达画面边缘。动态版本让光源绕圈，投影像日晷的影子一样扫过画面。
// 实现：对每个像素沿投影反方向回看 14 步，若碰到字，这里就在影子里（与 extrude 不同：这里是纯色硬影，且方向转动）。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  float front = inkAt(uv);
  // ① 投影方向：随时间旋转 + 小节猛转
  float ang = uTime * speed + kick;
  vec2 dir = vec2(cos(ang), sin(ang)) * vec2(uRes.y / uRes.x, 1.);
  // ② 回看 14 步（步长递增，近处细、远处粗），找到挡光的字
  float sh = 0.;
  for (int i = 1; i <= 14; i++) {
    float t = pow(float(i) / 14., 1.5);
    sh = max(sh, inkAt(uv - dir * reach * t) * (1. - t * .35));
  }
  // ③ 合成：影子是带一点透明度的实色（越远略淡），字在最上层
  vec3 c = mix(src, shadowColor, sh * .9 * (1. - front));
  return vec4(c, 1.);
}
