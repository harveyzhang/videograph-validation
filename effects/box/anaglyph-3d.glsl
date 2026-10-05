/*@effect
{
  "id": "anaglyph-3d",
  "name": "红蓝 3D",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["anaglyph", "3d glasses", "red cyan", "stereoscopic", "retro 3d", "红蓝3D", "立体眼镜", "复古", "双色"],
  "summary": "老式红蓝立体眼镜的 3D 效果：画面被分成红、青两个通道并左右错开，亮部与轮廓处的红青双影最明显；错开距离随拍一张一缩，像画面在“出屏”。",
  "when": "复古电影院/50 年代科幻、潮流与 Y2K、电子乐与迷幻、给普通画面加一点“错位”的冲击。",
  "avoid": "需要准确颜色的镜头；长时间观看会累（建议用在短段落）。",
  "params": {
    "offset": { "type": "float", "default": 0.008, "min": 0, "max": 0.04, "label": "左右错开" },
    "depth": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "按亮度分层（亮部错得更多）" },
    "desat": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "去色程度（3D 胶片通常偏灰）" },
    "pop": { "type": "float", "default": 0, "min": 0, "max": 0.03, "label": "节拍出屏（通常由节拍驱动）" }
  },
  "bindings": { "pop": { "to": "kick", "amount": 0.01 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：复古 3D", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：红蓝 3D 把左眼画面印成红色、右眼画面印成青色叠在一起，两幅画面的水平错位就是“视差”——
// 错位越大的物体看起来离屏幕越远/越近。戴眼镜时每只眼只看到一种颜色；不戴眼镜就是这种红青双影。
// 这里没有深度信息，用亮度近似深度（亮的物体当作更近，错位更大）。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 视差：基础错位 + 按亮度的深度 + 节拍出屏
  float l = fxLuma(src);
  float par = (offset + pop) * mix(1., .4 + 1.2 * l, depth);
  // ② 左眼（红）取右移、右眼（青）取左移
  vec3 L = srcTex(uv + vec2(par, 0.)).rgb;
  vec3 R = srcTex(uv - vec2(par, 0.)).rgb;
  float lL = fxLuma(L), lR = fxLuma(R);
  vec3 left = mix(L, vec3(lL), desat);
  vec3 right = mix(R, vec3(lR), desat);
  // ③ 合成：红通道来自左眼，绿蓝通道来自右眼
  vec3 c = vec3(left.r, right.g, right.b);
  return vec4(c, 1.);
}
