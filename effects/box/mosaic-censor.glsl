/*@effect
{
  "id": "mosaic-censor",
  "name": "打码遮挡",
  "kind": "post",
  "category": "画面版式",
  "tags": ["censor", "pixelate", "mosaic", "blur box", "privacy", "打码", "马赛克", "遮挡", "隐私"],
  "summary": "在画面中指定的矩形或圆形区域打上马赛克（或模糊、或黑条），区域边缘柔和，可做成综艺式的“哔——”打码效果；鼓点时马赛克格子轻微抖动。",
  "when": "综艺搞笑打码、隐私遮挡（人脸/车牌/品牌）、“不可说”的幽默梗、悬疑中隐藏信息。",
  "avoid": "需要精确跟踪移动物体时（区域是固定位置，物体移动需要逐镜头调整位置参数）。",
  "params": {
    "mode": { "type": "float", "default": 0, "min": 0, "max": 2, "label": "方式：0 马赛克 / 1 模糊 / 2 黑条" },
    "centerX": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "区域中心 X" },
    "centerY": { "type": "float", "default": 0.55, "min": 0, "max": 1, "label": "区域中心 Y" },
    "sizeX": { "type": "float", "default": 0.18, "min": 0.02, "max": 1, "label": "区域半宽（画面高度比例）" },
    "sizeY": { "type": "float", "default": 0.22, "min": 0.02, "max": 1, "label": "区域半高（画面高度比例）" },
    "round": { "type": "bool", "default": true, "label": "椭圆区域（关 = 矩形）" },
    "block": { "type": "float", "default": 0.025, "min": 0.005, "max": 0.1, "label": "马赛克格子大小" },
    "jitter": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "鼓点抖动（通常由节拍驱动）" }
  },
  "bindings": { "jitter": { "to": "kick", "amount": 0.5 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：综艺打码", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：电视台给需要隐藏的区域“打码”——最常见的是马赛克（把区域降成大方块），其次是高斯模糊或一条黑条；
// 综艺节目也故意给不需要隐藏的东西打码来制造笑点。

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 d = (uv - vec2(centerX, centerY)) * asp / vec2(sizeX, sizeY);
  float inside = round ? smoothstep(1.05, .95, length(d)) : smoothstep(1.05, .95, max(abs(d.x), abs(d.y)));
  if (inside <= 0.) return vec4(src, 1.);
  int m = int(floor(mode + .5));
  vec3 c;
  if (m == 0) {
    // ① 马赛克：区域内按格子取中心色；鼓点时格子网格偏移半格（抖动）
    float bpx = block * uRes.y;
    vec2 off = vec2(step(.5, fxHash(vec2(floor(uTime * 8.), 1.))) * .5 * jitter);
    vec2 cell = floor(uv * uRes / bpx + off);
    c = srcTex((cell + .5 - off) * bpx / uRes).rgb;
  } else if (m == 1) {
    // ② 模糊：12 次环形采样
    vec3 acc = vec3(0.);
    for (int i = 0; i < 12; i++) { float a = float(i) * .5236; acc += srcTex(uv + vec2(cos(a), sin(a)) * block * (.5 + float(i % 3) * .5) * vec2(uRes.y / uRes.x, 1.)).rgb; }
    c = acc / 12.;
  } else {
    // ③ 黑条
    c = vec3(.02);
  }
  return vec4(mix(src, c, inside), 1.);
}
