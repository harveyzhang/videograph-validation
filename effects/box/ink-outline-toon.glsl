/*@effect
{
  "id": "ink-outline-toon",
  "name": "卡通描线上色",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["toon", "cel shading", "cartoon", "anime", "outline", "卡通", "赛璐珞", "动画", "描线"],
  "summary": "把画面变成赛璐珞动画风：颜色压成两到三阶的平涂明暗（亮面/暗面分明），轮廓与明暗交界勾上墨线，高光处加一块纯白的“动画高光”；鼓点时墨线加粗一下。",
  "when": "动漫/二次元风格、卡通化的产品与人物、轻松的品牌片、游戏宣传。",
  "avoid": "需要写实细节与渐变的画面；画面噪点很多时会出现杂乱的线。",
  "params": {
    "steps": { "type": "float", "default": 3, "min": 2, "max": 6, "label": "明暗阶数" },
    "line": { "type": "float", "default": 0.8, "min": 0, "max": 2, "label": "墨线强度（通常由节拍驱动）" },
    "saturation": { "type": "float", "default": 1.3, "min": 0.5, "max": 2, "label": "饱和度" },
    "spec": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "动画高光" }
  },
  "bindings": { "line": { "to": "kick", "amount": 0.5 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/cel-anime-80s 与 scifi-toon", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（赛璐珞动画）：每一格画面先勾墨线，再在透明胶片背面用几种平涂颜色上色——“亮面一种颜色、暗面一种颜色”，
// 没有渐变；高光是一块形状明确的纯白。这样的明暗分阶就是“卡通着色”。

vec4 effect(vec2 uv) {
  // ① 轻微平滑（5 次采样）去掉噪点，避免产生杂线
  vec2 o = 1.5 / uRes;
  vec3 s = (srcTex(uv).rgb * 2. + srcTex(uv + vec2(o.x, 0.)).rgb + srcTex(uv - vec2(o.x, 0.)).rgb + srcTex(uv + vec2(0., o.y)).rgb + srcTex(uv - vec2(0., o.y)).rgb) / 6.;
  float l = fxLuma(s);
  // ② 明暗分阶：亮度量化成 steps 阶，色相保留（颜色 ÷ 亮度 × 量化亮度），提饱和
  float q = (floor(l * steps) + .5) / steps;
  vec3 hue = s / max(l, .05);
  vec3 c = clamp(hue * q, 0., 1.);
  c = mix(vec3(fxLuma(c)), c, saturation);
  // ③ 动画高光：最亮的区域直接变成纯白块
  c = mix(c, vec3(1.), step(.88, l) * spec);
  // ④ 墨线：轮廓（Sobel，9 次采样）
  float e = smoothstep(.12, .3, fxSobel(uv)) * line;
  c = mix(c, vec3(.07, .06, .08), clamp(e, 0., 1.));
  return vec4(c, 1.);
}
