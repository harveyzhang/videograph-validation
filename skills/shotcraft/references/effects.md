# effects.md — 特效与技法手册（通用）

按"要做什么效果"检索。每条给：做法/公式/参数量级/范例出处（pdoom-video `app/src/` 下文件，
逐行实现看范例源码）。
**能力标注**：[2D]=纯 Canvas2D 可做；[GLSL]=需单 pass shader；[3D]=需三维/raymarch 管线。
L0/L1/L2 分级见 SKILL.md；平台可用性与降级写法见 `platform-videograph.md`。

---

## A. 全帧后期链 [GLSL，或引擎内建]

帧流水线（范例：pdoom `engine/post.ts`）：
```
HDR 线性帧 → bloom 金字塔 → final：
  uv=(vUv−.5)/zoom+.5−shake/res        # zoom/shake 是整帧操作
  → 径向 CA（三通道各偏移采样）→ +bloom·金字塔色 +halation·橙红·luma(大半径级)
  → ×exposure → UI 线性合成（同吃 grain/vignette）→ tone shoulder → invert → +bone·flash
  → vignette → ×(1−fade) → toSRGB → 双尺度 grain+dither
```
- **bloom 金字塔**：7 mip；软阈值（quadratic knee）预滤波 + Jimenez 13-tap 降采样 + 9-tap tent
  上采样叠加；最终强度 ÷级数归一。
- **halation**：取金字塔较深一级（更大半径）染橙红 `vec3(1.0,0.18,0.04)`——胶片感，克制使用。
- **tone shoulder**：k≈0.72 以下恒等，以上指数肩；过曝 2–12 去饱和到白——**HDR 过曝自动变白热，
  火花白核不用手画**。
- **grain**：细粒（每物理像素）+粗粒（2×2 逻辑像素格）；midtone 加权 `amt=grain·(0.55+1.2·lm(1−lm))`；
  +1/255 抖动；种子每帧换（`fract(time·13.37)·1000`）。
- **invert**：线性域 `mix(col, bone−col·0.84, invert)` 做 ink↔bone 反转（亮底板切换）。

**参数默认值**（可直接当起点）：exposure 1 / bloom 0.55 / threshold 0.85 / knee 0.5 / radius 0.75 /
halation 0.25 / ca 1.2 / grain 0.055 / vignette 0.35。

**调色板纪律**：ink #0A0A0B / ink2 #151517 / graphite #5E5B57 / ash #9C978F / bone #EEE9DF /
**signal #FF4D12（唯一语义强调）** / ember #FF8A3D / blood #C21D0B / accent（全片限一次，如
acid #D8FF3C）。**只有 signal/ember 允许 >0.85 进 bloom；bone 文字压 0.8–0.96 永不发光。**

## B. 运动模糊与确定性渲染 [引擎级]

- **自适应子帧**：三元细分 4→12→36→108→324（每步在每个旧子帧两侧各加一个，保持均匀居中）；
  每步算"显示误差"（2×2 块 sRGB 域、新旧子帧集平均差）<tol(≈3/255) 停。静止帧 12、普通运镜
  36、whip/撞月 108–324。（范例：pdoom `engine/engine.ts`）
- **场景端三规则**（不做自适应子帧的平台也要守前两条）：
  1. 60fps 抖动以 `frameIdx(t)=round(t·60)` 为种子（快门内恒定），不是 `floor(t·60)`。
  2. 粒子发射率写成**出生时刻的函数**（见 C）；在当前 t 读速率会让粒子在子帧间整体重排。
  3. shader 内部超采样接 SS_TAP 协议（4 个旋转栅格 tap 轮流分给子帧，1/4 成本同图）。
- **无状态至上**：连"物理"都用 init 期积分成 Float32Array 查表（见 G），17 个范例板零状态。
- **单板噪声封顶**：收敛慢的高频噪声（半分辨率 sparkle 类）给该镜头设 `maxSamples`。

## C. 火花系统 [2D/线条批] —— 全片统一 motif 的标准实现

```ts
sparkHead(lb, x, y, t, scale=1, intensity=1)
// 闪烁 flick=0.85+0.15·sin(91.7t)sin(57.3t)；三层同心点：
//   26px signal×0.5 → 12px ember×2.5 → 5px 近白/1.0 + 4 根细射线（半径每 1/30s hash 抖动）

sparkParticles(lb, t, headAt, { rate|rate(tb), rateMax, life=0.45, speed=260,
                               gravity=520, intensity=1, seed=1, width=1.6 })
// 确定性出生钟模型（本库最重要的单一模式）：
//   出生在恒定 rateMax 时钟：tb = n/rateMax；
//   变速率 = hash(n,seed+3)·rateMax >= rate(tb) 时抽稀掉；
//   headAt(tb) 用出生时刻的头位置（回调必须 t 可逆）；
//   方向均匀 hash·TAU，速度 speed·(0.25+hash²·1.2)，初速 −0.3speed 上抛，
//   0.5·g·age² 重力，寿命 life·(0.35+0.65hash)；
//   streak 模糊：同一粒子再取 age−0.018s 位置画短段；
//   颜色 = signal 向白热 lerp(k²) ×2.2（HDR 进 bloom），α=min(1,k·1.4)。
```
- 用例：常驻 rate + 事件突发（每拍 burst：birth 相位 `ph<0.1` 才喷=噼啪感）；拖尾=采样
  `headAt(t−i·0.007)` 若干点按累计弧长淡出；曲线拖尾=每帧重采样折线、颜色按顶点年龄
  `exp(−age/0.16)` 从 signal 混到白热。
- Canvas2D 版：头=径向渐变（白→ember→signal→透明）；粒子=短线段+`globalCompositeOperation='lighter'`。
范例：pdoom `scenes/_motifs.ts`。

## D. 版画/刻线渲染（明暗即线密度）

**总原则**：光照照度 → 覆盖率/线宽 → 排线。墨不发光，白不 bloom。

### D1. 基础词汇 [GLSL]（范例：pdoom `engine/glsl/common.ts`）
- `hatch(u, darkness)`：沿坐标 u 的整数平行线，线宽 ∝ darkness，fwidth AA，4K 保持 1x 墨量。
- `engrave(uv, darkness, freq, angle)`：细 hairline+暗部交叉 hatch。
- `heat(x)`：ink→blood→signal→ember→白热 ramp（热物标准色映射）。
- `aaFill/aaStroke/pxLine/rampLine`：fwidth AA 原语，任意输出分辨率不变细。
- **Canvas2D 等价**：clip 区域内 stroke 平行线（间距/线宽/alpha 由 darkness 驱动）；heat 用
  插值色表；预生成一张排线 pattern 离屏 canvas 也可（确定性绘制，非外部资源）。

### D2. fwidth 恒宽图表线 [GLSL]
- 等值线：`f=abs(fract(h+.5)−.5)`，`pxLine(f, fw·k)`；线密时 fade 到均值色防摩尔；Tanaka 照明：
  按坡向 `sat(0.5+0.55·aspect·sat(slope·1.2))` 调线亮度。
- 网格：盒滤波 `gridCov(p,N)`（`w=max(|dFdx|,|dFdy|)`）；线宽不足 0.8px 时降 alpha 补偿防闪烁；
  `if (uniform>0.0)` 分支保护 fwidth 定义。范例：loss/leftturn。

### D3. G-buffer 管面刻线 [3D+GLSL]（raymarch 版画范本：shoggoth-glsl）
1. half-res MRT：`g0=(t, along, around, id)`、`g1=(key, rim, ao, nUp)`；聚合用 **id 感知 smin**
   （记录最近图元的沿管/绕管参数——刻线 UV 免费得到）。
2. 上采样只信 `id 相同且 |Δt|<0.06·t` 的邻域；不连续度 `edge=1−ws/cov` **直接当沟壑墨线**。
3. 着色：`light=key(0.3+0.7ao)+0.05up → 线宽 pow(light,1.25)·0.9`；`elineLod` 用 `log2(fwidth·u·px)`
   在两档线密度间 mix——任意距离屏幕线距恒定；超密/低覆盖回 tone 纯色；rim 单独刻 ember 层；
   沟壑压黑；深度雾。

### D4. 实体光照+逐材质刻线 [3D+GLSL]（"光越亮线越密"：ilya-glsl）
- 真光照：解析矩形面光源 form factor（四角归一化向量两两弧长和 /2π）+48 步软阴影+体积光
  pocket 采样（采样集中在离光源最近的区间，hash 抖动）。
- `tone=1−exp(−maxRGB(E)·2.2)`；**每材质指定刻线轴向量+世界间距**（桌面 0.0032m、褶皱顺纹
  0.022、凹槽 0.045…）；`cov=hatchLOD(dot(p,axis)/sp, tone, footprint(p,n,axis))`——footprint 用
  邻近射线与切平面交点估世界空间像素足迹（比 fwidth 稳）。线色混入光源色相。

### D5. 显式频率足迹抗摩尔 [GLSL]（paperclips-glsl）
- 绕管角分 N 条刻线，`fw = N/(2·线宽px·max(sinθ,0.2))`（每像素线密度，含前掠修正）：
  `fw>0.3~0.75` 时从 AA 线覆盖平滑退化为平均暗度——任何缩放不闪。

### D6. 材质级刻线技巧
- 鳞片 [GLSL]（ascent-eye `scaleShade`）：Voronoi 单元穹顶高度→法线→Lambert；刻线=横贯等值线
  `hatch(dot(wq,dir)·lines+dome·0.9+rnd·0.3, light)`——线随曲面弯、随光变宽；叠瓦压暗+受光白唇线。
- 浮雕表面 [GLSL]（ascent-note 月面）：高度场（球+陨石坑）法线 Lambert→水平 hatch 随高度位移、
  暗处覆盖率升高、最暗叠交叉 hatch。
- guilloché [GLSL/2D]：`rosette()` K 条玫瑰线，**斜率归一化距离 `(r−rk)/sqrt(1+slope²)` 保证线宽
  均匀**；底纹两组互扣正弦；woven band 周长交织。
- 纸与墨 [2D+GLSL]（bureau）：程序纸=fbm 云+纤维（随机短线段 SDF）+斑点；**通道编码墨水**——
  Canvas2D 'lighter' 把多种墨画进 R/G/B，shader 按通道调密度后 **Beer-Lambert 叠印
  `col×=pow(transmission,density)`**（墨叠墨减色模型）；橡皮章=三倍频噪声砂眼+受压 mottling
  +unsharp 边缘积墨（状态在 TS、质感在 shader）；撕纸=三倍频锯齿线+`pow(snoise,6)` 飞丝+白纤维断口。
  [2D 降级]：多种墨色分次直接绘制，叠印顺序模拟减色。

## E. 卡拉OK与文字动画 [2D]

统一状态机：**未唱=低透明/描边预览 → 唱中=signal 热填+pop → 完成=冷却回 bone**（`exp(−age/0.28)`）。
时间唯一来源 `wordProgress(word,t)`；预显整行 ≤0.4s；高亮永不超前人声。

| 变体 | 做法 | 范例 |
|------|------|------|
| 逐字形 clip wipe | `gp=clamp(p·n−i)`，clip 矩形到 `g.x+g.w·gp` 再 fillText；方向可定制（向上/竖排） | open/loss |
| 亚字符 wipe | 音节表折算连续字符数+kerned x 定位 | dense-press |
| 书写同步 | 单笔画字 + `writtenLength(st, charTimes, t)` 时间→弧长 | spacetime/bureau |
| token 化 | 词→piece 切分表+候选分布+指定采样；非首 piece 用音节时间 | prompt |
| 双通道 3D 字 | 纹理 R=填充 G=描边（'lighter' 两遍），shader 按 ink extent wipe | stack-kit |
| 镜像词 | 每 glyph `scale(−1,1)` 置镜像 kern 位置右→左显出 | bureau |
| 骑曲线/弧/环 | baseline=曲线+旋转 0.6·atan(斜率)；弧排字直立；环上 proj 弦长缩放+kern 修正+背面剔除 | loss/ascent/spacetime |
| 沿路径文字 | `layout().glyphs[i].x → 弧长` | fuse |
| 字宽/字重跳变隐藏 | 可变字体档位切换时 `scaleX(上一级宽/当前宽→1)` 配 spring 弹回 | dense |
| 速度驱动变形 | `vel=|Δy|·60` → 纵向拉伸+多层拖影 | hook |
| 文字当几何 | 字形轮廓 flatten 成折线点集→仿射/逐点映射=形变（填充与线条共享 transform） | outro ∞→NaN |
| 文字当 mask | fillText 进 DataTexture 逐格采样（重复单元拼字）；画进 R/G/B 通道当 shader 数据 | dense-gpu/shoggoth |
| 排版工艺 | 逐字绘制必须用 layout/glyph 拿 kerning；撑满排版反解字号；typographic 标点 vs mono 打字机引号；缺字形手绘（⏎ ▸ Δ θ） | 全部范例 |
| 违抗卡拉OK | 该词高亮方向反着走（右→左）——语义与形式互文 | stack |

## F. 相机与运动 [通用]

| 系统 | 做法 | 范例 |
|------|------|------|
| CamKey 表 | 关键帧数组，zoom **log 空间插值**；两端差>4% 改绕不动点 `fx=(bz·cx2−az·cx1)/(bz−az)` | open |
| 球坐标 orbit | `orbit(tgt,yaw,pitch,dist)`+贴地约束+手工投影返回 (x,y,scale,clipw) 供 2D 叠加 | loss |
| UI 空间相机 | Canvas2D `setTransform` 整层当相机；hairline=1/zoom 恒宽；Shot 表 {t,zoom,focus,blend} | prompt |
| 2D 仿射相机 | 正/逆变换成对（shader 用逆采样）；log-zoom 融合；剪切点防糊守卫 | bureau |
| CPU pinhole | `Cam{p,R,U,F,f}`+近平面参数裁剪+深度衰减；`planeAffine` 投影 3 点解仿射把 2D 文字贴上 3D 平面 | room |
| snap reframe | 每拍重构图：前镜头 outExpo 插到当前镜头；roll kick=阻尼正弦 | room/leftturn |
| whip-pan | 快门内双位姿 multi-tap（shader ≤16 位姿自适应；Canvas2D 多份偏移重绘）；CA 随 whip 拉高 | leftturn |
| 逐线段模糊 | 位移驱动：每线段重画 `clamp(ceil(|dy|/0.1),1,12)` 份 α/NS·1.6 | stack |
| match-cut 锚定 | 缩放同时插值屏幕锚点 `cam.y=目标y−(H/2−sy)/zoom` | ascent |
| 构图反解 | "想让它出现在屏幕某处"→反解相机；已知下一板锚点→反解本板末相机 | leftturn |
| 拍驱动位移 | Step[] 累积表+`springStep`+拍前 anticipation；`stepped(t,ks,freq,damp)` 每阶跃被弹簧接住；低频副本=滞后差分源 | stack/dense-askew |
| 冲击语法 | shake=`Σ amp·pulse(t,事件,τ)` × hash/双频正弦；zoom=`1+0.01..0.05·pulse`；punch 反相帧=2 帧前景背景互换 | 全部 |

**缓动直觉**：outExpo 释放；springStep(freq 3.0–3.6, damp 0.42–0.74) 接阶跃；inOutCubic 相机融合；
inQuad/inExpo 加速坠；outBack(1.3–1.6) slam 落定；pulse(τ 0.06–0.12s) 事件冲击。

## G. 确定性时间/数据/模拟 [通用]

- **构造期事件表**：歌词行/词/音节 + 拍网格 → 绝对时刻私有表；render 只读。音节缺失按时长均分回退。
- **keys(t, [[t,v,ease],…])** 多段关键帧；**ease 逆函数二分**（18–24 轮）求"某物到达某处的时刻"
  ——不引入第二个手调常数。
- **构造期数值积分→查表**：受迫弹簧跟踪外部数据（音高/任何序列）+松手自由振铃双态 ODE（fuse 弦）；
  流场时钟 dt=1/240（spacetime）。**物理也服从"帧是 t 的纯函数"**。
- **随机**：`mulberry32(seed)` 序列（填充布置+拒绝采样防重叠）；`hash(...)` 逐粒子/逐帧；
  GLSL hash 同族。
- **弧长参数化=万能轴**：路径均匀重采样后，一切"生长/燃烧/经过/书写"都是**标量前沿 vs 弧长**：
  灼痕 age、燃烧互逆表、笔尖截断、文字映射。匀速到达用 ease 反函数分布。

## H. 仪表/图表族 [2D]（数据的世界内舞台化）

- **odometer 滚数**两式：①shader 圆柱图集——`th=asin(clamp(y/R))`，图集 v=已转字位数−`th/(2π/10)`，
  RepeatWrapping；模糊=10 抽头跨 ±角速度/2 字位（闭式）；spin-down=逐鼓延迟阻尼振荡（ascent-odo）；
  ②clip 窗滚鼓——detent（round 附近 smoothstep 才进位）+carry+高速 4 份拷贝速度模糊（hook）。
- **阶段化读数**：阶梯值+0.9s 滚动+蠕变+微抖（PDoom 模式）；任意缩放画进板内的仪表绘制函数。
- **示波器**：束扫+磷光余辉（前 N 拍旧轨迹 `0.5^k` 重画+相位漂移）+哑通道彩蛋线。
- **图表**：确定性数据生成（mulberry32+趋势项）；对数网格+穿线刻度变橙；计数器 log10 空间 lerp；
  甘特图"时间即坐标" `X(t)=GX+(t−t0)·V`+依赖箭头+里程碑盖章扩散环。
- **UI 仪表**：检测框（outExpo pop+闪烁+置信度+倒计时）、面板数值+指数漂移+每拍计数条、
  QC log（最新从下滑入）、SMPTE timecode、量角弧。

## I. 大场面手法索引

| 效果 | 做法 | 能力 | 范例 |
|------|------|------|------|
| 指数分支爆炸 | 火花按八分/十六分代际表 1→2→4…；线冷却=绘制时刻反推 age 的 heat 阶梯 | [2D] | room |
| 冲击波环 | 事件回溯最近 N 个十六分；`r=r0+A(1−exp(−age·k))`；双通道=环带着色+顶点径向推移 | [2D+GLSL] | room |
| 字形碎裂 debris | 字形轮廓细分→等距切刀→径向速度+指数弛豫+重力+自旋 | [2D] | room |
| 表面生长 | 平面坐标展开映射到多面；随机游走 tips+分叉；birth 弧长按节拍 burst 揭示，尖端 accent 色 | [2D] | room 菌丝 |
| x-ray 扫描揭示 | 扫描带前沿=卡拉OK光标投影；带内遮罩透明+scanline+热边；双 clip 分区绘制 | [2D/3D] | shoggoth |
| CRT 关机坍缩 | squash 1→0.0025 统一进渲染与 UI；中线三层高斯（热核+余晖+白芯） | [2D/3D] | shoggoth |
| 黑洞/透镜 | 阴影半径+光子环四层+多普勒亮边；薄透镜方程反投影+MipLayer 采字 | [GLSL] | spacetime |
| 万物归一点 | 指数拉拽 warp+1/d 旋涡+方向模糊；亮度域反白时保持高 chroma 强调色 | [GLSL] | ascent |
| 时间重映射 stutter | `remap(t)→{时间,循环号}` 快放 N 遍，内容函数无感知 | [2D] | bureau |
| 撕纸 | 三倍频锯齿撕裂线+飞丝+白纤维断口+两半坠落 | [2D] | bureau |
| Droste 递归 | log-polar（clog→复数乘→cexp）+矩形归一计数层+解析导数喂 textureGrad+底层直采实时渲染 | [GLSL] | loom |
| 无限晶格 | 单元 SDF+层堆叠只算最近层+解析跳空+像素尺度步进下限+按屏幕尺寸分级开闭阴影/AO | [3D] | paperclips |
| 无限堆叠 | 世界坐标层固定、相机跟随、只画焦点 ±N 窗口 | [2D/3D] | stack |
| 无限重复单元（免几何） | 全屏 shader fragment 逆布局+DataTexture 语义 mask+波前 flood | [GLSL] | dense-gpu |
| 透镜畸变采字 | 源平面 Canvas2D→mipmap+预乘纹理→反投影采样 | [GLSL] | spacetime |
| 拍呼吸地形 | beat 波前高斯环叠加进高度场标量——等高线随之呼吸并点亮波前线 | [GLSL] | leftturn |
| 字形形变链 | 轮廓点集+逐段映射+落地闪光冷却+echo 过去帧 transform | [2D] | outro |
| 倒带蒙太奇 | 预渲染静帧加速倒放+duotone/RGB 分离旧化；真重放=实例倒放刹车 | [2D] | outro |
| 双世界 tilt | 两套相机各自平移，两世界锚点在屏幕上按 smoothstep 交叉淡化 | [2D] | fuse |
| strobe/echo | 按八分 `floor(beat·2)%N` 轮转配色；径向 echo=向中心多次采样 premultiplied 累加；残影=过去 N 帧状态各画一遍描边 | [2D/GLSL] | hook/dense-askew |

## J. 参数量级速查（范例全片统计，可直接当起点）

| 项 | 典型值 |
|----|--------|
| shake | 6–30 px（事件脉冲，τ 0.06–0.12s）；打字微震 ~2px |
| flash | 日常 0.006–0.05；命中 0.12–0.3；换世界 0.8–1.2（用完立刻回日常） |
| ca | 基线 0.5–1.6；紧张/whip +3–7；坍缩峰值 13 |
| zoom punch | 1+0.01–0.05·pulse；dive `exp(log(Z)·inQuad)` |
| bloom | 亮底板 0.2（thr 1.8）；正常 0.55–0.7；命中/落定 0.8–1.4 |
| 火花粒子 | rate 85–940、speed 220–420、life 0.3–0.45s、gravity 320–520 |
| 刻线屏幕间距 | 3.2–7px（密度 LOD 锁定） |
| raymarch | 96–160 步、relaxed 0.8–0.9、命中阈值比例于 t |
| Canvas2D 层 | 每板 1–3 个（upload 2–4ms） |
| 线批容量 | 3k–200k 段（按需） |
