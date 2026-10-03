/*@effect
{
  "id": "polaroid-instant",
  "name": "宝丽来即显",
  "kind": "post",
  "category": "胶片与调色",
  "tags": ["polaroid", "instant film", "integral film", "frame", "宝丽来", "拍立得", "即显相纸"],
  "summary": "一张拍立得照片：画面被白色相框包住（下边宽），色彩偏青偏粉、黑位发灰、高光略黄，中心亮边缘暗，药膜不均带一点化学斑；每小节像刚显影一样轻微“浮现”。",
  "when": "回忆、旅行、青春、朋友/家庭、生活方式品牌、“定格瞬间”的镜头；适合单镜头当作一张照片出现。",
  "avoid": "需要全画幅的镜头（相框会裁掉边缘内容）；准确色彩要求的产品镜头。",
  "params": {
    "frame": { "type": "float", "default": 1, "min": 0, "max": 1, "label": "相框（0 = 只要色调）" },
    "fade": { "type": "float", "default": 0.18, "min": 0, "max": 0.5, "label": "黑位发灰" },
    "develop": { "type": "float", "default": 0, "min": 0, "max": 0.6, "label": "显影未完成" },
    "chem": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "药膜斑痕" },
    "frameColor": { "type": "color", "default": "#f2efe6", "label": "相框颜色" }
  },
  "bindings": { "develop": { "to": "bar", "amount": 0.25 } },
  "inspiredBy": [{ "source": "lievan-video-prompts", "ref": "prompts/story：instant photo / polaroid 描述", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 1,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// 现实中：即显相纸在出相机时被滚轴挤破下边框里的药包，显影剂从下往上铺开（所以下边框宽、边缘常有药剂没铺匀的斑痕）；
// 它的染料层在暗部永远到不了纯黑（发灰偏蓝），高光偏暖黄，整体饱和度低、偏青粉；
// 显影要几分钟，画面是从淡到浓慢慢“浮现”的。

vec4 effect(vec2 uv) {
  // ① 相框：上/左/右边约 5%，下边约 18%（药包所在）；画面区域映射到框内。
  vec2 lo = vec2(.055, .2), hi = vec2(.945, .955);
  vec2 inner = (uv - lo) / (hi - lo);
  float inside = step(0., inner.x) * step(inner.x, 1.) * step(0., inner.y) * step(inner.y, 1.);
  vec2 iuv = mix(uv, clamp(inner, 0., 1.), frame);
  float inPhoto = mix(1., inside, frame);

  // ② 染料层的色彩响应：饱和度降低，暗部抬起并偏蓝青，高光偏暖黄，中间调偏一点粉。
  vec3 c = srcTex(iuv).rgb;
  float l = fxLuma(c);
  c = mix(vec3(l), c, .78);
  c = c * (1. - fade) + fade * vec3(.32, .38, .45);                 // 黑位发灰发蓝
  c += vec3(.06, .03, -.04) * smoothstep(.55, 1., l);                // 高光偏黄
  c += vec3(.03, -.02, .02) * (1. - abs(l - .5) * 2.);               // 中间调偏粉
  c = clamp((c - .5) * .92 + .5, 0., 1.);

  // ③ 显影未完成：整体更淡、更偏青，像还没“浮现”完全。develop 挂小节：每小节开头画面轻微变淡再浓回来。
  c = mix(c, vec3(.62, .7, .72), develop);

  // ④ 药膜不均：显影剂从下往上推，边缘（尤其靠近下边和两侧）有不规则的化学斑与发白的边。
  float edgeD = min(min(iuv.x, 1. - iuv.x), min(iuv.y, 1. - iuv.y));
  float blot = fxFbm(iuv * vec2(6., 3.) + 2.) * smoothstep(.12, 0., edgeD);
  c = mix(c, vec3(.92, .88, .78), smoothstep(.35, .7, blot) * chem * .6);
  c *= 1. - .25 * smoothstep(.25, .7, length(iuv - .5));            // 中心亮、四周暗（即显镜头的暗角很重）

  // ⑤ 相框：哑光白卡纸，带一点纸纹；照片外缘约 0.6% 宽的一圈卡纸略暗（相纸压在框下的阴影）。
  vec3 card = frameColor * (.97 + .03 * fxNoise(uv * uRes * .3));
  float outside = max(max(lo.x - uv.x, uv.x - hi.x), max(lo.y - uv.y, uv.y - hi.y));   // >0 在框上，<0 在照片里
  card *= 1. - .15 * smoothstep(.006, 0., outside);
  vec3 col = mix(card, c, inPhoto);
  return vec4(col, 1.);
}
