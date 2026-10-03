/*@effect
{
  "id": "gen-rain",
  "name": "雨丝",
  "kind": "post",
  "category": "生成层",
  "tags": ["rain", "storm", "weather", "streaks", "overlay", "下雨", "雨丝", "暴雨", "天气"],
  "summary": "斜落的雨丝分远近两层划过画面，地面一带有小水花溅起；画面整体压暗偏冷；音乐能量越高雨越大、越斜。",
  "when": "悲伤/失恋/离别、黑色电影与都市夜景、悬疑与惊悚、情绪爆发的副歌。",
  "avoid": "晴朗欢快的画面；需要清楚看细节的产品镜头。",
  "params": {
    "amount": { "type": "float", "default": 0.7, "min": 0, "max": 1, "label": "雨量" },
    "slant": { "type": "float", "default": 0.18, "min": -0.6, "max": 0.6, "label": "倾斜" },
    "speed": { "type": "float", "default": 1.6, "min": 0.3, "max": 4, "label": "下落速度（屏高/秒）" },
    "gloom": { "type": "float", "default": 0.25, "min": 0, "max": 0.7, "label": "阴天压暗" },
    "storm": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "暴雨增强（通常由音乐能量驱动）" },
    "splashLine": { "type": "float", "default": 0.12, "min": 0, "max": 0.5, "label": "水花地面高度（0 = 不显示）" }
  },
  "bindings": { "storm": { "to": "energy", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：天气粒子层", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：雨滴下落很快，摄像机快门时间内它划过一段距离，所以拍出来是“丝”而不是点；
// 近处的雨丝粗而亮、远处细而淡；雨丝在逆光处最明显。雨滴落地溅起小水花与涟漪；阴雨天整体光线偏冷偏暗。

float rainLayer(vec2 p, float cols, float len, float spd, float seed, float dens) {
  // 斜坐标：让雨丝沿 slant 方向
  vec2 q = vec2(p.x + p.y * (slant + storm * .15), p.y);
  q.x *= cols;
  float col = floor(q.x);
  float h = fxHash(vec2(col, seed));
  // 每列若干滴：沿 y 周期排列，相位随列随机
  float y = q.y * 3. - uTime * spd * (.8 + .4 * h) * 3. + h * 10.;
  float cell = floor(y);
  float has = step(fxHash(vec2(col, cell + seed)), dens);
  float f = fract(y);
  float x = fract(q.x) - .5 - (fxHash(vec2(col, cell)) - .5) * .5;
  float line = smoothstep(.06, 0., abs(x)) * smoothstep(0., .05, f) * smoothstep(len, len * .4, f);
  return line * has;
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, 1. - uv.y);

  // ① 阴天：先把画面压暗、偏冷（雨天的散射光）。
  float g = gloom + storm * .1;
  vec3 c = mix(src, src * vec3(.75, .82, .95), g);

  // ② 两层雨丝：远层细密淡、近层粗疏亮；storm 挂音乐能量：激烈段落雨更大更斜。
  float dens = clamp(amount + storm * .35, 0., 1.);
  float far = rainLayer(p, 140., .45, speed, 1., dens * .8);
  float nearL = rainLayer(p + 3.1, 55., .6, speed * 1.4, 7., dens * .5);
  float rain = far * .45 + nearL * .7;

  // ③ 水花：地面一带（画面底部 splashLine 高度内）随机出现的小椭圆涟漪，每格每 0.4 秒重新落一滴。
  float splash = 0.;
  if (splashLine > 0.) {
    vec2 s = vec2(p.x * 18., (p.y - (1. - splashLine)) * 30.);
    vec2 id = floor(s);
    float t = fract(uTime * 2.5 + fxHash(id));
    vec2 f = fract(s) - .5;
    float r = t * .45;
    float ring = smoothstep(.04, 0., abs(length(f * vec2(1., 2.4)) - r)) * (1. - t);
    splash = ring * step(1. - splashLine, p.y) * step(fxHash(id + 3.), dens);
  }

  // ④ 合成：雨丝与水花都是亮的（反射天光），用 screen 叠加。
  vec3 rc = vec3(.82, .88, .98) * (rain + splash * .6);
  c = 1. - (1. - c) * (1. - clamp(rc, 0., 1.));
  return vec4(c, 1.);
}
