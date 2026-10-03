/*@effect
{
  "id": "beat-pixel-burst",
  "name": "拍点像素爆散",
  "kind": "post",
  "category": "运动与节拍",
  "tags": ["pixel burst", "disintegrate", "shatter", "particles", "beat", "像素爆散", "碎裂", "解体"],
  "summary": "鼓点那一刻画面碎成方块像素，像被冲击波从中心炸开：方块向外飞散、翻转变暗，然后在拍内迅速飞回拼合成完整画面。",
  "when": "副歌爆点、转折、游戏/科技主题的卡点、标题“炸开”的瞬间；每个鼓点一次。",
  "avoid": "需要连贯阅读的镜头；鼓点很密（>3 次/秒）时画面会一直是碎的。",
  "params": {
    "burst": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "爆散程度（通常由节拍驱动）" },
    "block": { "type": "float", "default": 18, "min": 6, "max": 60, "label": "方块大小（像素）" },
    "travel": { "type": "float", "default": 0.08, "min": 0.01, "max": 0.3, "label": "飞散距离" },
    "gap": { "type": "float", "default": 0.12, "min": 0, "max": 0.5, "label": "方块间隙" }
  },
  "bindings": { "burst": { "to": "kick", "amount": 0.9 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques 节奏与卡点：像素化爆散/重组", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（动态设计）：设计师把画面切成方块，每块当作一片独立的“卡片”，在冲击帧让它们从中心向外飞散、
// 带一点随机延迟与翻转，然后用缓动拉回拼合——观众看到的是“画面被音乐炸碎又复原”。
// 实现思路（无帧间状态）：每个输出像素反查“哪块卡片现在飞到了这里”，只需检查自己所在格与相邻格（9 块）。

vec4 effect(vec2 uv) {
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 g = uv * uRes / block;
  vec2 base = floor(g);
  float b = clamp(burst, 0., 1.);

  // ① 反查：卡片 id 原本在 (id+.5) 格的位置，飞散后中心移动 = 从画面中心向外的方向 × 距离 × 每块的随机延迟。
  //    burst 挂鼓点：鼓点时最大（飞得最远），随衰减飞回原位。
  vec3 col = vec3(0.);
  float found = 0.;
  float maxShift = travel * uRes.y / block;          // 最大位移（以格为单位）
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = base + vec2(float(i), float(j));
      vec2 home = (id + .5) * block / uRes;            // 卡片原位置（uv）
      vec2 dir = normalize((home - .5) * asp + 1e-4);
      float delay = fxHash(id);                          // 每块不同的反应强度
      float amt = b * (.4 + .6 * delay);
      vec2 shift = dir * amt * maxShift + (vec2(fxHash(id + 3.), fxHash(id + 7.)) - .5) * amt * 1.2;
      shift = clamp(shift, vec2(-1.), vec2(1.));          // 限制在相邻格内（只检查了 3×3）
      // ② 卡片几何：飞行中的卡片缩小（翻转的透视），留出间隙；当前像素若落在卡片内就取卡片上的画面。
      vec2 local = g - (id + shift);                      // 像素在卡片坐标中的位置（0..1 为卡片内）
      float shrink = gap * amt + (1. - cos(amt * 3.1416 * delay)) * .15;
      vec2 lc = (local - .5) / (1. - shrink) + .5;
      if (lc.x >= 0. && lc.x <= 1. && lc.y >= 0. && lc.y <= 1.) {
        vec3 s = srcTex((id + lc) * block / uRes).rgb;
        // ③ 翻转变暗：卡片转离观众时受光变少，按随机程度变暗
        s *= 1. - amt * .45 * fxHash(id + 11.);
        col = s;
        found = 1.;
      }
    }
  }

  // ④ 卡片飞走后露出的背景：深色底 + 极淡的原画面（像画面的“残影”）。b 为 0 时所有卡片归位，与原画面完全一致。
  vec3 bg = srcTex(uv).rgb * .15 + vec3(.02, .02, .03);
  return vec4(mix(bg, col, found), 1.);
}
