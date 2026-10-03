/*@effect
{
  "id": "gen-sparkle-trail",
  "name": "魔法闪粉轨迹",
  "kind": "post",
  "category": "生成层",
  "tags": ["sparkle", "magic", "fairy dust", "trail", "glitter", "闪粉", "魔法", "仙尘", "轨迹"],
  "summary": "一颗明亮的光点沿一条优雅的 8 字形曲线在画面里飞行，身后拖着一串逐渐消散的星形闪粉；每拍光点亮一下、撒出更多闪粉。",
  "when": "童话/魔法/节日、产品“变出来”的瞬间、标题出现前的引导、儿童与梦幻题材。",
  "avoid": "写实严肃题材；画面已有复杂运动时（轨迹会抢视线）。",
  "params": {
    "size": { "type": "float", "default": 0.4, "min": 0.1, "max": 0.8, "label": "飞行范围" },
    "speed": { "type": "float", "default": 0.35, "min": 0.05, "max": 2, "label": "飞行速度" },
    "trail": { "type": "float", "default": 0.6, "min": 0.1, "max": 1.5, "label": "尾迹长度（秒）" },
    "burst": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "节拍撒粉（通常由节拍驱动）" },
    "color": { "type": "color", "default": "#ffe7a3", "label": "闪粉颜色" }
  },
  "bindings": { "burst": { "to": "beat", "amount": 0.8 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：引导光点", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（动画里的“仙尘”）：魔杖或小精灵飞过时撒下一路闪光的颗粒，颗粒很快变暗、略微下落；
// 每颗颗粒是一个小十字星。实现：光点位置 = 时间的解析函数（利萨如 8 字曲线），尾迹 = 过去 N 个时刻的位置各撒一颗闪粉。

vec2 pathAt(float t) {
  return vec2(.5, .5) + vec2(sin(t * speed * 2.) * size * .9, sin(t * speed * 4.) * size * .45);
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp;
  float light = 0.;
  // ① 尾迹：过去 trail 秒里取 24 个时刻，每个时刻撒一颗闪粉（随机偏离路径、受“重力”下落、逐渐熄灭）
  for (int i = 0; i < 24; i++) {
    float k = float(i) / 24.;
    float tb = uTime - k * trail;                        // 这颗闪粉的诞生时刻
    float seed = floor(tb * 40.);
    vec2 born = pathAt(tb) * asp + (vec2(fxHash(vec2(seed, 1.)), fxHash(vec2(seed, 2.))) - .5) * .08 * (1. + burst);
    vec2 pos = born - vec2(0., k * trail * .05);          // 缓慢下落
    vec2 d = p - pos;
    float life = 1. - k;
    float sz = max(.01 * life + .004, 2.5 / uRes.y);
    // ② 星形闪粉：十字（两条细光）+ 中心点
    float star = smoothstep(sz * .25, 0., abs(d.x)) * smoothstep(sz * 2.5, 0., abs(d.y)) + smoothstep(sz * .25, 0., abs(d.y)) * smoothstep(sz * 2.5, 0., abs(d.x));
    star += smoothstep(sz * .6, 0., length(d));
    float tw = .6 + .4 * sin(seed * 7.3 + uTime * 20.);
    light += star * life * tw * 1.5;
  }
  // ③ 光点本体：亮核 + 光晕，每拍更亮
  vec2 head = pathAt(uTime) * asp;
  float hd = length(p - head);
  light += smoothstep(max(.016, 3. / uRes.y), 0., hd) * 1.5 + exp(-hd / .04) * (.6 + burst);
  vec3 c = 1. - (1. - src) * (1. - clamp(color * light, 0., 1.));
  return vec4(c, 1.);
}
