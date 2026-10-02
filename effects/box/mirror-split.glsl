/*@effect
{
  "id": "mirror-split",
  "name": "镜像对称",
  "kind": "post",
  "category": "运动与节拍",
  "tags": [
    "mirror",
    "symmetry",
    "split screen",
    "对称"
  ],
  "summary": "左右（或上下）镜像，制造对称构图。",
  "when": "对立/对话、仪式感、片头。",
  "avoid": "有文字的画面（会出现反字）。",
  "params": {
    "vertical": {
      "type": "bool",
      "default": false,
      "label": "上下镜像"
    }
  },
  "bindings": {},
  "inspiredBy": [
    {
      "source": "videograph",
      "ref": "mirror",
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
  vec2 u = uv;
  if (vertical) u.y = u.y > .5 ? 1. - u.y : u.y; else u.x = u.x > .5 ? 1. - u.x : u.x;
  return vec4(srcTex(u).rgb, 1.);
}
