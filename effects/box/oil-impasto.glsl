/*@effect
{
  "id": "oil-impasto",
  "name": "油画厚涂",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": [
    "oil",
    "impasto",
    "painterly",
    "kuwahara",
    "油画"
  ],
  "summary": "Kuwahara 色块平滑 + 笔刷方向的明暗起伏，像厚涂油画。",
  "when": "艺术感、情绪浓烈的特写、古典气质。",
  "avoid": "小字与细线（会被抹平）。",
  "params": {
    "radius": {
      "type": "float",
      "default": 4,
      "min": 1,
      "max": 8,
      "label": "笔刷半径(px)"
    },
    "relief": {
      "type": "float",
      "default": 0.4,
      "min": 0,
      "max": 1,
      "label": "笔触起伏"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "lemo-opuscar-styles",
      "ref": "styles/impasto",
      "note": "只参考风格名称与观感描述，代码为本项目自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec2 px = radius / uRes;
  vec3 m[4]; float v[4];
  for (int k = 0; k < 4; k++) {
    vec2 dir = vec2(k == 1 || k == 3 ? 1. : -1., k >= 2 ? 1. : -1.);
    vec3 sum = vec3(0.), sq = vec3(0.);
    for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) { vec3 s = srcTex(uv + dir * vec2(float(i), float(j)) * px * .5).rgb; sum += s; sq += s * s; }
    m[k] = sum / 9.; vec3 var = sq / 9. - m[k] * m[k]; v[k] = var.r + var.g + var.b;
  }
  vec3 col = m[0]; float best = v[0];
  for (int k = 1; k < 4; k++) if (v[k] < best) { best = v[k]; col = m[k]; }
  float brush = fxNoise(fxRot(fxNoise(uv * 6.) * 3.) * uv * uRes * .25);
  col *= 1. + (brush - .5) * relief * .35;
  return vec4(col, 1.);
}
