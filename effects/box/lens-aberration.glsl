/*@effect
{
  "id": "lens-aberration",
  "name": "镜头色差",
  "kind": "post",
  "category": "胶片与调色",
  "tags": [
    "chromatic aberration",
    "lens",
    "optics",
    "fringe",
    "色差"
  ],
  "summary": "越靠画面边缘颜色分离越明显，模拟廉价/复古镜头。",
  "when": "手持感、复古镜头、梦境边缘。",
  "avoid": "精确的产品与文字边缘。",
  "params": {
    "amount": {
      "type": "float",
      "default": 0.03,
      "min": 0,
      "max": 0.06,
      "label": "强度"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "videograph",
      "ref": "lateral chromatic aberration",
      "note": "本项目原创"
    }
  ],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/
vec4 effect(vec2 uv) {
  vec2 d = uv - .5;
  float k = dot(d, d) * 4.;
  vec3 c = vec3(srcTex(uv + d * amount * k).r, srcTex(uv).g, srcTex(uv - d * amount * k).b);
  return vec4(c, 1.);
}
