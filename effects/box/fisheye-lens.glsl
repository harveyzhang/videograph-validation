/*@effect
{
  "id": "fisheye-lens",
  "name": "鱼眼镜头",
  "kind": "post",
  "category": "镜头与扭曲",
  "tags": ["fisheye", "barrel distortion", "skate video", "lens", "鱼眼", "桶形畸变", "滑板片", "广角"],
  "summary": "超广角鱼眼的桶形畸变：画面中心鼓起、边缘被压弯，四角带一圈色散与暗角；鼓点时镜头“凸”得更厉害。",
  "when": "滑板/街头/嘻哈 MV、搞怪近距离怼脸、监控与猫眼视角、运动相机感。",
  "avoid": "需要直线保持笔直的建筑与产品镜头；文字贴近画面边缘时会被弯掉。",
  "params": {
    "strength": { "type": "float", "default": 0.35, "min": 0, "max": 1.2, "label": "畸变强度" },
    "fringe": { "type": "float", "default": 0.4, "min": 0, "max": 1, "label": "边缘色散" },
    "vignette": { "type": "float", "default": 0.5, "min": 0, "max": 1, "label": "暗角" },
    "bulge": { "type": "float", "default": 0, "min": 0, "max": 0.6, "label": "鼓点鼓起（通常由节拍驱动）" }
  },
  "bindings": { "bulge": { "to": "kick", "amount": 0.25 } },
  "inspiredBy": [{ "source": "videos-casebook", "ref": "techniques：镜头语言/广角", "note": "按思路自写" }],
  "version": 1, "license": "MIT", "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：鱼眼镜头用等距投影把 180° 视场压进一个画幅，离中心越远的物体被压缩得越多，直线弯成弧线（桶形畸变）；
// 不同波长折射率不同，所以边缘的高反差处出现红蓝色散；大视角下边缘进光少，形成暗角。

vec2 bend(vec2 uv, float k) {
  vec2 asp = vec2(uRes.x / uRes.y, 1.);
  vec2 p = (uv - .5) * asp;
  float r2 = dot(p, p);
  float rmax2 = dot(asp * .5, asp * .5);
  // ① 桶形畸变：像素到中心的距离按 (1 + k r²) 放大取样（采样点往外推 = 画面往中心压缩），再整体缩放让四角刚好铺满
  p *= (1. + k * r2) / (1. + k * rmax2);
  return p / asp + .5;
}

vec4 effect(vec2 uv) {
  float k = strength + bulge;
  // ② 色散：红/绿/蓝三个通道用略有差别的畸变量取样（3 次采样），边缘处分得最开
  float f = fringe * .08;
  vec3 c = vec3(srcTex(bend(uv, k * (1. + f))).r, srcTex(bend(uv, k)).g, srcTex(bend(uv, k * (1. - f))).b);
  // ③ 暗角：按到中心距离的平方衰减
  vec2 d = (uv - .5) * vec2(uRes.x / uRes.y, 1.);
  c *= 1. - vignette * smoothstep(.3, 1.1, length(d));
  return vec4(c, 1.);
}
