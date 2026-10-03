/*@effect
{
  "id": "disco-ball",
  "name": "迪斯科球光斑",
  "kind": "post",
  "category": "光效与粒子",
  "tags": ["disco ball", "mirror ball", "light spots", "party", "70s", "迪斯科球", "镜面球", "光斑", "派对"],
  "summary": "满墙满地的小光斑（迪斯科镜面球的反光）在画面上缓慢旋转平移，光斑带一点彩色、时亮时暗；每拍光斑整体变亮一下。",
  "when": "派对/舞厅/复古迪斯科/放克、婚礼与生日、轻松愉快的副歌。",
  "avoid": "严肃悲伤题材；需要清楚看人脸的特写（光斑会落在脸上，可调低 amount）。",
  "params": {
    "amount": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "光斑亮度" },
    "density": { "type": "float", "default": 16, "min": 6, "max": 40, "label": "光斑密度（每屏高）" },
    "spin": { "type": "float", "default": 0.08, "min": -0.5, "max": 0.5, "label": "旋转速度" },
    "colorful": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "彩色程度" },
    "pulse": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "节拍增亮（通常由节拍驱动）" }
  },
  "bindings": { "pulse": { "to": "beat", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：舞台灯光", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：迪斯科球表面贴满小镜片，一束聚光灯打在球上，每片镜子把光反射到房间各处，形成成百上千个小光斑；
// 球在旋转，所以所有光斑一起沿同一方向缓慢移动；镜片朝向略有不同，光斑亮度不一、偶尔闪亮。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  // ① 光斑坐标：绕画面上方一点（球的位置）旋转（球在转），远离中心处光斑被拉长（斜射到墙上）
  vec2 C = vec2(.5, 1.1) * asp;
  vec2 p = uv * asp - C;
  float r = length(p), a = atan(p.y, p.x) + uTime * spin;
  vec2 q = vec2(a * 3., r * 3.) * density / 6.;
  vec2 id = floor(q), f = fract(q) - .5;
  // ② 每个光斑：格内随机位置、随机亮度、偶尔闪亮（镜片恰好对准）
  float h = fxHash(id);
  vec2 o = (vec2(fxHash(id + 1.), fxHash(id + 2.)) - .5) * .5;
  float d = length((f - o) * vec2(1., 1. + r * .5));
  float spot = smoothstep(.16, .06, d) * (.4 + .6 * h);
  float twinkle = step(.93, fxHash(id + floor(uTime * 4.)));
  // ③ 颜色：大部分白，一部分带彩（镜片后的彩色滤光）
  vec3 col = mix(vec3(1.), .5 + .5 * cos(6.2832 * (h + vec3(0., .33, .67))), colorful * step(.5, fxHash(id + 5.)));
  float lum = spot * (1. + twinkle * 1.5) * (amount + pulse * .6);
  // ④ 合成：光斑是加光；房间整体略暗（迪斯科舞厅）
  vec3 c = 1. - (1. - src * .8) * (1. - clamp(col * lum, 0., 1.));
  return vec4(c, 1.);
}
