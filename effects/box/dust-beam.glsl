/*@effect
{
  "id": "dust-beam",
  "name": "尘埃光束",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["dust", "light beam", "window light", "particles", "haze", "尘埃", "光束", "窗光"],
  "summary": "一道斜射的窗光穿过画面，光里漂浮着缓慢翻飞的尘埃颗粒，节拍上尘埃闪亮。",
  "when": "老房子、阁楼、图书馆、回忆与独白、安静的主歌段；给静态画面加“空气感”。",
  "avoid": "户外大晴天或快节奏剪辑（尘埃是慢的）；光束方向与画面原有光源相反时会显假，调角度对齐。",
  "params": {
    "angle": { "type": "float", "default": 0.6, "min": -1.5, "max": 1.5, "label": "光束角度（弧度，0 = 竖直向下，正值向右下）" },
    "originX": { "type": "float", "default": 0.08, "min": -0.2, "max": 1.2, "label": "光源 X（画面上边缘）" },
    "width": { "type": "float", "default": 0.3, "min": 0.05, "max": 0.6, "label": "光束宽度" },
    "beam": { "type": "float", "default": 0.55, "min": 0, "max": 1.2, "label": "光束亮度" },
    "dust": { "type": "float", "default": 0.8, "min": 0, "max": 2, "label": "尘埃亮度" },
    "tint": { "type": "color", "default": "#ffe2b0", "label": "光色" }
  },
  "bindings": { "dust": { "to": "beat", "amount": 0.9 } },
  "inspiredBy": [{ "source": "chuspeeism-awesome-videos", "ref": "videos/motion-graphics：dust particles in light 描述", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：阳光从窗口斜射进昏暗的房间，空气里的灰尘只在光路中被照亮（光外的灰尘看不见），
// 所以我们看到的是“一条有边界的光柱 + 光柱里闪闪发亮的漂浮颗粒”。光柱因窗框和空气扰动而带有纵向条纹。

// 一层尘埃：把画面切成格子，每格最多一粒，位置/大小/闪烁相位都由格子哈希决定；整层缓慢漂移
float dustLayer(vec2 p, float scale, float t, float seed) {
  p += vec2(sin(t * .23 + seed) * .6, t * .35);  // 上升的热气流 + 左右摆动
  vec2 g = p * scale;
  vec2 id = floor(g);
  vec2 f = fract(g) - .5;
  float h = fxHash(id + seed);
  vec2 o = vec2(fxHash(id + seed + 3.1), fxHash(id + seed + 7.7)) - .5;
  o += .25 * vec2(sin(t * (.6 + h) + h * 6.), cos(t * (.5 + h) + h * 9.));  // 布朗式翻飞
  float d = length(f - o * .7);
  float size = mix(.05, .14, fxHash(id + seed + 1.3));
  float twinkle = .5 + .5 * sin(t * (1.5 + h * 2.) + h * 40.);           // 颗粒翻面时反光强弱
  return smoothstep(size, size * .2, d) * step(.55, h) * twinkle;
}

vec4 effect(vec2 uv) {
  vec3 base = srcTex(uv).rgb;
  float asp = uRes.x / uRes.y;
  vec2 p = vec2(uv.x * asp, uv.y);

  // ① 光路几何：光从画面上边缘某点（originX）沿 angle 方向射入；算每个像素到光轴的垂直距离与沿光轴的深度。
  vec2 O = vec2(originX * asp, 1.05);
  vec2 dir = vec2(sin(angle), -cos(angle));
  vec2 rel = p - O;
  float along = dot(rel, dir);
  float across = dot(rel, vec2(-dir.y, dir.x));

  // ② 光柱形状：越往前越宽（光从窗口发散），边缘柔和；沿光轴逐渐衰减（被空气吸收）。
  float halfW = width * (.5 + along * .35);
  float inBeam = smoothstep(halfW, halfW * .35, abs(across)) * step(0., along) * exp(-along * .55);

  // ③ 光柱条纹：窗框与空气扰动让光柱带有平行于光轴的明暗条纹，条纹很慢地漂移。
  float streaks = .65 + .35 * fxNoise(vec2(across / max(halfW, .01) * 6., along * .4 - uTime * .05));
  float shaft = inBeam * streaks;

  // ④ 尘埃：三层不同大小/速度的颗粒，只在光柱里被照亮（光外留 8% 表示极少的环境光）。
  //    dust 挂 beat：每拍颗粒整体闪亮一下再暗下去，像音乐在“扬尘”。
  float d = dustLayer(p, 26., uTime, 1.) + dustLayer(p, 48., uTime * .8, 5.) * .7 + dustLayer(p, 90., uTime * .6, 9.) * .45;
  float motes = d * (inBeam * .92 + .08) * dust;

  // ⑤ 合成：光束是加性的雾（屏幕混合，并在光里把暗部微微抬起），尘埃是更亮的小点。
  vec3 light = tint * (shaft * beam + motes);
  vec3 c = 1. - (1. - base) * (1. - clamp(light, 0., 1.));
  c = mix(c, c * .82, (1. - inBeam) * beam * .5);  // 光外的房间稍暗一点，突出光柱
  return vec4(c, 1.);
}
