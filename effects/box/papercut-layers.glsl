/*@effect
{
  "id": "papercut-layers",
  "name": "剪纸层叠",
  "kind": "post",
  "category": "手绘与绘画",
  "tags": ["papercut", "paper craft", "layered paper", "collage", "shadow box", "剪纸", "纸雕", "层叠纸艺"],
  "summary": "画面按明暗剪成 4 层彩色卡纸叠起来：边缘是手剪的微小起伏，每层在下层投下柔和阴影，切口露出白色纸芯；鼓点时纸层被托高、阴影变长。",
  "when": "童话、节日贺卡、品牌故事、手作/环保主题、温暖可爱的解说片；风景与剪影最好看。",
  "avoid": "需要细节与真实颜色的镜头；画面明暗层次很少（只剩 1–2 层，会显空）。",
  "params": {
    "c1": { "type": "color", "default": "#22314f", "label": "最底层（暗部）" },
    "c2": { "type": "color", "default": "#d0564a", "label": "第二层" },
    "c3": { "type": "color", "default": "#e9a94c", "label": "第三层" },
    "c4": { "type": "color", "default": "#f3e7cf", "label": "最上层（亮部）" },
    "lift": { "type": "float", "default": 5, "min": 0, "max": 16, "label": "纸层高度（阴影长度，像素）" },
    "rough": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "手剪起伏" }
  },
  "bindings": { "lift": { "to": "kick", "amount": 4 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/papercut-red 与 paper-popup", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：层叠纸艺是把几张不同颜色的卡纸各剪出一个形状，按从后到前的顺序用泡沫胶垫高叠起来；
// 每一层都会在它下面那层投下阴影（垫得越高阴影越长越虚），剪刀/刻刀留下的边缘有微小起伏，
// 有色卡纸的切口会露出白色的纸芯。和 silkscreen-poster（平印色块）不同：这里有真实的层次和阴影。

// 某位置属于第几层纸（0 = 最底层，3 = 最上层）：亮度分 4 层，边缘用噪声扰动成“手剪”的起伏
float layerAt(vec2 uv) {
  float l = fxLuma(srcTex(uv).rgb);
  l += (fxNoise(uv * uRes * .05) - .5) * .08 * rough;
  return floor(clamp(l, 0., .999) * 4.);
}

vec3 paperColor(float k) { return k < .5 ? c1 : k < 1.5 ? c2 : k < 2.5 ? c3 : c4; }

vec4 effect(vec2 uv) {
  // ① 剪纸：当前像素是哪一层纸。
  float k = layerAt(uv);
  vec3 col = paperColor(k);

  // ② 投影：光从左上方来，阴影落在右下方。往光源方向找（3 个距离 = 3 次采样），
  //    如果那里的纸比当前层高，说明有一层纸垫在我上方投下阴影；高出越多层、离得越近，阴影越深。
  //    lift 挂鼓点：鼓点那一下纸层像被托起来，阴影瞬间拉长再回落。
  vec2 toLight = normalize(vec2(-1., 1.)) / uRes;
  float shade = 0.;
  for (int i = 1; i <= 3; i++) {
    float d = lift * float(i) / 3.;
    float kk = layerAt(uv + toLight * d);
    shade = max(shade, clamp(kk - k, 0., 2.) * (1.15 - float(i) * .25));
  }
  col *= 1. - clamp(shade, 0., 1.) * .38;

  // ③ 白色纸芯：当前层的边缘（朝光一侧的下一像素是更低的层）露出一条约 1.5 像素的白芯。
  float kEdge = layerAt(uv - toLight * 1.5);
  col = mix(col, vec3(.97, .95, .9), step(kEdge + .5, k) * .7);

  // ④ 卡纸质感：纸纤维 + 每层轻微不同的纹理方向，静止不动。
  vec2 p = uv * uRes;
  col *= .95 + .05 * fxNoise(p * .6 + k * 13.);
  return vec4(col, 1.);
}
