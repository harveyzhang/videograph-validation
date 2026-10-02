/*@effect
{
  "id": "kaleidoscope",
  "name": "万花筒",
  "kind": "post",
  "category": "运动与节拍",
  "tags": [
    "kaleidoscope",
    "mirror",
    "psychedelic",
    "symmetry",
    "万花筒"
  ],
  "summary": "画面按角度镜像成 N 瓣对称图形，缓慢旋转。",
  "when": "迷幻、电子音乐、过渡段的装饰。",
  "avoid": "需要识别主体与文字的镜头。",
  "params": {
    "segments": {
      "type": "float",
      "default": 6,
      "min": 2,
      "max": 16,
      "label": "瓣数"
    },
    "spin": {
      "type": "float",
      "default": 0.15,
      "min": -1,
      "max": 1,
      "label": "旋转速度"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "opus-video-prompt-libraries",
      "ref": "kaleidoscope / symmetry",
      "note": "自写"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec2 p = (uv - .5) * vec2(uRes.x / uRes.y, 1.);
  float r = length(p), a = atan(p.y, p.x) + uTime * spin;
  float seg = 6.28318 / segments;
  a = mod(a, seg); a = abs(a - seg * .5);
  vec2 q = vec2(cos(a), sin(a)) * r;
  q.x /= uRes.x / uRes.y;
  return vec4(srcTex(q + .5).rgb, 1.);
}
