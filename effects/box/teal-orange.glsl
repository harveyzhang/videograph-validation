/*@effect
{
  "id": "teal-orange",
  "name": "青橙电影调色",
  "kind": "post",
  "category": "胶片与调色",
  "tags": [
    "teal orange",
    "cinematic",
    "grade",
    "blockbuster",
    "调色"
  ],
  "summary": "暗部推向青色、亮部推向橙色，加 S 曲线，常见大片调色。",
  "when": "大片感宣传、运动、产品英雄镜头。",
  "avoid": "已经强烈风格化的画面。",
  "params": {
    "amount": {
      "type": "float",
      "default": 0.6,
      "min": 0,
      "max": 1,
      "label": "强度"
    },
    "curve": {
      "type": "float",
      "default": 0.35,
      "min": 0,
      "max": 1,
      "label": "S 曲线"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "videograph",
      "ref": "teal & orange grade",
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
  vec3 c = srcTex(uv).rgb;
  float l = fxLuma(c);
  vec3 graded = c + mix(vec3(-.05, .06, .1), vec3(.12, .04, -.08), smoothstep(.2, .8, l));
  graded = mix(graded, graded * graded * (3. - 2. * graded), curve);
  return vec4(mix(c, graded, amount), 1.);
}
