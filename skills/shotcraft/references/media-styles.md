# media-styles.md — 视觉媒介风格库（25 个 Opus 5.5 视频仓库蒸馏）

语料：25 个开源 Opus 5.5 视频仓库（清单与许可见 [SOURCES.md](../SOURCES.md)）；下列范例路径均相对该语料目录。
核心宪法（出自 opus-5.5-music-video-art-styles/docs/engine-patterns.md）：
**"Simulate the process, not the look"——模拟工艺过程，而非模拟观感**（MIT 语料 opus-5.5-music-video-art-styles，见 SOURCES.md）。给干净数字图加
"做旧滤镜"撑不了多久；要模拟的是工艺本身。

**实现路径判据**（选择手法前先问工艺属于哪类）：
- 工艺有**材料沉积**语义（墨、沙、蜡、颜料）→ 层内存 coverage（alpha），后置合成器着色；
- 工艺有**形变**语义（水纹、弯树、梳理）→ 几何点集 + 可逆点到点映射；
- 工艺有**光学**语义（透光、halation、热成像调色）→ 全屏 shader 后处理。
贯穿所有风格的纪律：每帧纯函数于 t（有状态媒介用显式 `step(t)` 按序 + `renderAt(t)` 追帧重建）、
种子化随机、on twos 运动（`floor(t*12)/12` 量化 12fps）+ 8–12fps 纹理 boil、切点落 beat。

---

## 1. 水彩手绘绘本（p5.brush 系代表风格）
**观感**：米黄纸底+柔和颜料（无纯黑白），每个形体=扁平 wash 底色 + 水彩 fill（bleed 泛色边+
纹理）+ 单条连续墨线轮廓。
**做法**：
- `paint(pts, {wash, washOp, fill, fillOp, bleed, tex, hatch:{d,a,o,b}, ink, sw, br, curv})`
  万能封装——一次调用走完全部四层（PDoomVideo/src/core.js:98-112）。水彩 fill 成本随顶点数
  增长：大形用 wash，fill 保持低多边形。
- 自定义笔刷参数表：ink（scatter .25/grain 40/pressure 变细）、dry（scatter 3/opacity 90 枯笔）。
- **颜料混色守则**：p5.brush 低透明度叠色会物理混色（黄叠蓝变绿）——layering 顺序即调色；
  显式混色用 `mixCol()`；**光是唯一例外**（见 fx 增补的 glow 两式）。
- 纸=离屏预生成（70 个径向渐变污渍+1400 条纤维短弧，seeded LCG）；grain+vignette 用
  `multiply` 压在成品上——颜料感来自"纹理乘进画面"。
- p5.brush 强制合成 hack：brush 把 wash/stroke 延迟到 mask 层，画一个 10px 离屏 fill 逼它
  立刻 composite（`flushLetters()`）；`centred()` 包裹规避 zoom>2 时远坐标 stroke 塌缩 bug。
**范例**：PDoomVideo/src/、ClaudeAnimationBase/src/（462 行 ANIMATION_GUIDE.md 是"手绘动画
宪法"，可整篇当风格 brief）。

## 2. GPU 油画/笔刷重绘（绘制期+shader 双层）
**观感**：会动的油画——笔触沿形体边缘排列，flat 色块+逆光 rim+暖光池。
**做法**（functional-emotions-video/js/paint.js，171 行）：
1. 每帧先在半分辨率画两层 Canvas2D：`s`（flat underpainting）+ `f`（additive 光层）；
2. GPU 把 underpainting 重绘成 ~6 万个 instanced 笔触：每笔在 base 位置采样亮度 Sobel 梯度，
   `ang=atan(gy,gx)+π/2`——**沿等亮度线排列**；平坦区退化为 value-noise 流场（Van Gogh 漩涡），
   `smoothstep(.015,.08,edge)` 混合；
3. 三层笔触尺寸（大笔全域/中笔弱边缘/小笔强边缘）——天然"边缘更细"；
4. 笔触材质：纵向 `(1-|x|⁴)` 笔锋收敛+软边+dry-brush 飞白（噪声 mask）+鬃毛条纹；
5. whip smear：`uSmear` 向量让所有笔触沿运动方向拉长 `len·(1+sm·3)`——**绘画式运动模糊**；
6. hex 偏移网格+散列洗牌绘制顺序去网格化；画布织纹 `sin(x·1.9)·sin(y·1.9)`。
**范例**：functional-emotions-video/js/paint.js。

## 3. Risograph 孔版印刷
**观感**：四色墨鼓（黑/蓝/荧光珊瑚/红）、halftone 网点、叠印第三色、套准漂移。
**做法**（why-wont-you-let-me-help/src/core/riso.js，GPU 四墨一 pass）：
- 层里只存 **coverage（alpha）**，颜色由合成器着色——同一套绘制代码可在"彩铅合成器"与
  "riso 合成器"间切换；
- halftone spot function：`v=.5−.25(cos2πqx+cos2πqy)`，coverage>0.9 直接实心，`fwidth` AA；
- **每鼓自己的网角**（blue 15°/red 0°/coral 75°/black 45°）防 moiré；
- **网屏锚定纸面坐标而非图像坐标**（网点钉在画框上，图像在其下移动）——印刷动画质感来源；
- 套准漂移=每鼓像素偏移（取整保网点锐利）；滚筒进度 `FX.roll`=按纸面 y 从上往下"印到哪算哪"
  （分色逐次印上，可直接当转场）；墨耗尽=低频×细噪声低于剩余墨量才出墨（拉丝 dry streak）；
- 四墨 `multiply` 叠印出第三色；辉光也印刷（halo 加进珊瑚鼓 coverage）。
**叙事化用例**：套准即叙事——恐惧把红鼓推出套准（偏移 `lerp(2,11,fear)`），和解时阻尼弹簧
"咔"回套准（`-.45·exp(−6x)·cos(21x)`）。
**范例**：why-wont-you-let-me-help/src/core/riso.js。

## 4. Halftone 两式
- **shader 式**：上面 riso 的 spot function（实时）；
- **CPU 预烘焙式**（art-styles/styles/screenprint/print.js）：对 cell 采样 160×160 个 cosine
  spot 值**排序建阈值表** `HT.thr[cov]`，保证"点长大→50% 相切→变孔"无缝连续。
两者共同要点：网屏属于纸，不属于图像。

## 5. 丝网印刷 screenprint
每墨=stencil mask（手刻 solid / 半分辨率 halftone tone / 平涂 tint）→ 逐墨 squeegee 拉过
multiply 上纸（带波浪前沿的扫过 clip）→ 各自失准 `off=[dx,dy,rot]` → squeegee 拉丝+900 颗
针孔 pinhole+边角套准线。**patch 重印**：噪声按纸面绝对坐标取值，stop-motion 换姿势只重印
一个矩形与整张无缝（`new Print({patch:[x,y,w,h]})`）。
**范例**：opus-5.5-music-video-art-styles/styles/screenprint/。

## 6. 剪纸/纸剧场/毡布（paper theater）
**做法**（bohemian-tokenry-video/video/styles/papertheater/kit.js，634 行）：
- 纸/毡无缝纹理：径向明暗斑+短纤维笔画+噪点，`wrapDraw` 9 宫格平铺；
- `cut(x, polys, color, o)` 一刀剪纸：投影 → 填色 → `createPattern` 随机相位贴纹理 → 纵向
  渐变（上亮下暗）→ 浅色描边 → `fuzz()` 沿轮廓画纤维；
- **`wobble()` 手切边**：3 个正弦谐波（u·3/u·8/u·23）+2.5% 随机缺口沿法线推点——所有剪纸
  轮廓都过这函数；
- `bake(w,h,K,pad,fn)` 4× 超采样预烘焙精灵+`source-in` 软阴影副本；约 40 个道具全预烘焙；
- 纸偶 rig：on twos 位置/旋转 jitter、`scale(turn/√sq, sq)` squash&stretch、眼型枚举、
  雪糕棒/吊线挂点；
- 深度：items 按 z 排序透视投影；焦点外画进半分辨率 BG/FG 缓冲回贴=**廉价 DOF**；light map
  （ambient+径向灯+闪烁）`multiply`；聚光灯锥+尘埃 `screen`。
**范例**：bohemian-tokenry-video/video/styles/papertheater/kit.js。

## 7. Backlit 剪影（逆光剪纸）
mask 沿 `rimDx` 平移后 `destination-out` 原 mask，`source-in` 填亮色贴回=**lit rim**（blur
光晕版+锐利边版两道）；层间 fog 带；`drawBent()` 把整片按 `dx(h)=A·h²/Hb²` 以 14 条横条剪切
变换弯曲，`bentPoint()` 给逆映射让附着的叶/雪跟着走。
**范例**：opus-5.5-music-video-art-styles/styles/paper-cut/paper.js。

## 8. 其它材料工艺（简条，均带完整引擎）
- **linocut 版画**：版=gouge 刻痕/留墨区列表，主版黑叠水彩洗底，on twos 运动；
- **刺绣**：羊毛铺线+couch 沿路径排布 tiles，轮廓 stem stitch，光=盘金线；
- **马赛克/沙画**：沿轮廓行排 tesserae；沙厚=密度场，透光 `exp(−k·thickness)`，手指清线；
- **marbling 水纹**：颜料=闭合点环，一切运动是**精确可逆映射**——`mapDrop`（径向推
  `k=sqrt(1+r²/d²)`）、`mapTine`（梳齿 `exp(−d/λ)`）、`mapSwirl`（高斯涡）、`mapFlow`（无散度
  curl 流场，颜料不堆积）——因此支持 **Rewind 倒放**与 snapshot/restore；
- **batik 蜡染**：真 3D 双色灯渲进 buffer——双灯都到=wax 留白、单灯到=染那色、蜡开裂；
- **长曝光玻璃底片**：每帧对曝光窗内多姿态积分——动体糊、静体锐，halation/乳剂边缘；
- **thermal 热成像**：顶点带 temperature/emissivity 而非颜色，8 种 palette=相机设置，
  可见光只贡献细白描边；
- **liquid light show**：噪声染带+metaball 油滴+真实遮光的黑色手绘透明片。
**范例**：opus-5.5-music-video-art-styles/styles/<name>/（18 个引擎文件夹，每个自带 lab/ 与 README）。

## 9. UI 拟物 / 复古操作系统（Win95）
**硬像素纪律**：禁 `ctx.arc/stroke/fillText`/渐变；文字光栅化后**阈值化成 1-bit** 缓存
（alpha≥128 才 255）；自带 Bresenham 线/扫描线多边形/50% checkerboard `dither()` 代替透明度；
ASCII 字符画 sprite 系统。widget kit：5 种 `bevel()` 斜面、窗口 opening 动画（先 dither 描边
zoom 再实体化）、全套 msgbox/dialog/menu/taskbar。**主题跟随叙事**：std→night→void→hotdog
随剧情推进。卡拉OK隐喻化：`select`（唱过的词=拖选文本蓝底）/`type`（打字机+块光标）/`color`。
CRT 管线一行：低清 canvas + ffmpeg `scale=1920:1080:flags=neighbor` + `drawgrid` 扫描线+vignette。
**范例**：pdoom-video-win95/src/core.js、ui.js、STORYBOARD.md。

## 10. 报纸档案 / 1-bit 印刷（jessecaple）
三色 INK/PAPER/RED + 8×8 Bayer 有序抖动（保 RED 通道的 `crunch()`）、撕纸横条位移、datamosh
矩形位移、红色 rubber stamp、**事实台账**（屏上每个数字/日期/引语有 source）、`textscan` 钩
fillText 扫描全片文字重叠。嘶吼文字 `screamText`：逐字母 jitter+echo 重影+尖刺碎片+每 0.24s
重启的外扩 echo 波+横向 slice glitch。
**范例**：jessecaple-pdoom-video/video/lib.js。

## 11. 纯排版驱动 MV（印刷世界）
**范式**：3D 透视相机"拍"平面排版——文字光栅化一次进 **atlas 缓存**（CanvasTexture+mipmap），
此后每帧只是 mesh 变换（"Text is rasterized once, never repainted each frame"）；
`text()/rect()/poly()/ribbon()` 四个原语都是 3D 空间中的平面；逐词状态内置（唱前 0.16s
淡入 0.14→1、演唱中变朱红）；post **关掉 bloom/halation**（印刷品不发光）只留 ca/grain/vignette。
导演法：每句歌词四个摄影状态（位置/注视点/roll/FOV）×三个连续阶段，节点从关键词或长音中点
取再 ±115ms 吸附节拍；**鼓声分工制**：kick=大层受力、snare=套印剪切、hat=细刻线碎屑、
vocal/bass=长音张力——"音乐不是一份统一脉冲"。铰链折叠=把世界一半绕真实铰接线折 90°。
交付 QA：全帧解码+音频相关性采样（>0.9998）+每词相机投影出框检查点+静止段筛查。
**范例**：pdoom-the-printed-world/app/src/scenes/mv-kit.ts、docs/MV-ACT3-MOTION.md。

## 12. 多风格统一管理（三种模式）
1. **叙事缝合型**（bohemian）：`G.STYLES[style]={ready, render, layer}` 注册表 + shot 带
   style 字段 + `G.CROSS(style,t,fn)` 池化透明画布**跨风格借角色**（把别的画风的 Claude 渲进
   池化画布裁切成纸偶）；一致性不靠画风靠**共享 running gags**（同一 `CTX(t)` 月相时钟、同一
   蝴蝶结、同色常量）；风格切换永远是"戏内事件"（幕布落下/换台/爆出）；
2. **工序比较型**（art-styles）：风格即引擎即文件夹，共享**页合同**
   （`window.__video={ready,step(t),renderAt(t),error}`）而非运行时代码；风格选择用 style lab
   （同 3-4 个时刻画进每个候选 look 并排比）；
3. **单风格参数分级型**：把媒介参数开放成逐 shot 配置（`paintSet({boil,bloom,strokeK,…})` /
   `FX:{roll,amt,reg,cell}`），切接时参数 lerp；媒介参数可承担叙事（套准=情绪）。
多 agent 生产共同点：导演写 core/渲染器/转场+参考章，N 个并行 subagent 按统一 brief 各负责
一个区间，contact sheet 审片+两轮返工，bug 回报而不许改共享文件。

## 13. Riso-cel 转描管线（AI 生成画面的媒介化）[GLSL]（anime-version）
**观感**：虚构 90s 赛博朋克动画 OP——AI 生成的动画面孔/动势 + 手印赛璐璐质感。
**第一原则**："Seedance/Seedream footage is **never shown raw**"——AI 生成素材只提供运动、
解剖与口型，观众看到的只有墨与纸。WebGL 转描流水线五级：
```
原始 AI 片段/静帧 → ① Kuwahara 滤镜（保边平滑+色块化 cel）
→ ② XDoG（Extended DoG）多 pass（动态手绘墨线轮廓）
→ ③ Riso 专色量化（nearest-ink 映射到受限墨盘）
→ ④ 45° halftone screentone（暗部 cel 程序网点）
→ ⑤ Boil on twos（12fps 手绘抖动）+ misregister（版错位）
```
配套手法：
- **每镜头允许墨盘** `PAL.{room,stage,gg,dc,sea,plug,pink,blue,red,mono,face}`——量化目标
  色板按场景切换（10–12 色含纸色），全片只有 7 种专色+终幕专属 ALARM 红；
- **注意装置清单**：首帧即全屏歌词+瞳孔火花（hook）；持续 HUD 年份计数器随歌加速（每小节
  数月→每拍数年→20XX→∞）+ P(doom) 表 8→34→61→86→99.9→ERR；每副歌重复同一"指手"签名
  动作（K-pop point dance）；歌词三级尺度 FULLSCREEN/SIDE/SUBTITLE 按段落切换；切率跟能量
  曲线（verse 3 起加快、breakdown 慢浮、outro 每拍一切）；EVA 风格 Mincho 黑白标题卡标段落
  （缩略图尺寸可读）；
- **三源 shot 分型**：SD=AI 视频基底 / IMG=AI 静帧+视差 / JS=纯 motion graphics——分镜表
  里每镜标注来源；
- **像素级口型同步**（mouthsync.mjs，25 行）：对口型搜索框内数"暗红口腔像素"（`l<0.33 &&
  r>g·1.35`）得嘴开度曲线，与 300–3400Hz 带通人声能量做互相关→**最佳 retime 滞后**——AI
  生成片段按歌曲重新计时而非信任其原始口型；
- 渲染：puppeteer `--use-angle=metal` 多 worker 可续渲 JPG 帧，`window.renderFrame(t)` 纯函数。
**范例**：Pdoom-video-anime-version/（README.md 管线图、STORYBOARD.md 逐镜表、studio/core.js、
mouthsync.mjs；注：tarball 快照，重素材未完整下载）。
