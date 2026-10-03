/*@effect
{
  "id": "stripe-shift",
  "name": "条纹位移",
  "kind": "post",
  "category": "几何与图形",
  "tags": ["stripes", "slice", "offset", "displacement", "slit", "条纹", "切片", "位移"],
  "summary": "画面被切成等宽的竖条（或横条），每条按自己的节奏上下滑动错开，条与条之间留细缝；鼓点时整排条纹被推开再归位。",
  "when": "时尚/潮流宣传片、音乐节海报感、标题字切片、节奏感强的过门；与几何排版类字幕很搭。",
  "avoid": "需要稳定阅读的长文字；对位移很敏感的写实人物镜头（会显得“被切开”）。",
  "params": {
    "count": { "type": "float", "default": 14, "min": 3, "max": 60, "label": "条数" },
    "offset": { "type": "float", "default": 0.025, "min": 0, "max": 0.2, "label": "位移量" },
    "vertical": { "type": "bool", "default": true, "label": "竖条（关 = 横条）" },
    "gap": { "type": "float", "default": 0.08, "min": 0, "max": 0.4, "label": "条缝宽度（条宽比例）" },
    "gapColor": { "type": "color", "default": "#111114", "label": "条缝颜色" }
  },
  "bindings": { "offset": { "to": "kick", "amount": 0.05 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/swiss-motion：网格与切片排版", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：平面设计里的“切条错位”是把一张海报裁成等宽纸条，贴回去时每条上下错开一点；
// 动态版本就是每根纸条各自缓慢滑动（像百叶窗后面的画面），节拍到时整排被推开，形成有秩序的错乱。

vec4 effect(vec2 uv) {
  // ① 裁条：沿横向（竖条）或纵向（横条）切成 count 条，算出当前像素在第几条、在条内的位置。
  float along = vertical ? uv.x : uv.y;
  float k = floor(along * count);
  float inStrip = fract(along * count);

  // ② 每条的滑动：方向交替（奇偶条反向）+ 每条自己的相位与速度，缓慢正弦滑动；
  //    offset 挂鼓点：鼓点时所有条一起被推开到最大，再衰减回平时的轻微滑动。
  float dir = mod(k, 2.) < 1. ? 1. : -1.;
  float phase = fxHash(vec2(k, 3.)) * 6.2832;
  float speed = .6 + fxHash(vec2(k, 7.)) * .8;
  float s = dir * offset * (.35 + .65 * (.5 + .5 * sin(uTime * speed + phase)));
  vec2 shift = vertical ? vec2(0., s) : vec2(s, 0.);

  // ③ 贴回：从错开后的位置取画面。条之间是纸张背后的底色（gap），条边有极细的阴影（纸条略微翘起）。
  vec3 col = srcTex(uv + shift).rgb;
  float edgeDist = min(inStrip, 1. - inStrip);
  float px = count / (vertical ? uRes.x : uRes.y);       // 一个像素在条内坐标中的宽度
  float inGap = smoothstep(gap * .5 + px, gap * .5, edgeDist);
  float shade = smoothstep(gap * .5 + px * 4., gap * .5 + px, edgeDist) * (1. - inGap);
  col *= 1. - shade * .25;
  col = mix(col, gapColor, inGap);
  return vec4(col, 1.);
}
