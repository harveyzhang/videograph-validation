/*@effect
{
  "id": "film-strip-scroll",
  "name": "胶片卷轴",
  "kind": "post",
  "category": "画面版式",
  "tags": ["film strip", "35mm", "sprocket", "scroll", "memories", "胶片", "片孔", "卷轴", "回忆"],
  "summary": "画面变成一条竖直移动的 35mm 正片胶片：每一格是画面的一帧，左右两边是带片孔的黑色片边，整条胶片缓慢向上滚动、略微倾斜；鼓点时滚动一顿。",
  "when": "回忆/怀旧/时间流逝、电影幕后与片头、照片集与 vlog 合集、电影节宣传。",
  "avoid": "需要完整清晰看画面的镜头（每格会缩小，格间有片缝）。",
  "params": {
    "speed": { "type": "float", "default": 0.12, "min": -1, "max": 1, "label": "滚动速度（格/秒）" },
    "width": { "type": "float", "default": 0.62, "min": 0.3, "max": 1, "label": "胶片宽度（画面宽度比例）" },
    "tilt": { "type": "float", "default": 0.08, "min": -0.5, "max": 0.5, "label": "倾斜（弧度）" },
    "jolt": { "type": "float", "default": 0, "min": 0, "max": 0.2, "label": "鼓点顿挫（通常由节拍驱动）" },
    "bg": { "type": "color", "default": "#1b1714", "label": "背景色" }
  },
  "bindings": { "jolt": { "to": "kick", "amount": 0.06 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：胶片质感", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：35mm 电影正片是一条连续的透明片基，画面一格一格地排在中间，两侧是用于牵引的方形片孔；
// 对着灯看，片边是黑的、片孔透光，格与格之间有一条细细的黑色片缝。卷片时整条胶片匀速移动。

vec4 effect(vec2 uv) {
  float A = uRes.x / uRes.y;
  vec2 p = (uv - .5) * vec2(A, 1.);
  p = fxRot(tilt) * p;
  float W = width * A;                                      // 胶片总宽
  float imgW = W * .76;                                     // 画格宽
  float frameH = imgW / A;                                  // 画格高（保持原画面比例）
  float pitch = frameH * 1.08;                              // 一格的步距（含片缝）
  // ① 滚动：位置随时间增加；鼓点顿挫让卷动停一下再追上
  float y = p.y + (uTime * speed - jolt * sin(uBeat * 3.1416)) * pitch;
  vec3 c = bg;
  if (abs(p.x) > W * .5) {
    c *= .9 + .1 * fxNoise(uv * uRes * .2);
    return vec4(c, 1.);
  }
  // ② 片边：黑色带片孔（圆角方孔，透出暖白灯光）
  vec3 film = vec3(.06, .055, .05);
  float side = abs(p.x) - imgW * .5;
  if (side > 0.) {
    float holeY = fract(y / (pitch / 4.)) - .5;
    float hx = abs(p.x) - (imgW * .5 + (W - imgW) * .25);
    vec2 hd = abs(vec2(hx, holeY * pitch / 4.)) - vec2((W - imgW) * .1, pitch / 4. * .28);
    float hole = smoothstep(.002, 0., length(max(hd, 0.)) - .004);
    c = mix(film, vec3(.98, .92, .8), hole);
    return vec4(c, 1.);
  }
  // ③ 画格：原画面缩放进每一格；格间片缝
  float fy = fract(y / pitch);
  float inImg = step(.04, fy) * step(fy, .96);
  vec2 q = vec2(p.x / imgW + .5, (fy - .04) / .92);
  c = mix(film, srcTex(q).rgb * .95, inImg);
  return vec4(c, 1.);
}
