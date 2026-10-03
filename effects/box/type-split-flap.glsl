/*@effect
{
  "id": "type-split-flap",
  "name": "翻牌显示屏",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["split flap", "solari board", "departure board", "flip", "text reveal", "翻牌", "机场显示屏", "文字揭示"],
  "summary": "画面被切成一块块机场翻牌：开头每块牌子先显示乱跳的字块，然后从左到右依次“啪”地翻到真实画面，牌子中间有铰链缝；鼓点时少数牌子重新翻一次。",
  "when": "旅行、车站/机场、复古科技、倒计时、数据或名单公布；文字与图形都适用。",
  "avoid": "需要连续观看细节的镜头（牌缝会切开画面）；牌子太小时翻页动作看不清。",
  "params": {
    "tile": { "type": "float", "default": 0.1, "min": 0.015, "max": 0.3, "label": "牌子宽度（画面高度比例）" },
    "inEnd": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.8, "label": "全部翻完于镜头进度" },
    "flipTime": { "type": "float", "default": 0.06, "min": 0.01, "max": 0.2, "label": "单块翻页时长（镜头进度）" },
    "shuffle": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点重翻比例（通常由节拍驱动）" },
    "panel": { "type": "color", "default": "#16161a", "label": "牌面底色" },
    "glyph": { "type": "color", "default": "#e8e2d4", "label": "乱跳字块颜色" }
  },
  "bindings": { "shuffle": { "to": "kick", "amount": 0.25 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：翻牌/逐格揭示", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（Solari 翻牌板）：每块牌子是一叠绕中轴转动的薄片，上半片翻下来盖住下半片，一次换一个字符；
// 更新信息时牌子从左到右依次翻，翻到正确的字才停。翻页那一下，上半片先压扁消失，新的下半片再展开。

vec4 effect(vec2 uv) {
  // ① 牌格：宽 tile、高 1.4×tile；求格子编号与格内位置。
  vec2 size = vec2(tile, tile * 1.4) * uRes.y;
  vec2 g = uv * uRes / size;
  vec2 id = floor(g), f = fract(g);
  vec2 cuv = (id + f) * size / uRes;   // 格内对应的原画面位置（真实内容）

  // ② 翻页时刻：从左到右（行间略有延迟）+ 随机抖动；鼓点时一小部分牌子再翻一次（shuffle 挂 kick）。
  float cols = uRes.x / size.x;
  float order = clamp(id.x / cols + fxHash(id) * .15 - id.y * .02, 0., 1.);
  float tFlip = order * (inEnd - flipTime);
  float ph = clamp((uProgress - tFlip) / flipTime, 0., 1.);       // 0 未翻，1 已翻好
  float re = step(fxHash(id + floor(uTime * 2.)), shuffle * .4);
  if (re > .5) ph = min(ph, fract(uTime * 2.) * 1.6);              // 重翻：半秒内再翻一次

  // ③ 旧牌面：乱跳的字块（3×5 点阵伪字形，每 1/12 秒换一次），新牌面：真实画面。
  vec2 q = (f - vec2(.22, .14)) / vec2(.56, .72);
  float bit = 0.;
  if (q.x >= 0. && q.x < 1. && q.y >= 0. && q.y < 1.) bit = step(.5, fxHash(id * 3.1 + floor(q * vec2(3., 5.)) * 1.9 + floor(uTime * 12.)));
  vec3 oldFace = mix(panel, glyph, bit * .55);   // 旧牌面的字块偏暗，翻到真实画面时才“亮”起来
  vec3 newFace = srcTex(cuv).rgb;

  // ④ 翻页几何：前半程上半片绕中轴压扁（显示旧面，越来越窄且变暗），后半程新的上半片展开；下半片在半程时被新面盖住。
  vec3 c;
  float top = step(.5, f.y);
  if (ph <= 0.) c = oldFace;
  else if (ph >= 1.) c = newFace;
  else if (ph < .5) {
    float k = cos(ph * 3.1416);                                     // 1 → 0：上半片压扁
    float y = .5 + (f.y - .5) / max(k, .001);
    c = top > .5 ? (y <= 1. ? mix(newFace, oldFace, 1.) * (.5 + .5 * k) : newFace) : oldFace;
  } else {
    float k = -cos(ph * 3.1416);                                    // 0 → 1：新下半片展开
    float y = .5 - (.5 - f.y) / max(k, .001);
    c = top > .5 ? newFace : (y >= 0. ? newFace * (.5 + .5 * k) : oldFace);
  }

  // ⑤ 牌子结构：四周深色缝隙 + 中间的铰链细缝 + 上下半片轻微的明暗差。
  vec2 px = 1.5 / size;
  float gap = step(f.x, px.x) + step(1. - px.x, f.x) + step(f.y, px.y) + step(1. - px.y, f.y);
  float hinge = smoothstep(px.y * 1.2, 0., abs(f.y - .5));
  c *= (1. - min(gap, 1.) * .85) * (1. - hinge * .6) * mix(.92, 1.04, top);
  return vec4(c, 1.);
}
