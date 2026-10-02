/*@effect
{
  "id": "bloom-glow",
  "name": "柔光辉光",
  "kind": "post",
  "category": "胶片与调色",
  "tags": [
    "bloom",
    "glow",
    "dreamy",
    "soft",
    "辉光"
  ],
  "summary": "亮部向外溢出柔光，像镜头雾化或梦境。",
  "when": "梦境、婚礼、柔美产品、高光时刻。",
  "avoid": "主文字也发光（只让强调物发光）。",
  "params": {
    "threshold": {
      "type": "float",
      "default": 0.65,
      "min": 0.2,
      "max": 0.95,
      "label": "亮部阈值"
    },
    "intensity": {
      "type": "float",
      "default": 0.8,
      "min": 0,
      "max": 2,
      "label": "强度"
    },
    "radius": {
      "type": "float",
      "default": 0.012,
      "min": 0.002,
      "max": 0.04,
      "label": "半径"
    }
  },
  "bindings": {
    "intensity": {
      "to": "kick",
      "amount": 0.5
    }
  },
  "inspiredBy": [
    {
      "source": "shotcraft",
      "ref": "辉光纪律：只有强调色进辉光",
      "note": "规则自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec3 c = srcTex(uv).rgb;
  vec3 glow = vec3(0.);
  for (int i = 0; i < 12; i++) {
    float a = float(i) * .5236, r = radius * (.5 + float(i % 3) * .5);
    vec3 s = srcTex(uv + vec2(cos(a), sin(a)) * r * vec2(uRes.y / uRes.x, 1.)).rgb;
    glow += max(s - threshold, 0.);
  }
  return vec4(c + glow / 12. * intensity * 2., 1.);
}
