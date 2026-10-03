/*@effect
{
  "id": "picture-frame",
  "name": "画框装裱",
  "kind": "post",
  "category": "画面版式",
  "tags": ["frame", "gallery", "museum", "gold frame", "mat board", "画框", "装裱", "美术馆", "金框"],
  "summary": "画面被装进一个带浅色卡纸衬边的画框里，挂在一面墙上：画框有立体斜面和木纹/金属光泽（可选金框或黑框），墙面有柔和的射灯光斑；鼓点时射灯微微一亮。",
  "when": "艺术/美术馆/拍卖题材、回忆与家庭照片、复古优雅的品牌、“作品展示”的镜头。",
  "avoid": "需要全屏冲击力的镜头。",
  "params": {
    "size": { "type": "float", "default": 0.62, "min": 0.3, "max": 0.9, "label": "画框大小（画面高度比例）" },
    "mat": { "type": "float", "default": 0.05, "min": 0, "max": 0.15, "label": "卡纸衬边宽度" },
    "frameW": { "type": "float", "default": 0.045, "min": 0.01, "max": 0.12, "label": "画框宽度" },
    "gold": { "type": "bool", "default": true, "label": "金框（关 = 黑木框）" },
    "wall": { "type": "color", "default": "#5a4a42", "label": "墙面颜色" },
    "spot": { "type": "float", "default": 0.2, "min": 0, "max": 1, "label": "射灯（通常由节拍驱动）" }
  },
  "bindings": { "spot": { "to": "kick", "amount": 0.15 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/art-deco：装饰画框", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：装裱一幅画由内到外是：画心 → 卡纸衬边（让画“透气”，内沿有一圈斜切的白边）→ 画框（有斜面，受光一侧亮）
// → 挂在墙上，射灯从上方打下一个椭圆光斑，画框在墙上投出阴影。

vec4 effect(vec2 uv) {
  float A = uRes.x / uRes.y;
  vec2 p = (uv - .5) * vec2(A, 1.);
  vec2 img = vec2(size * .5 * 1.33, size * .5);             // 画心 4:3
  vec2 matB = img + mat;
  vec2 frB = matB + frameW;
  // ① 墙面 + 射灯光斑（上方椭圆）
  vec3 c = wall * (.55 + .6 * exp(-dot((p - vec2(0., .25)) * vec2(.7, 1.2), (p - vec2(0., .25)) * vec2(.7, 1.2)) * 3.) * (1. + spot));
  c *= .95 + .05 * fxNoise(uv * uRes * .3);
  // ② 画框投影（右下）
  vec2 q = abs(p - vec2(.012, -.018)) - frB;
  float sh = length(max(q, 0.));
  c *= 1. - .45 * exp(-sh * 40.) ;
  vec2 ap = abs(p);
  // ③ 画框：斜面受光（上/左亮，下/右暗），金框带横向纹理光泽
  if (ap.x < frB.x && ap.y < frB.y) {
    vec3 fc = gold ? vec3(.78, .58, .25) : vec3(.12, .1, .09);
    float lit = (p.y > 0. && ap.y - matB.y > ap.x - matB.x) ? 1.25 : (p.x < 0. && ap.x - matB.x > ap.y - matB.y) ? 1.1 : (p.y < 0. && ap.y - matB.y > ap.x - matB.x) ? .65 : .8;
    float grain = gold ? .85 + .3 * sin((p.x + p.y) * 400. + fxNoise(p * 40.) * 6.) : .9 + .15 * fxNoise(p * vec2(300., 20.));
    c = fc * lit * grain;
  }
  // ④ 卡纸衬边：米白，内沿一圈斜切白边
  if (ap.x < matB.x && ap.y < matB.y) {
    c = vec3(.93, .91, .86);
    float bevel = step(max(ap.x - img.x, ap.y - img.y), .006);
    c = mix(c, vec3(1.), bevel * .6);
  }
  // ⑤ 画心：原画面
  if (ap.x < img.x && ap.y < img.y) c = srcTex(p / (img * 2.) + .5).rgb;
  return vec4(c, 1.);
}
