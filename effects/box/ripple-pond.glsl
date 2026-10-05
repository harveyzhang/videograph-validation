/*@effect
{
  "id": "ripple-pond",
  "name": "水波荡漾转场",
  "kind": "transition",
  "category": "转场",
  "tags": ["ripple", "water", "pond", "concentric", "reflection", "水波", "涟漪", "荡漾", "水面转场"],
  "summary": "像一颗石子落进水面：一圈圈涟漪从落点扩散开，波纹扭曲画面，波前经过的地方旧镜头像倒影一样晃散、露出下一个镜头；最后水面平静下来。",
  "when": "抒情/回忆/梦境、水与自然主题、温柔的段落过渡、“心里泛起涟漪”的意象。",
  "avoid": "快节奏与硬朗风格。时长建议 0.8–1.5 秒。",
  "params": {
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "落点 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "落点 Y" },
    "waves": { "type": "float", "default": 18, "min": 4, "max": 60, "label": "波纹密度" },
    "strength": { "type": "float", "default": 0.025, "min": 0, "max": 0.08, "label": "扭曲强度" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：涟漪", "note": "按思路自写；与 gl-transitions 的 ripple 不同：波前推进揭示 + 衰减的同心多圈 + 高光" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：石子落水后，一组同心圆波向外传播；波峰和波谷像一圈圈透镜，把水底/倒影扭曲；波越往外越弱，最后水面恢复平静。
// 转场：波前扫过的区域换成新画面，波纹的扭曲在两个画面上都有，随进度减弱。

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 d = (uv - vec2(centerX, centerY)) * vec2(ratio, 1.);
  float r = length(d);
  float front = p * 1.6;
  // ① 波：只在波前后方存在，越靠后越弱；整体随进度衰减
  float behind = front - r;
  float wave = sin(behind * waves * 6.2832 / 1.6) * exp(-max(behind, 0.) * 3.) * step(0., behind) * (1. - p);
  vec2 dir = d / max(r, 1e-4);
  vec2 off = dir * wave * strength / vec2(ratio, 1.);
  // ② 波前之后 = 新镜头（边缘柔和）
  float m = smoothstep(.0, .08, behind);
  vec3 a = getFromColor(uv + off).rgb, b = getToColor(uv + off).rgb;
  vec3 c = mix(a, b, m);
  // ③ 波峰高光
  c += max(wave, 0.) * .25;
  return vec4(c, 1.);
}
