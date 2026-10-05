/*@effect
{
  "id": "gen-bokeh-float",
  "name": "漂浮光斑",
  "kind": "post",
  "category": "生成层",
  "tags": ["bokeh", "floating lights", "particles", "dreamy", "christmas", "光斑", "漂浮", "梦幻", "圣诞"],
  "summary": "画面前景漂浮着大大小小的失焦光斑（圆形或六边形，带亮边），缓慢上浮并左右摇曳，颜色在暖金与粉之间；每一拍有一部分光斑亮一下。",
  "when": "节日/婚礼/梦幻/浪漫、产品广告的高级背景、抒情歌词、夜景。",
  "avoid": "需要看清细节的信息镜头（光斑会挡住，可调低 amount）。",
  "params": {
    "amount": { "type": "float", "default": 0.6, "min": 0, "max": 1.5, "label": "亮度" },
    "count": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "数量" },
    "size": { "type": "float", "default": 0.06, "min": 0.015, "max": 0.2, "label": "光斑大小（画面高度比例）" },
    "hexagon": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "六边形程度（光圈叶片）" },
    "colorA": { "type": "color", "default": "#ffd28a", "label": "颜色 A" },
    "colorB": { "type": "color", "default": "#ff8ab8", "label": "颜色 B" },
    "twinkle": { "type": "float", "default": 0, "min": 0, "max": 1, "label": "节拍闪亮（通常由节拍驱动）" }
  },
  "bindings": { "twinkle": { "to": "beat", "amount": 0.6 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：光斑前景", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：在镜头前很近的地方放一串小灯（或隔着彩灯拍），这些点光源完全失焦，变成大大的、半透明的光圈形状光斑；
// 光斑边缘比中间略亮（球差），形状由光圈叶片决定（圆或多边形）。和 bokeh-dream（把画面本身虚化）不同：这是叠加的前景光斑层。

float hexLen(vec2 p) { vec2 q = abs(p); return max(q.x * .866 + q.y * .5, q.y); }

vec4 effect(vec2 uv) {
  vec3 src = srcTex(uv).rgb;
  vec2 p = vec2(uv.x * uRes.x / uRes.y, uv.y);
  vec3 light = vec3(0.);
  // ① 两层（远小近大），每格一个光斑，缓慢上浮 + 摇曳；检查本格与下方一格
  for (int L = 0; L < 2; L++) {
    float cs = size * 2.6 * (1. + float(L) * .8);
    vec2 q = p / cs;
    q.y -= uTime * .03 * (1. + float(L)) / cs;
    for (int j = 0; j < 2; j++) for (int i = -1; i <= 1; i++) {
      vec2 id = floor(q) - vec2(-float(i), float(j));
      float h = fxHash(id + float(L) * 17.);
      if (h > count) continue;
      vec2 ctr = id + vec2(fxHash(id + 1.), fxHash(id + 2.));
      ctr.x += sin(uTime * .5 + h * 30.) * .3;
      float r = (.3 + .4 * fxHash(id + 3.)) * (1. + float(L) * .3);
      vec2 d = (q - ctr) / r;
      // ② 光圈形状：圆与六边形之间插值；边缘亮环 + 内部半透明
      float dist = mix(length(d), hexLen(d), hexagon);
      float disc = smoothstep(1., .9, dist);
      float ring = smoothstep(.75, .95, dist) * disc;
      float tw = 1. + twinkle * step(.6, fxHash(id + floor(uTime * 2.)));
      vec3 col = mix(colorA, colorB, fxHash(id + 5.));
      light += col * (disc * .25 + ring * .35) * tw * (1. - float(L) * .3);
    }
  }
  vec3 c = 1. - (1. - src) * (1. - clamp(light * amount, 0., 1.));
  return vec4(c, 1.);
}
