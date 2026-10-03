/*@effect
{
  "id": "low-poly-facets",
  "name": "低多边形三角化",
  "kind": "post",
  "category": "几何与图形",
  "tags": ["low poly", "triangulate", "facets", "polygon", "geometric", "三角化", "低多边形"],
  "summary": "画面被切成一片片随机三角形，每片填一种平均色并带一点面光明暗，像低多边形插画；鼓点时顶点被震散再归位。",
  "when": "科技/数据主题、游戏感、几何风宣传片、片头标题背景；风景与大色块画面最好看。",
  "avoid": "小字和细节多的画面（三角形会把字吃掉）；人脸特写会显得生硬，调小三角形。",
  "params": {
    "size": { "type": "float", "default": 34, "min": 8, "max": 120, "label": "三角形大小（像素）" },
    "jitter": { "type": "float", "default": 0.35, "min": 0, "max": 0.45, "label": "顶点随机度" },
    "shade": { "type": "float", "default": 0.12, "min": 0, "max": 0.4, "label": "面光明暗" },
    "edge": { "type": "float", "default": 0.25, "min": 0, "max": 1, "label": "棱线可见度" }
  },
  "bindings": { "jitter": { "to": "kick", "amount": 0.1 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/lowpoly-island", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：低多边形插画是设计师在照片上撒一批顶点、连成三角网，每个三角形取区域平均色平涂；
// 3D 软件里同样的网格被灯光照着，朝向不同的面有轻微明暗差，这就是“切面感”的来源。

// 顶点：规则网格 + 每个格点按哈希偏移（jitter 是偏移量占格宽比例）
vec2 vertexAt(vec2 id) {
  return id + (vec2(fxHash(id), fxHash(id + 31.7)) - .5) * 2. * jitter;
}

// 点 p 是否在三角形 abc 内（重心坐标全非负），返回到最近一条边的距离（重心坐标最小值）
float inTri(vec2 p, vec2 a, vec2 b, vec2 c) {
  vec2 v0 = b - a, v1 = c - a, v2 = p - a;
  float d = v0.x * v1.y - v1.x * v0.y;
  float u = (v2.x * v1.y - v1.x * v2.y) / d;
  float v = (v0.x * v2.y - v2.x * v0.y) / d;
  return min(min(u, v), 1. - u - v);
}

vec4 effect(vec2 uv) {
  // ① 撒点连网：按像素尺寸建格子，每个格子有 4 个（偏移过的）角点，用对角线切成两个三角形。
  //    对角线方向按格子哈希随机选，避免整齐的“斜纹”。jitter 挂鼓点：鼓点时顶点震散，网面一抖。
  vec2 g = uv * uRes / size;
  vec2 base = floor(g);

  // ② 找当前像素所在的三角形：顶点偏移后，像素可能落进相邻格子的三角形，所以检查 3×3 个格子共 18 个三角
  //    （纯算术，不采样），取“最在里面”的那一个（重心坐标最小值最大）——三角网严丝合缝，没有接缝。
  //    flip：沿 b–c 对角线切（三角 abc / bdc）；否则沿 a–d 切（三角 adc / abd）。
  vec2 A = vec2(0.), B = vec2(0.), C = vec2(0.);
  float edgeD = -1e3;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = base + vec2(float(i), float(j));
      vec2 a = vertexAt(id), b = vertexAt(id + vec2(1., 0.)), c = vertexAt(id + vec2(0., 1.)), d = vertexAt(id + vec2(1., 1.));
      bool flip = fxHash(id + 9.1) > .5;
      vec2 t0a = a, t0b = flip ? b : d, t0c = c;
      vec2 t1a = flip ? b : a, t1b = flip ? d : b, t1c = flip ? c : d;
      float e0 = inTri(g, t0a, t0b, t0c), e1 = inTri(g, t1a, t1b, t1c);
      if (e0 > edgeD) { edgeD = e0; A = t0a; B = t0b; C = t0c; }
      if (e1 > edgeD) { edgeD = e1; A = t1a; B = t1b; C = t1c; }
    }
  }

  // ③ 平涂取色：在三角形重心和三个顶点向内 1/3 处取 4 次样求平均——近似“区域平均色”。
  vec2 cen = (A + B + C) / 3.;
  vec2 toUv = size / uRes;
  vec3 col = srcTex(cen * toUv).rgb * .4
           + srcTex(mix(cen, A, .55) * toUv).rgb * .2
           + srcTex(mix(cen, B, .55) * toUv).rgb * .2
           + srcTex(mix(cen, C, .55) * toUv).rgb * .2;

  // ④ 面光：把三角形看成微微倾斜的面，法线由三个顶点的“高度”（取顶点处亮度）决定，被左上方的光照亮。
  float hA = fxLuma(srcTex(A * toUv).rgb), hB = fxLuma(srcTex(B * toUv).rgb), hC = fxLuma(srcTex(C * toUv).rgb);
  vec3 n = normalize(cross(vec3(B - A, (hB - hA) * 1.5), vec3(C - A, (hC - hA) * 1.5)));
  n *= sign(n.z);
  float light = dot(n, normalize(vec3(-.5, .6, .8)));
  col *= 1. + shade * (light - .7) * 3. + shade * (fxHash(cen) - .5);

  // ⑤ 棱线：靠近三角形边的地方提亮一点点（面与面交界处的高光），宽度约 1 像素。
  float px = 1. / size;
  col = mix(col, col * 1.25 + .04, edge * smoothstep(px * 1.5, 0., edgeD));
  return vec4(col, 1.);
}
