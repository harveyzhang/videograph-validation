/*@effect
{
  "id": "riso-two-ink",
  "name": "Risograph 双色套印",
  "kind": "post",
  "category": "印刷与版画",
  "tags": ["risograph", "print", "grain", "zine", "套印"],
  "summary": "把画面分成两种专色油墨（默认荧光粉 + 群青），带套印错位与油墨颗粒。",
  "when": "独立杂志感、文艺海报、温暖手作感的宣传片；也适合音乐人 PV 的主歌段统一视觉。",
  "avoid": "需要准确肤色或产品真实颜色的镜头；画面大面积纯黑时会变成满版混色（先提亮或换浅色纸）。",
  "params": {
    "inkA": { "type": "color", "default": "#ff4f9a", "label": "油墨 A（亮部第一层）" },
    "inkB": { "type": "color", "default": "#2d4cc8", "label": "油墨 B（暗部第二层）" },
    "paper": { "type": "color", "default": "#f4ecdc", "label": "纸色" },
    "misregister": { "type": "float", "default": 0.004, "min": 0, "max": 0.02, "label": "套印错位" },
    "grain": { "type": "float", "default": 0.35, "min": 0, "max": 1, "label": "颗粒" }
  },
  "bindings": { "misregister": { "to": "kick", "amount": 0.006 } },
  "inspiredBy": [{ "source": "lemo-opuscar-styles", "ref": "styles/risograph", "note": "只参考风格名称与观感描述，代码为本项目自写" }],
  "version": 2,
  "license": "MIT",
  "author": "videograph",
  "provenance": "本项目原创实现（随仓库 MIT 分发）；inspiredBy 只记录风格参考来源，未复制代码。"
}
@effect*/

// ============================================================================
// 特效箱样板：Risograph 双色套印（给其他 agent 照着写的参考实现）
// ----------------------------------------------------------------------------
// 一、文件结构（一个文件 = 一个动效，文件名必须等于 id）
//   1. 头部 /*@effect … @effect*/ 是 JSON manifest：
//      - id/name/kind/category/tags：检索与分类用；kind = post（镜头后期）或 transition（转场）。
//      - summary/when/avoid：AI 选效果时读的三句话。when 写“什么镜头/情绪该用”，avoid 写“什么时候会翻车”。
//      - params：每个参数都会被宿主声明成同名 uniform（不要在下面再写 uniform）。
//        类型 float/int/bool/vec2/vec3/vec4/ivec2/color；color 用 "#RRGGBB"，在着色器里是 vec3。
//        float 一定要给 min/max，界面会生成滑块，服务端会校验 AI 填的值。
//      - bindings：把某个 float 参数挂到节拍上：实际值 = 基础值 + amount × 脉冲。
//        to = beat（每拍衰减）| kick（鼓点脉冲）| bar（每小节）| energy（音乐能量）。
//        这是“卡点”的标准做法：不要在着色器里自己算节拍。
//      - inspiredBy/provenance/license：来源与许可。只参考风格就写 note；复制了谁的代码必须写明并确认许可允许。
//   2. 正文只需要定义 vec4 effect(vec2 uv)；转场则定义 vec4 transition(vec2 uv)（gl-transitions 接口）。
//
// 二、宿主提供的东西（预览、校验、导出三处同一份，见 src/fx/runtime.mjs 与 src/server/transition-runtime.mjs）
//   - srcTex(uv)：读当前画面，**显示空间 0..1**（引擎内部是线性 HDR，宿主已经帮你编解码）。转场用 getFromColor/getToColor。
//   - uniform：uRes（输出像素尺寸）、uTime（歌曲秒）、uProgress（镜头内 0..1）、uBeat/uBar（拍/小节相位 0..1）、
//     uKick（鼓点脉冲 0..1）、uEnergy（能量 0..1）。
//   - 工具函数：fxHash fxNoise fxFbm（确定性噪声）、fxLuma、fxRot、fxBayer4、fxHex、fxSobel。自定义函数不要用 fx 前缀。
//
// 三、硬规则（scripts/fx/check-box.mjs 会检查其中可自动检查的部分）
//   1. 确定性：输出只取决于 uv、uniform 与参数。禁止依赖帧间状态；需要“随机”用 fxHash(坐标 + 量化后的时间)。
//   2. 分辨率无关：像素尺度的东西（颗粒、网点、线距）乘 uRes 换算，不要写死“0.001 ≈ 1 像素”。
//   3. GLSL ES 3.00：浮点字面量写 1. 而不是 1；不能用非常量表达式初始化全局变量；循环次数要是常量。
//   4. 安全：不要做全屏明暗交替（>3 次/秒是光敏风险）；节拍冲击用“瞬间起跳 + 衰减”，幅度有上限。
//   5. 成本：每像素采样控制在 ~16 次以内（这里是 2 次）；1080p 实时预览要流畅。
//   6. 默认参数就要好看且“看得出效果”：校验会拿默认值和原图比较，差异太小判失败。
//
// 四、实现思路：模拟“过程”而不是“外观”
//   真实的 riso 是：原稿分色 → 每种油墨一张蜡纸（版）→ 两个滚筒先后印到纸上；两次印刷对不准就是“套印错位”，
//   蜡纸打孔的颗粒让墨色不均匀，油墨是半透明的、叠在一起相乘变深。下面每一步对应一个物理环节。
// ============================================================================

vec4 effect(vec2 uv) {
  // ① 分色 + 套印错位：两张“版”各自从略微错开的位置取样。
  //    A 版水平偏、B 版竖直偏（偏移量不同方向，叠印时边缘才会露出两种颜色的毛边）。
  //    misregister 挂在 kick 上：鼓点那一帧两张版“抖开”，随后衰减回位——这就是卡点。
  float lumA = fxLuma(srcTex(uv + vec2(misregister, 0.)).rgb);
  float lumB = fxLuma(srcTex(uv - vec2(0., misregister * .7)).rgb);

  // ② 蜡纸颗粒：按“像素格”量化坐标再取哈希，颗粒大小跟输出分辨率走（.75 ≈ 每 1.3 像素一个颗粒）。
  //    没有用 uTime → 颗粒是静止的（真实印刷品的纸面不会闪），避免整片沸腾。
  float g = (fxHash(floor(uv * uRes * .75)) - .5) * grain;

  // ③ 墨量曲线：暗处吃墨多。两张版的阈值区间不同——A 负责中间调，B 只在更暗处出现，
  //    所以亮部只剩纸色、中间调是单色 A、暗部是 A×B 叠色，层次来自“分版”而不是调色。
  //    颗粒对两张版的作用方向相反（+g / -g），叠色区更斑驳，像真的两次印刷。
  float covA = smoothstep(.15, .85, 1. - lumA + g * .6);
  float covB = smoothstep(.35, .95, 1. - lumB - g * .4);

  // ④ 减色叠印：从纸色出发，油墨按覆盖率“乘”上去（半透明油墨相乘变深），
  //    覆盖率上限 0.9/0.8 留一点纸的透气感，满版也不会是死黑。
  vec3 c = paper;
  c = mix(c, c * inkA, covA * .9);
  c = mix(c, c * inkB, covB * .8);

  // ⑤ 输出：显示空间颜色，alpha 固定 1（宿主负责转回引擎的线性空间）。
  return vec4(c, 1.);
}
