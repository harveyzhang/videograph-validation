/*@effect
{
  "id": "pixel-sort-sweep",
  "name": "像素排序扫过",
  "kind": "transition",
  "category": "转场",
  "tags": ["pixel sort", "glitch art", "databend", "streaks", "digital", "像素排序", "故障艺术", "拉丝", "数字"],
  "summary": "一道竖直的“排序前沿”从左扫到右：前沿附近的像素按亮度被拉成长长的水平色丝（像像素排序的故障艺术），前沿扫过后露出下一个镜头。",
  "when": "故障艺术/电子乐/实验影像、科技与数据、潮流与时尚的段落衔接。",
  "avoid": "温暖手作与写实叙事。时长建议 0.5–1 秒。",
  "params": {
    "smear": { "type": "float", "default": 0.25, "min": 0.02, "max": 0.6, "label": "拉丝长度" },
    "threshold": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "参与排序的亮度门槛" },
    "rows": { "type": "float", "default": 120, "min": 20, "max": 400, "label": "行密度" }
  },
  "bindings": {},
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：故障艺术", "note": "按思路自写；近似的像素排序观感（着色器无法真排序，用按亮度的定向拉丝近似）" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中（像素排序 glitch art）：程序把每一行里亮度超过门槛的一段像素按亮度重新排序，结果是一条条从亮到暗渐变的水平色丝。
// 着色器无法跨像素排序，这里用近似：前沿附近，每个像素向左取一段距离（距离由该行该段的亮度决定）的颜色，形成“被拉过来”的色丝。

vec4 transition(vec2 uv) {
  float p = progress;
  float front = p * 1.3 - .15;
  // ① 每行的随机延迟，让前沿是锯齿状的
  float row = floor(uv.y * rows);
  float jag = (fxHash(vec2(row, 3.)) - .5) * .12;
  float x = uv.x - (front + jag);
  if (x > smear) return vec4(getFromColor(uv).rgb, 1.);  // 前沿右侧：还是旧画面
  if (x < 0.) {
    // 前沿左侧：新画面，紧贴前沿的一小段仍带残留拉丝
    float t = clamp(-x / .06, 0., 1.);
    vec3 b = getToColor(uv).rgb;
    vec3 tail = getToColor(vec2(front + jag, uv.y)).rgb;
    return vec4(mix(tail, b, t), 1.);
  }
  // ② 前沿与右侧 smear 之间：旧画面的像素被拉成色丝——向右取“源”位置，亮的拉得更远（排序后亮的聚在一端）
  vec3 s0 = getFromColor(uv).rgb;
  float l = fxLuma(s0);
  float k = step(threshold, l);
  float pull = x / smear;                                // 0 在前沿处，1 在拉丝末端
  vec2 src = vec2(uv.x + (1. - pull) * smear * (.3 + l) * k, uv.y);
  vec3 c = getFromColor(src).rgb;
  // 拉丝内部按亮度渐变（模拟排序结果）
  c = mix(c, c * (1. + (1. - pull) * .4), k);
  return vec4(c, 1.);
}
