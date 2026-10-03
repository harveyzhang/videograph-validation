/*@effect
{
  "id": "gen-spotlights",
  "name": "舞台追光",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["spotlight", "stage lights", "concert", "beams", "moving head", "追光", "舞台灯", "演唱会", "光束"],
  "summary": "画面上方挂着几盏舞台摇头灯，打出带烟雾感的锥形光束左右扫动、在地面形成椭圆光斑；光束颜色各异，鼓点时所有灯齐亮一下。",
  "when": "演唱会/Live/选秀/颁奖、夜店与派对、偶像与乐队 MV、发布会开场。",
  "avoid": "白天户外与自然题材；光束扫过人脸会遮挡表情（调低 intensity）。",
  "params": {
    "count": { "type": "float", "default": 4, "min": 1, "max": 8, "label": "灯的数量" },
    "intensity": { "type": "float", "default": 0.55, "min": 0, "max": 1.5, "label": "光束亮度" },
    "sweep": { "type": "float", "default": 0.5, "min": 0, "max": 1.5, "label": "扫动幅度（弧度）" },
    "width": { "type": "float", "default": 0.09, "min": 0.02, "max": 0.3, "label": "光束张角" },
    "hit": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点齐亮（通常由节拍驱动）" },
    "haze": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "烟雾感（光束里的颗粒）" }
  },
  "bindings": { "hit": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：舞台灯光", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：舞台上方的摇头灯打出锥形光束，光束本身之所以看得见，是因为舞台上放了烟机（光被烟雾颗粒散射）；
// 光束扫动、变色，打到地面形成光斑；鼓点时灯光师会让所有灯同时闪一下。

vec3 hue(float h) { return clamp(abs(fract(h + vec3(0., .667, .333)) * 6. - 3.) - 1., 0., 1.); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp;
  vec3 light = vec3(0.);
  float n = floor(count + .5);
  // ① 烟雾：光束里的颗粒（慢速漂移的噪声），让光束有体积感
  float smoke = mix(1., .55 + .9 * fxFbm(p * 4. + vec2(uTime * .05, -uTime * .03)), haze);
  for (int i = 0; i < 8; i++) {
    float fi = float(i);
    if (fi >= n) break;
    // ② 灯位：均匀挂在画面顶部；角度 = 向下 + 每盏灯自己的正弦扫动
    vec2 L = vec2((fi + .5) / n * asp.x, 1.05);
    float ang = -1.5708 + sin(uTime * (.5 + fi * .13) + fi * 1.7) * sweep;
    vec2 dir = vec2(cos(ang), sin(ang));
    vec2 d = p - L;
    float along = dot(d, dir);
    float across = abs(dot(d, vec2(-dir.y, dir.x)));
    // ③ 锥形：允许的横向距离随沿光轴的距离线性增大；边缘柔和；随距离衰减
    float cone = smoothstep(width * along + .005, width * along * .3, across) * step(0., along);
    float atten = exp(-along * .8);
    vec3 col = hue(fi / n + uTime * .03) * .7 + .3;
    light += col * cone * atten * smoke * (intensity + hit * .8);
    // ④ 地面光斑：光束与画面底部附近相交处的椭圆
    vec2 spot = L + dir * ((L.y - .1) / max(-dir.y, .2));
    float s = exp(-length((p - spot) * vec2(1., 3.5)) * 9.);
    light += col * s * .5 * (intensity + hit);
  }
  vec3 c = 1. - (1. - src * .85) * (1. - clamp(light, 0., 1.));
  return vec4(c, 1.);
}
