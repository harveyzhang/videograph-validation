/*@effect
{
  "id": "kick-ripple",
  "name": "鼓点涟漪扭曲",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["ripple", "shockwave", "distortion", "kick", "water drop", "涟漪", "冲击波", "水波"],
  "summary": "每个鼓点从一个点激起一圈冲击波：波前经过的地方画面被折射扭曲、边缘带一点色散和亮光，波纹向外扩散并衰减。",
  "when": "低音炮/底鼓特别重的段落、能量爆发、魔法与超能力、产品“落地”的瞬间、水与声音主题。",
  "avoid": "安静段落；需要稳定画面的字幕镜头（波纹扫过字会扭）。",
  "params": {
    "strength": { "type": "float", "default": 0.006, "min": 0, "max": 0.06, "label": "扭曲强度（基础值，鼓点时叠加）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "波源 X" },
    "centerY": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "波源 Y" },
    "speed": { "type": "float", "default": 1.4, "min": 0.3, "max": 3, "label": "扩散速度（每拍扩散的画面高度倍数）" },
    "width": { "type": "float", "default": 0.07, "min": 0.02, "max": 0.2, "label": "波带宽度" }
  },
  "bindings": { "strength": { "to": "kick", "amount": 0.035 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：冲击波/涟漪", "note": "按思路自写；不复用 gl-transitions 的 ripple 代码" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：石子落水（或强低频声压）在介质表面激起一圈波：波峰像凸透镜把背后的画面向外推、波谷向内收，
// 波前上光线被折射得最厉害，所以有一圈亮边和轻微的色散；波向外传播时能量摊薄，越远越弱。
// 节拍绑定：鼓点那一刻（拍相位 0）波从波源出发，uBeat 决定波前已经走了多远；strength 挂鼓点控制这一圈的能量。

vec4 effect(vec2 uv) {
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 C = vec2(centerX, centerY);
  vec2 d = (uv - C) * asp;
  float r = length(d);

  // ① 波前位置：拍点出发（落水点本身有大小，所以从 0.12 处开始），随拍内相位向外扩散。
  //    上一拍激起的那圈波还在更远处继续传播（能量更弱），两圈一起看才像连续的“声波”。
  float front = .12 + uBeat * speed;
  float front2 = .12 + (uBeat + 1.) * speed;

  // ② 波形：以波前为中心的一个“正弦包络”——前沿是波峰（向外推），后沿是波谷（向内收）。
  float x = (r - front) / width;
  float wave = -sin(x * 3.1416) * exp(-x * x * 1.5);
  float x2 = (r - front2) / (width * 1.6);
  float wave2 = -sin(x2 * 3.1416) * exp(-x2 * x2 * 1.5);

  // ③ 传播衰减：越远越弱（能量摊在更大的圆周上）；这一圈的能量 = strength（挂鼓点，带包络），
  //    上一圈只留基础强度的 0.5 倍 + 固定的一点点余波，让非鼓点帧也能看出“水面”还在动。
  float amp = (strength * wave + (strength * .3 + .004) * wave2) / (1. + front * 1.5);
  wave = max(wave, wave2 * .4);
  vec2 dir = d / max(r, 1e-4);
  vec2 offs = dir * amp / asp;

  // ④ 折射取样 + 色散：三个通道折射量略不同（3 次采样）。
  vec3 c;
  c.r = srcTex(uv - offs * 1.15).r;
  c.g = srcTex(uv - offs).g;
  c.b = srcTex(uv - offs * .85).b;

  // ⑤ 波前亮边：光在波峰处汇聚 → 一圈很淡的亮光（与扭曲强度成比例）。
  c += max(wave, 0.) * strength * 6. * vec3(.9, .95, 1.);
  return vec4(c, 1.);
}
