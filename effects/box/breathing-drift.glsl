/*@effect
{
  "id": "breathing-drift",
  "name": "低频呼吸推移",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["breathing", "ken burns", "slow zoom", "drift", "bar", "呼吸", "缓推", "小节"],
  "summary": "镜头以小节为周期缓慢地“吸气-呼气”：轻轻推近再退回，同时沿一条平滑曲线微微漂移和转动，像手持摄影师随音乐呼吸；没有任何冲击感。",
  "when": "抒情主歌、氛围段落、静态画面/照片需要“活起来”、长镜头的轻微生命感。",
  "avoid": "需要卡点冲击的段落（用 beat-zoom-punch）；画面边缘有重要内容（推近会裁掉约 3–6%）。",
  "params": {
    "depth": { "type": "float", "default": 0.035, "min": 0, "max": 0.12, "label": "呼吸幅度（推近比例）" },
    "drift": { "type": "float", "default": 0.012, "min": 0, "max": 0.04, "label": "漂移幅度" },
    "tilt": { "type": "float", "default": 0.006, "min": 0, "max": 0.03, "label": "转动幅度（弧度）" },
    "swell": { "type": "float", "default": 0, "min": 0, "max": 0.05, "label": "音乐能量加推" }
  },
  "bindings": { "swell": { "to": "energy", "amount": 0.025 } },
  "inspiredBy": [{ "source": "shotcraft", "ref": "五条通用法则：节拍律动（低频层）", "note": "本仓库" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：手持或斯坦尼康摄影师即使“不动”，镜头也会随呼吸缓慢起伏；纪录片的 Ken Burns 手法是对静态照片做缓推缓移。
// 把这种低频运动锁到小节上（一个小节一次呼吸），画面就会和音乐同呼吸，但不会像拍点冲击那样抢戏。
// 节拍绑定：小节相位 uBar 直接驱动呼吸周期（每小节一次）；swell 挂音乐能量，越激烈的段落推得越近。

vec4 effect(vec2 uv) {
  // ① 呼吸曲线：一个小节一次，用余弦让吸气与呼气都缓入缓出（没有拐点、没有冲击）。
  float breath = .5 - .5 * cos(uBar * 6.2832);

  // ② 推近：以略偏离中心的点为锚（画面重心通常不在正中），缩放量 = 基础幅度 × 呼吸 + 能量加推。
  float zoom = 1. + depth * breath + swell;

  // ③ 漂移与转动：两条不同频率的正弦（与时间相关、周期不等于小节）让轨迹不重复，像真人手持。
  vec2 off = vec2(sin(uTime * .37) + .5 * sin(uTime * .91 + 1.), cos(uTime * .29) + .5 * sin(uTime * .73)) * drift * .66;
  float ang = sin(uTime * .23 + .7) * tilt;

  // ④ 取景：先平移、再绕中心旋转、再缩放（镜头运动的顺序），画面边缘用镜像外推避免露黑边。
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = (uv - .5 - off) * asp;
  p = fxRot(ang) * p / zoom;
  vec2 u = p / asp + .5;
  u = 1. - abs(1. - abs(u));   // 镜像外推（缩放足够时几乎用不到）
  return vec4(srcTex(u).rgb, 1.);
}
