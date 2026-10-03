/*@effect
{
  "id": "color-negative",
  "name": "彩色负片底片",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["negative", "film negative", "orange mask", "inverted", "darkroom", "负片", "底片", "反相"],
  "summary": "未经反转的彩色负片底片：明暗与颜色全部反相，罩着一层橙色片基，边缘有片孔和片号文字，像对着灯箱看底片；鼓点时灯箱一亮。",
  "when": "暗房与摄影题材、回忆被“翻到背面”、悬疑反转、艺术短片与过场；可与正常画面交替剪辑做揭示。",
  "avoid": "需要识别内容的镜头（反相后人脸会很难认）；连续长时间使用会让观众疲劳。",
  "params": {
    "mask": { "type": "color", "default": "#d9813f", "label": "片基橙色" },
    "density": { "type": "float", "default": 0.85, "min": 0.3, "max": 1.2, "label": "底片密度" },
    "sprockets": { "type": "float", "default": 1, "min": 0, "max": 1, "label": "片孔与片边" },
    "lightbox": { "type": "float", "default": 1, "min": 0.6, "max": 1.6, "label": "灯箱亮度" }
  },
  "bindings": { "lightbox": { "to": "kick", "amount": 0.25 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：胶片质感", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：彩色负片记录的是“补色 + 反相”的影像：亮的地方银多、染料密度大（看起来暗），颜色是补色；
// 为了校正染料的不纯，片基被做成橙色（橙色遮罩），所以整卷底片看起来是橙棕色的。
// 对着灯箱看：灯光透过片基与染料，片边有齿孔（片孔）与印上去的片号、画格编号。

vec4 effect(vec2 uv) {
  // ① 画格：35mm 底片画面区域在中间，上下是片边（各约 13%）。
  float edge = sprockets;
  float top = 1. - .13 * edge, bot = .13 * edge;
  vec2 iuv = vec2(uv.x, (uv.y - bot) / max(top - bot, .01));
  float inFrame = step(bot, uv.y) * step(uv.y, top);

  // ② 影像反相：亮处银多 → 密度大 → 透光少；颜色变成补色。density 控制反相的“深浅”。
  vec3 src = srcTex(clamp(iuv, 0., 1.)).rgb;
  vec3 neg = 1. - src * density;

  // ③ 橙色遮罩：片基本身的颜色叠在整张底片上（相乘）。
  vec3 c = neg * mask * 1.15;

  // ④ 片边：片基色更透（没有影像），上下各一排圆角方形片孔（透出灯箱的白光），片边印着片号与画格箭头。
  vec3 base = mask * 1.2;
  float pitch = .055;
  float px = fract(uv.x / pitch) - .5;
  float yHole = uv.y < .5 ? uv.y - bot * .5 : uv.y - (1. - bot * .5);
  vec2 hd = abs(vec2(px * pitch, yHole)) - vec2(pitch * .18, .03 * edge);
  float hole = 1. - smoothstep(0., .003, length(max(hd, 0.)) - .004);
  // 片号：用一串小方块代替文字（每隔几个片孔一组“数字”），只在下片边
  float code = step(abs(uv.y - bot * .2), .012) * step(.5, fxHash(vec2(floor(uv.x * 90.), 1.))) * step(.25, fract(uv.x * 90.)) * step(fract(uv.x * 4.), .35);
  vec3 film = base * (1. - code * .45);
  film = mix(film, vec3(1., .98, .92), hole);
  c = mix(film, c, inFrame);

  // ⑤ 灯箱：整体透光亮度（lightbox 挂鼓点：鼓点时灯箱一亮），以及中心略亮的不均匀与灰尘。
  c *= lightbox * (1.05 - .2 * length(uv - .5));
  c *= 1. - step(.9985, fxHash(floor(uv * uRes * .5))) * .6;
  return vec4(clamp(c, 0., 1.), 1.);
}
