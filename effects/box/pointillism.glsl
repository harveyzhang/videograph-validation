/*@effect
{
  "id": "pointillism",
  "name": "点彩",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["pointillism", "seurat", "neo-impressionism", "dots", "divisionism", "点彩", "新印象派", "修拉"],
  "summary": "画面由一颗颗纯色的短笔点堆成：颜色被提纯，相邻处故意点上邻近色和补色，近看是彩点、远看在眼里混成画面；鼓点时笔点涨大。",
  "when": "公园/海滨/阳光户外、艺术与博物馆题材、梦幻怀旧、节日与花卉；明亮的风景最好看。",
  "avoid": "暗部为主的画面（点彩靠亮色堆叠）；需要清楚文字与细节的镜头。",
  "params": {
    "spacing": { "type": "float", "default": 7, "min": 3, "max": 20, "label": "笔点间距（像素）" },
    "radius": { "type": "float", "default": 0.74, "min": 0.3, "max": 1, "label": "笔点大小" },
    "pure": { "type": "float", "default": 0.6, "min": 0, "max": 1, "label": "色彩提纯" },
    "contrastHue": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "邻近色/补色比例" },
    "canvas": { "type": "color", "default": "#f3ecdc", "label": "画布色" }
  },
  "bindings": { "radius": { "to": "kick", "amount": 0.1 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/impasto 与 watercolor：绘画类风格描述", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：修拉的点彩不在调色板上调色，而是把纯色一点一点并排点在画布上，让观众的眼睛完成混色（“视觉混合”）；
// 为了让颜色更“振动”，他在一个颜色旁边点上它的邻近色，暗部点上补色；笔点是短短的、方向大致一致的小椭圆。

// 绕灰轴转色相（Rodrigues 旋转），保持亮度大致不变
vec3 hueTurn(vec3 c, float a) {
  vec3 k = vec3(.57735);
  return c * cos(a) + cross(k, c) * sin(a) + k * dot(k, c) * (1. - cos(a));
}

vec4 effect(vec2 uv) {
  vec2 p = uv * uRes / spacing;
  vec2 ip = floor(p);

  // ① 点笔：每个格子一笔，位置随机；当前像素检查 3×3 个邻格的笔点（9 次采样），
  //    每笔有随机“先后”，后点的盖住先点的（颜料是不透明的）。
  vec3 col = canvas;
  float top = -1.;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = ip + vec2(float(i), float(j));
      vec2 ctr = id + .5 + (vec2(fxHash(id), fxHash(id + 4.7)) - .5) * .8;

      // ② 笔点形状：方向大致一致（约 20°）的短椭圆。radius 挂鼓点：鼓点时笔点涨大、更密地盖住画布。
      vec2 d = (p - ctr) * mat2(.94, -.34, .34, .94);
      d.x *= .7;
      float r = radius * (.75 + .5 * fxHash(id + 2.2));
      float m = smoothstep(r, r - .12, length(d));
      float order = fxHash(id + 9.3);
      if (m > .5 && order > top) {
        top = order;
        // ③ 选色：笔点中心处的颜色，提纯（拉高饱和度、轻微提亮）。
        vec3 s = srcTex(ctr * spacing / uRes).rgb;
        float l = fxLuma(s);
        s = clamp(mix(vec3(l), s, 1. + pure * 1.3) + pure * .06, 0., 1.);
        // ④ 分色：一部分笔点换成邻近色（色相 ±35°），暗处一部分换成补色的暗调——视觉混合的“振动”。
        float h = fxHash(id + 6.1);
        if (h < contrastHue * .5) s = hueTurn(s, .6);
        else if (h < contrastHue) s = hueTurn(s, -.6);
        if (l < .35 && fxHash(id + 8.8) < contrastHue * .6) s = hueTurn(s, 3.1416) * .7;
        col = mix(col, s, m);
      }
    }
  }

  // ⑤ 颜料厚度：每个笔点上有一点点明暗起伏（笔刷带起的颜料），画布有织纹。
  vec2 q = uv * uRes;
  col *= .94 + .06 * fxNoise(q * .5);
  col *= top < 0. ? .97 + .03 * sin(q.x * 1.6) * sin(q.y * 1.6) : 1.;
  return vec4(col, 1.);
}
