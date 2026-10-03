/*@effect
{
  "id": "type-underline-draw",
  "name": "下划线生长",
  "kind": "post",
  "category": "文字与排版",
  "tags": ["text", "underline", "line draw", "emphasis", "editorial", "文字", "下划线", "线条生长", "强调"],
  "summary": "在每行文字下方自动画出一条下划线：线从左向右生长（强缓出），长度刚好覆盖这一行字；线条颜色可设，鼓点时线条加粗一下。",
  "when": "强调关键词、标题与副标题、讲解与知识类视频、杂志/简约风格排版。",
  "avoid": "竖排文字；字与字之间空隙很大（下划线会在空隙处断开）。",
  "params": {
    "inEnd": { "type": "float", "default": 0.35, "min": 0.05, "max": 0.9, "label": "画完于镜头进度" },
    "gap": { "type": "float", "default": 0.012, "min": 0, "max": 0.05, "label": "线与字的间距（画面高度比例）" },
    "thick": { "type": "float", "default": 0.006, "min": 0.002, "max": 0.03, "label": "线粗（通常由节拍驱动）" },
    "reach": { "type": "float", "default": 0.03, "min": 0.005, "max": 0.1, "label": "跨字间隙的距离（画面高度比例）" },
    "lineColor": { "type": "color", "default": "#ff4d12", "label": "线色" },
    "threshold": { "type": "float", "default": 0.45, "min": 0.05, "max": 0.95, "label": "文字亮度阈值" }
  },
  "bindings": { "thick": { "to": "kick", "amount": 0.004 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/swiss-motion：线条强调", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：设计师在字下面拉一条线强调，动态版本让线条像被笔划出来一样从左长到右。
// 实现：找“字的下沿再往下 gap”的那条细带，左右各借一次邻近的字把线连起来，再按镜头进度限制线的长度。

float inkAt(vec2 p) { return smoothstep(threshold - .08, threshold + .08, fxLuma(srcTex(p).rgb)); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  // ① 字的下沿：若当前像素上方 gap 处没有字、而再往上 gap+thick 处有字，这里就在“字底下方 gap、厚 thick”的线带里。
  //    左右各再查一次（间距 reach），让线跨过字与字之间的空隙连成一条（共 6 次采样）。
  float band = 0.;
  for (int i = -1; i <= 1; i++) {
    vec2 q = uv + vec2(float(i) * reach * uRes.y / uRes.x, 0.);
    band = max(band, inkAt(q + vec2(0., gap + thick)) * (1. - inkAt(q + vec2(0., gap * .5))));
  }
  band *= 1. - inkAt(uv);                                   // 线不画在字上
  // ② 生长：线从左到右，强缓出
  float t = 1. - pow(2., -10. * clamp(uProgress / inEnd, 0., 1.));
  float drawn = step(uv.x, t * 1.02);
  return vec4(mix(src, lineColor, band * drawn), 1.);
}
