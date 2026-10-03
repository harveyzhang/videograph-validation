/*@effect
{
  "id": "lcd-subpixel",
  "name": "LCD 子像素特写",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["lcd", "subpixel", "rgb stripe", "macro screen", "display", "子像素", "液晶屏", "微距"],
  "summary": "像用微距镜头拍液晶屏：每个像素拆成竖排的红绿蓝三条子像素，之间是黑色栅格，画面有轻微的摩尔纹与屏幕发光；鼓点时背光一亮。",
  "when": "科技/数码产品、“画面在屏幕里”的套层、赛博与网络题材、数据与界面展示。",
  "avoid": "需要看清细节的镜头（子像素会吃掉细节）；与 crt-monitor 叠用（两种屏幕结构打架）。",
  "params": {
    "pixel": { "type": "float", "default": 12, "min": 4, "max": 30, "label": "像素大小（屏幕像素 → 输出像素）" },
    "grid": { "type": "float", "default": 0.18, "min": 0, "max": 0.45, "label": "黑色栅格宽度" },
    "backlight": { "type": "float", "default": 1.25, "min": 0.6, "max": 2.5, "label": "背光亮度" },
    "glow": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "发光扩散" }
  },
  "bindings": { "backlight": { "to": "kick", "amount": 0.35 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：屏幕质感/屏中屏", "note": "按思路自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：液晶屏的每个像素由三条竖着并排的子像素组成，分别盖着红、绿、蓝滤色片；背光从后面照过来，
// 液晶只控制每条子像素透多少光。子像素之间有不透光的黑色矩阵（black matrix），近看就是一格格彩色竖条。
// 和 crt-monitor（荧光点 + 扫描线 + 弯曲玻璃）不同：LCD 是平的、方格的、没有扫描线。

vec4 effect(vec2 uv) {
  // ① 屏幕像素：把画面按 pixel 大小分格，每格取一个颜色（这是屏幕在显示的那个像素）。
  vec2 g = uv * uRes / pixel;
  vec2 id = floor(g);
  vec2 f = fract(g);
  vec3 c = srcTex((id + .5) * pixel / uRes).rgb;

  // ② 子像素：一个像素横向分成 R、G、B 三条，每条只透自己那个通道的光。
  float sub = f.x * 3.;
  float k = floor(sub);
  float fs = fract(sub);
  vec3 mask = k < .5 ? vec3(1., 0., 0.) : k < 1.5 ? vec3(0., 1., 0.) : vec3(0., 0., 1.);

  // ③ 黑色矩阵：子像素之间的竖向间隔 + 像素之间的横向间隔（边缘柔和一点，像透过镜头看）。
  float soft = 1.5 / pixel * 3.;   // 约 1.5 输出像素的柔边
  float vx = smoothstep(grid * .5, grid * .5 + soft, fs) * smoothstep(grid * .5, grid * .5 + soft, 1. - fs);
  float hy = smoothstep(grid * .35, grid * .35 + soft / 3., f.y) * smoothstep(grid * .35, grid * .35 + soft / 3., 1. - f.y);
  float open = vx * hy;

  // ④ 背光透过液晶：子像素亮度 = 该通道值 × 背光；滤色片不完全纯（各通道有一点串色）。
  //    backlight 挂鼓点：鼓点那一下背光一亮。
  vec3 filterCol = mix(mask, vec3(1.), .08);
  vec3 lit = c * filterCol * backlight * open;

  // ⑤ 发光扩散：镜头会让亮的子像素晕开一点，近看屏幕整体泛出它所显示的颜色（相邻像素颜色的平均，4 次采样）。
  vec3 halo = (srcTex((id + vec2(1.5, .5)) * pixel / uRes).rgb + srcTex((id + vec2(-.5, .5)) * pixel / uRes).rgb
             + srcTex((id + vec2(.5, 1.5)) * pixel / uRes).rgb + srcTex((id + vec2(.5, -.5)) * pixel / uRes).rgb + c * 4.) / 8.;
  //    每条子像素只透一个通道，面积上只有 1/3 → 亮度乘 3 补回（微距照片里屏幕看起来依然明亮饱和）。
  vec3 col = lit * 2.6 + halo * glow * .3 * backlight;
  return vec4(col, 1.);
}
