/*@effect
{
  "id": "palette-dither-8bit",
  "name": "8 位调色板抖动",
  "kind": "post",
  "category": "复古与数字",
  "tags": ["8-bit", "palette", "dither", "pico-8", "retro computer", "调色板", "抖动", "复古电脑"],
  "summary": "只能用 16 种固定颜色的老电脑画面：每个像素在调色板里找最接近的两色，用棋盘/网格抖动混出中间色，画面带着复古电脑的配色；鼓点时调色板轮换一格。",
  "when": "复古游戏与电脑题材、像素艺术风 MV、可爱/怀旧、科技史回顾。",
  "avoid": "需要准确肤色/品牌色的镜头；与 pixel-art 和 gameboy 风格接近，选一个就够（这个的特点是固定 16 色调色板 + 双色抖动）。",
  "params": {
    "pixel": { "type": "float", "default": 3, "min": 1, "max": 8, "label": "像素放大倍数" },
    "dither": { "type": "float", "default": 0.8, "min": 0, "max": 1, "label": "抖动强度" },
    "cycle": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "调色板轮换" },
    "contrast": { "type": "float", "default": 1.1, "min": 0.6, "max": 1.8, "label": "反差" }
  },
  "bindings": { "cycle": { "to": "bar", "amount": 0.5 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/pixel-rpg 与 microgame：复古像素观感", "note": "只参考风格名称与观感描述，代码为本项目自写；调色板为本项目自选的 16 色" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：80 年代的电脑和掌机显存很小，每个像素只能存一个“调色板编号”，屏幕只能同时显示 16 种固定颜色。
// 美术要画中间色，就让两种颜色按棋盘/网格交替排列（抖动），人眼在远处把它们混成一种颜色。
// 和 pixel-art（按通道均匀量化）不同：这里是固定的 16 色表，所以颜色有那个年代的“味道”。

// 本项目自选的 16 色（暖冷各半，从黑到白）
vec3 palColor(int i) {
  vec3 p[16] = vec3[16](
    vec3(.07, .06, .1), vec3(.18, .14, .3), vec3(.42, .16, .32), vec3(.12, .32, .38),
    vec3(.55, .3, .2), vec3(.36, .36, .4), vec3(.62, .62, .66), vec3(.96, .94, .9),
    vec3(.92, .2, .3), vec3(.98, .58, .2), vec3(.98, .88, .3), vec3(.3, .78, .32),
    vec3(.2, .5, .9), vec3(.48, .42, .7), vec3(.98, .55, .62), vec3(.98, .8, .66));
  return p[i];
}

vec4 effect(vec2 uv) {
  // ① 低分辨率：老电脑的像素很大——按 pixel 倍放大取样。
  vec2 cell = floor(uv * uRes / pixel);
  vec3 c = srcTex((cell + .5) * pixel / uRes).rgb;
  c = clamp((c - .5) * contrast + .5, 0., 1.);

  // ② 找最接近的两种调色板颜色（按人眼加权的颜色距离）：一个主色、一个次色。
  //    cycle 挂小节：每小节开头调色板索引轮换（像老游戏的“调色板循环”动画），然后回到原位。
  int shift = int(floor(cycle * 3.));
  float d1 = 1e3, d2 = 1e3;
  vec3 p1 = vec3(0.), p2 = vec3(0.);
  for (int i = 0; i < 16; i++) {
    vec3 pc = palColor(int(mod(float(i + shift), 16.)));
    vec3 diff = c - pc;
    float d = dot(diff * diff, vec3(.3, .59, .11));
    if (d < d1) { d2 = d1; p2 = p1; d1 = d; p1 = pc; }
    else if (d < d2) { d2 = d; p2 = pc; }
  }

  // ③ 抖动：原色在两色之间的位置 = 次色应占的比例；与 4×4 Bayer 阈值比较决定这个像素画哪一色。
  float ratio = sqrt(d1) / (sqrt(d1) + sqrt(d2) + 1e-5);
  float th = fxBayer4(cell);
  vec3 col = ratio * dither > th * .5 + .001 ? p2 : p1;

  // ④ 输出：像素边缘保持硬边（老显示器没有平滑），不做任何模糊。
  return vec4(col, 1.);
}
