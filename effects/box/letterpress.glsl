/*@effect
{
  "id": "letterpress",
  "name": "凸版压印",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["letterpress", "deboss", "relief print", "cotton paper", "凸版", "活版印刷", "压印"],
  "summary": "单色油墨被铅字/凸版压进厚棉纸：印纹凹陷、边缘一圈墨积得更深，墨面里有没吃满墨的斑驳白点，纸面有棉纤维纹理。",
  "when": "婚礼请柬感、手工品牌、书店/咖啡馆、文艺标题卡、复古商业海报；文字与 Logo 镜头尤其好看。",
  "avoid": "需要连续灰阶的照片（凸版只有“有墨/无墨”两态）；画面暗部大面积时会变成满版墨块。",
  "params": {
    "ink": { "type": "color", "default": "#1d3b6e", "label": "油墨颜色" },
    "paper": { "type": "color", "default": "#f3eee2", "label": "棉纸颜色" },
    "threshold": { "type": "float", "default": 0.5, "min": 0.1, "max": 0.9, "label": "上墨阈值" },
    "bite": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "压印深度" },
    "starve": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "缺墨斑驳" }
  },
  "bindings": { "bite": { "to": "kick", "amount": 0.6 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/risograph 与 woodcut：印刷工艺描述", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：凸版印刷是把凸起的版面（铅字/树脂版）滚上油墨，再用很大的压力压到厚棉纸上。
// 版面把纸压出凹痕（光从左上照来时，凹痕的上沿有阴影、下沿有亮边）；油墨被挤向印纹边缘，所以边缘比中间深；
// 墨辊供墨不均时，印纹中间会出现没吃到墨的细小白点（“缺墨”），这是凸版最有味道的瑕疵。

float plate(vec2 uv) {
  // 版面：亮度低于阈值的地方是凸起的印纹（1 = 有版）。用 smoothstep 留 1–2 像素的软边，压痕才有坡度。
  return smoothstep(threshold + .04, threshold - .04, fxLuma(srcTex(uv).rgb));
}

vec4 effect(vec2 uv) {
  vec2 px = 1. / uRes;

  // ① 制版：原图按阈值变成单色印纹（1 次采样），再在四个方向各取一次，得到印纹的坡度（共 5 次采样）。
  float m = plate(uv);
  float mL = plate(uv - vec2(px.x * 1.5, 0.)), mR = plate(uv + vec2(px.x * 1.5, 0.));
  float mD = plate(uv - vec2(0., px.y * 1.5)), mU = plate(uv + vec2(0., px.y * 1.5));
  vec2 slope = vec2(mR - mL, mU - mD);

  // ② 压印：纸被压下去的凹陷 = 印纹本身。光从左上来：坡面朝向光的一侧亮、背光一侧暗。
  //    bite 挂鼓点：鼓点那一下像压印机“咚”地压了一下，凹凸更深。
  float relief = dot(slope, normalize(vec2(-1., 1.))) * bite;

  // ③ 挤墨：印纹边缘（坡度大处）积墨更多 → 更深；印纹中间按棉纸纤维的噪声“缺墨”露出纸白。
  float edgeInk = clamp(length(slope) * 1.2, 0., 1.);
  float fiber = fxNoise(uv * uRes * vec2(.35, .12)) * .6 + fxNoise(uv * uRes * .9) * .4;   // 横向拉长的棉纤维
  float starveMask = smoothstep(.55, .8, fiber) * starve;
  float coverage = m * (1. - starveMask * (1. - edgeInk)) ;

  // ④ 上墨：从纸色出发，油墨按覆盖率盖上去，边缘处再加深一点（积墨）。
  vec3 c = mix(paper, ink, coverage * .92);
  c = mix(c, ink * .7, edgeInk * m * .35);

  // ⑤ 纸面：棉纸的纤维纹理（静止，不闪）+ 压印的明暗（凹痕阴影/亮边）。
  c *= .96 + .04 * fiber;
  c += relief * .12;
  return vec4(c, 1.);
}
