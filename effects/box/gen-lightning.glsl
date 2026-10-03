/*@effect
{
  "id": "gen-lightning",
  "name": "闪电",
  "kind": "post",
  "category": "生成层",
  "tags": ["lightning", "storm", "thunder", "electric", "bolt", "闪电", "雷暴", "电光", "打雷"],
  "summary": "画面上部压上一层冷色雷雨云；在小节开头（按概率）从上方劈下一道分叉闪电：主干明亮带辉光、分支细而短，天空随之微微一亮再迅速熄灭；每道闪电形状都不同。",
  "when": "暴风雨、电子乐 drop、超能力与觉醒、恐怖与悬疑转折、摇滚与金属的重拍。",
  "avoid": "晴朗温和的画面；对光敏感的观众场景要调低 skyFlash（已限制为每小节最多一次）。",
  "params": {
    "chance": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "每小节出现概率" },
    "boltX": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "落点大致位置 X" },
    "spread": { "type": "float", "default": 0.3, "min": 0, "max": 0.5, "label": "落点随机范围" },
    "overcast": { "type": "float", "default": 0.3, "min": 0, "max": 0.8, "label": "雷雨云压暗（常驻）" },
    "skyFlash": { "type": "float", "default": 0.12, "min": 0, "max": 0.3, "label": "天空闪亮（低值更安全）" },
    "charge": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "能量增强（通常由音乐能量驱动）" },
    "color": { "type": "color", "default": "#d9e4ff", "label": "电光颜色" },
    "barSeconds": { "type": "float", "default": 2, "min": 0.5, "max": 8, "label": "小节时长（秒，= 240 / BPM；用于让同一小节的闪电形状不变）" }
  },
  "bindings": { "charge": { "to": "energy", "amount": 0.4 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：天气与冲击", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：闪电是沿空气中阻力最小的路径一节一节向下“跳”的放电，所以是锯齿状折线，并不断分叉；
// 主通道最亮（周围空气被照亮形成辉光），整个过程只有零点几秒，云层和天空被瞬间照亮。
// 安全：闪电只出现在小节开头 0.18 个小节内（120 BPM 约 0.35 秒），每小节最多一次（≤0.5 次/秒），天空增亮幅度有上限。

float segDist(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.));
}

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 本小节是否打雷：小节序号用 uTime 与小节相位推算（同一小节内的所有帧结论一致）。
  //    小节起点时刻 = 当前时间 − 小节相位 × 小节时长；同一小节内恒定，作为本道闪电形状的随机种子。
  float barStart = uTime - uBar * barSeconds;
  float seed = floor(barStart / barSeconds + .5);
  float on = step(fxHash(vec2(seed, 1.)), chance + charge * .3);
  float life = on * (1. - smoothstep(0., .18, uBar)) * (.75 + .25 * step(.5, fract(uBar * 40.)));   // 主放电 + 一两次回闪

  // ①′ 雷雨云：常驻的冷色压暗，越往上越重（雷暴天的天空），闪电不出现时也成立。
  src = mix(src, src * vec3(.62, .68, .82), overcast * smoothstep(.2, 1., uv.y));
  if (life <= 0.) return vec4(src, 1.);

  // ② 主通道：从顶部到画面 15–45% 高度的 12 段折线，每段横向随机偏移（锯齿）。
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = uv * asp;
  float x0 = (boltX + (fxHash(vec2(seed, 2.)) - .5) * spread * 2.) * asp.x;
  float yEnd = .15 + .3 * fxHash(vec2(seed, 3.));
  float d = 1e3, dBranch = 1e3;
  vec2 prev = vec2(x0, 1.05);
  for (int i = 1; i <= 12; i++) {
    float t = float(i) / 12.;
    vec2 cur = vec2(prev.x + (fxHash(vec2(seed, float(i) + 10.)) - .5) * .09, mix(1.05, yEnd, t));
    d = min(d, segDist(p, prev, cur));
    // ③ 分支：第 3、6、9 段各分出一支 4 段的短枝，向一侧斜下方
    if (i == 3 || i == 6 || i == 9) {
      vec2 b0 = cur;
      float dir = fxHash(vec2(seed, float(i) + 50.)) > .5 ? 1. : -1.;
      for (int k = 1; k <= 4; k++) {
        vec2 b1 = b0 + vec2(dir * (.02 + .03 * fxHash(vec2(seed, float(i * 10 + k)))), -.035 - .02 * fxHash(vec2(seed, float(i * 10 + k) + 7.)));
        dBranch = min(dBranch, segDist(p, b0, b1));
        b0 = b1;
      }
    }
    prev = cur;
  }

  // ④ 光：主通道芯（约 2 像素）+ 宽辉光，分支更细更淡；天空整体轻微增亮（上部更亮）。
  float px = 1. / uRes.y;
  float core = smoothstep(px * 2.5, 0., d) + smoothstep(px * 1.5, 0., dBranch) * .7;
  float glow = exp(-d / .02) * .6 + exp(-dBranch / .012) * .25;
  vec3 c = src + skyFlash * life * color * smoothstep(0., 1., uv.y) * .8;
  c = 1. - (1. - c) * (1. - clamp(color * (core * 1.5 + glow) * life, 0., 1.));
  return vec4(c, 1.);
}
