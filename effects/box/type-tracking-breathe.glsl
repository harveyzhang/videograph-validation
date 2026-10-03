/*@effect
{
  "id": "type-tracking-breathe",
  "name": "字距呼吸",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "tracking", "letter spacing", "expand", "breathe", "文字", "字距", "扩张", "呼吸"],
  "summary": "文字的字距随镜头缓慢拉开（像高端品牌片的片名“散开”），每个鼓点再额外撑开一下；靠按列切开文字、按到中心的距离向两侧推开实现。",
  "when": "奢侈品/香水/时尚/电影片名、慢节奏的品牌落版、强调一个单词。",
  "avoid": "文字压在复杂画面上（背景也会被分列推开）；中文与紧排的字可能在笔画中间被切开（调 columns 接近字数）。",
  "params": {
    "columns": { "type": "float", "default": 24, "min": 4, "max": 80, "label": "切列数（越多越细）" },
    "spread": { "type": "float", "default": 0.12, "min": 0, "max": 0.5, "label": "镜头内总扩张量" },
    "kick": { "type": "float", "default": 0, "min": 0, "max": 0.1, "label": "鼓点撑开（通常由节拍驱动）" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "扩张中心 X" },
    "fill": { "type": "color", "default": "#0d0d0f", "label": "列缝底色" }
  },
  "bindings": { "kick": { "to": "kick", "amount": 0.025 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：片名字距动画", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（AE 文字动画的 Tracking 属性）：字距从紧到松慢慢打开，字形本身不变，只是字与字之间的空隙变大；
// 中心的字基本不动，越外侧的字移得越远。这里把画面按列切开，每列按到中心的距离向外平移——列宽≈字宽时就是字距动画。

vec4 effect(vec2 uv) {
  // ① 扩张量：随镜头进度缓出增长 + 鼓点额外撑开（kick 挂 kick，单位：画面宽）
  float e = spread * (1. - pow(1. - uProgress, 2.)) + kick;
  // ② 反查：显示点 x 属于哪一列？第 i 列的中心被推到 c_i + (c_i - 0.5)*e。用列中心的公式反解：
  //    显示坐标 x = cx + (x0 - cx) * (1 + e) 对列中心成立，列内保持原宽 → 先求原始列号再验证是否落在该列移动后的范围内。
  float w = 1. / columns;
  float x0guess = centerX + (uv.x - centerX) / (1. + e);      // 若整体均匀放大时对应的原坐标
  float col = floor(x0guess / w);
  vec3 c = fill;
  for (int k = -1; k <= 1; k++) {
    float ci = (col + float(k) + .5) * w;                        // 原列中心
    float di = centerX + (ci - centerX) * (1. + e);              // 推开后的列中心
    float lx = uv.x - di;                                        // 相对列中心的位置
    if (abs(lx) <= w * .5) { c = srcTex(vec2(ci + lx, uv.y)).rgb; }
  }
  return vec4(c, 1.);
}
