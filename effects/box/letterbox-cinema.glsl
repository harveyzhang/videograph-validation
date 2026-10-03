/*@effect
{
  "id": "letterbox-cinema",
  "name": "电影遮幅",
  "kind": "post",
  "category": "画面版式",
  "tags": ["letterbox", "cinemascope", "2.39", "black bars", "widescreen", "电影感", "遮幅", "黑边", "宽银幕"],
  "summary": "上下黑边以缓动推入，把画面裁成 2.39:1 宽银幕比例（比例可调）；画面略微压暗四角、提一点反差。鼓点时黑边轻轻一收一放。",
  "when": "任何想要“电影感”的段落、预告片、叙事与情绪高潮、片头片尾。",
  "avoid": "画面上下边缘有重要内容（字幕、Logo）时；竖屏发布的内容。",
  "params": {
    "aspect": { "type": "float", "default": 2.39, "min": 1.85, "max": 3.5, "label": "目标画幅比（宽/高）" },
    "inEnd": { "type": "float", "default": 0.15, "min": 0, "max": 0.8, "label": "黑边推入完成于镜头进度（0 = 一开始就在）" },
    "breathe": { "type": "float", "default": 0, "min": 0, "max": 0.03, "label": "鼓点收放（通常由节拍驱动）" },
    "barColor": { "type": "color", "default": "#000000", "label": "遮幅颜色" },
    "grade": { "type": "float", "default": 0.3, "min": 0, "max": 1, "label": "电影感调色（反差 + 暗角）" }
  },
  "bindings": { "breathe": { "to": "kick", "amount": 0.008 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：电影感画幅", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：宽银幕电影（2.39:1）在 16:9 屏幕上播放时，上下会留出黑边（letterbox）；
// 这种比例本身就让人联想到电影，所以短视频常用“加黑边”制造电影感，配合略高的反差与暗角。

vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;
  // ① 黑边高度：16:9 画面要变成 aspect 比例，上下各需遮掉 (1 - (W/H)/aspect)/2
  float frameA = uRes.x / uRes.y;
  float bar = max(0., (1. - frameA / aspect) * .5);
  // ② 推入动画（强缓出）+ 鼓点收放
  float t = inEnd <= 0. ? 1. : 1. - pow(1. - clamp(uProgress / inEnd, 0., 1.), 3.);
  float b = bar * t + breathe;
  // ③ 电影感调色：轻微 S 曲线 + 暗角（只作用于画面区域）
  c = mix(c, c * c * (3. - 2. * c), grade * .6);
  vec2 d = (uv - .5) * vec2(frameA, 1.);
  c *= 1. - grade * .35 * smoothstep(.4, 1.1, length(d));
  // ④ 遮幅（边缘 1 像素抗锯齿）
  float px = 1. / uRes.y;
  float m = smoothstep(b - px, b, uv.y) * smoothstep(b - px, b, 1. - uv.y);
  return vec4(mix(barColor, c, m), 1.);
}
