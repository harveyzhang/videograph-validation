/*@effect
{
  "id": "crt-monitor",
  "name": "CRT 显像管",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "crt",
    "scanlines",
    "monitor",
    "terminal",
    "显像管"
  ],
  "summary": "屏幕弯曲、扫描线、RGB 荧光点阵与暗角。",
  "when": "终端、黑客、复古游戏、科技回顾。",
  "avoid": "全屏大量小字（扫描线会降低可读性）。",
  "params": {
    "curvature": {
      "type": "float",
      "default": 0.12,
      "min": 0,
      "max": 0.35,
      "label": "屏幕弯曲"
    },
    "scanline": {
      "type": "float",
      "default": 0.35,
      "min": 0,
      "max": 1,
      "label": "扫描线"
    },
    "glow": {
      "type": "float",
      "default": 0.25,
      "min": 0,
      "max": 1,
      "label": "辉光"
    }
  },
  "bindings": {
    "glow": {
      "to": "beat",
      "amount": 0.2
    }
  },
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "CRT / terminal look",
      "note": "只参考风格描述，代码为本项目自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec2 c = uv * 2. - 1.;
  c *= 1. + curvature * dot(c, c) * .25;
  vec2 u = c * .5 + .5;
  if (u.x < 0. || u.x > 1. || u.y < 0. || u.y > 1.) return vec4(0., 0., 0., 1.);
  vec3 col = srcTex(u).rgb;
  vec3 bloom = (srcTex(u + vec2(.002, 0.)).rgb + srcTex(u - vec2(.002, 0.)).rgb + srcTex(u + vec2(0., .003)).rgb) / 3.;
  col += bloom * glow * .5;
  float scan = .5 + .5 * sin(u.y * uRes.y * 3.14159);
  col *= 1. - scanline * (1. - scan) * .6;
  float triad = mod(floor(u.x * uRes.x), 3.);
  col *= mix(vec3(1.), vec3(triad == 0. ? 1.15 : .9, triad == 1. ? 1.15 : .9, triad == 2. ? 1.15 : .9), .35);
  col *= smoothstep(1.2, .6, length(c));
  return vec4(col, 1.);
}
