/*@effect
{
  "id": "neon-edges",
  "name": "霓虹描边",
  "kind": "post",
  "category": "复古与数字",
  "tags": [
    "neon",
    "edge glow",
    "cyberpunk",
    "tron",
    "霓虹"
  ],
  "summary": "只保留发光的边缘线（可双色渐变），背景压暗。",
  "when": "赛博朋克、夜景、科技发布会。",
  "avoid": "平涂、无轮廓画面。",
  "params": {
    "colorA": {
      "type": "color",
      "default": "#00e5ff",
      "label": "颜色 A"
    },
    "colorB": {
      "type": "color",
      "default": "#ff2fb8",
      "label": "颜色 B"
    },
    "intensity": {
      "type": "float",
      "default": 1.6,
      "min": 0.5,
      "max": 4,
      "label": "亮度"
    },
    "keepImage": {
      "type": "float",
      "default": 0.12,
      "min": 0,
      "max": 1,
      "label": "保留原图"
    }
  },
  "bindings": {
    "intensity": {
      "to": "kick",
      "amount": 1.2
    }
  },
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "neon / cyberpunk outlines",
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
  float e = fxSobel(uv);
  float glow = 0.;
  for (int i = 1; i <= 3; i++) { float r = float(i) * 2. / uRes.x; glow += fxSobel(uv + vec2(r, 0.)) + fxSobel(uv - vec2(r, 0.)) + fxSobel(uv + vec2(0., r)) + fxSobel(uv - vec2(0., r)); }
  glow /= 12.;
  vec3 tint = mix(colorA, colorB, uv.x + .2 * sin(uTime));
  vec3 c = srcTex(uv).rgb * keepImage + tint * (smoothstep(.15, .5, e) + glow * .8) * intensity;
  return vec4(c, 1.);
}
