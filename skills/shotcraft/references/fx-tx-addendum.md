# fx-tx-addendum.md — 特效与转场增补（25 个 Opus 5.5 视频仓库蒸馏）

对 `effects.md` / `transitions.md` 的增补：只写原手册没有的手法。范例路径相对
本仓库外语料（清单见 [SOURCES.md](../SOURCES.md)）。原有条目（卡拉OK状态机/火花/odometer/handshake 等）不重复。

---

## A. 特效增补

### A1. boil 系统（手绘"线沸腾"——手绘感的时间维度）[2D]
- 基础：`randomSeed(1000 + floor(T·BOIL))` 全局 12fps 重播种 + `jit(a)` 逐几何点抖动——
  所有线条像手绘动画一样持续微沸（PDoomVideo/src/core.js:19,194）。
- **`boilSeed(key)` 防串扰**（ClaudeAnimationBase/src/core.js:26）：一个运动元素消耗随机流会让
  其后所有静止元素每帧跟着沸腾——每个背景层/道具/角色部件独立 FNV hash 种子，用完复位。
- **`onTwos(t)`**：`floor(t·12)/12` 把整镜量化到 12fps，模拟手绘"拍二"；shader 侧
  `uBoil = floor(t·boilRate)%251 + i·300`（functional-emotions paint.js:151）。

### A2. 颜料系发光两式（"颜料不会发光"约束的解）[2D]
- p5.brush 混色画不出光（黄叠蓝变绿）→ ① 256px 径向渐变纹理 `blendMode(ADD)` 贴片
  （ClaudeAnimationBase `glow()`，且画在 paper grain 之下）；② 低透明度水彩 fill 大圆当
  halo（PDoomVideo 红眼光环）。three.js 后期管线不存在此约束——这是媒介决定的差异。

### A3. 跨界新特效（three.js 系仓库的新招）
- **GLSL/JS twins 地形**（context-window s13_keystorm.ts:306）：每次击键落一排 token 字符
  堆成 voxel 地形，GLSL shader 与 JS `height()` 双实现一致（JS twin 供相机落脚点采样），
  相机 keys 表垂直俯视→俯冲→低空盘旋；
- **液压机压字**（context-window s09）：opentype 文字几何被压扁，每唱一次压一冲，弹簧
  squash `0.14·exp(−d/0.07)·cos(2πd/0.2)`，缝里喷字形；
- **套印错位层**（context-window s02）：口吃的词用 signal 填充层+骨白描边层逐层 slip，
  offset 在事件上 snap；
- **参数化损坏 hook**（context-window shared/hook.ts）：HookScene 基类 `damage` 参数
  （0/0.4/1）统一缩放 ▒ 字符替换、排版错位帧、撕裂条、RGB split、计数器损坏——一版代码
  演三个升级档；
- **flash 安全**（jessecaple）：`allowedHit()` 贪心抽稀 onset 保证全曲任意 1 秒 ≤3 次亮度
  翻转（Harding 光敏性癫痫测试，video/tools/flashcheck.py 验证）；
- **chaos 强度公式**（jessecaple engine.js:65）：`chaos(t)=(段落混乱度·0.8+实测 intensity·0.3)
  ×情绪倍率`——特效强度从实测音频数据闭式算出，而非手写节拍表。

### A4. 双语/音节级卡拉OK [2D+数据]
- **`to[]` 索引数组**（Zh-CN-pdoom-video data/lyrics.zh.json）：`{zh:["我看见","AGI 的火花"],
  to:[1,4]}`=第 k 段中文对应到最后一个英文词 index——译文按语义切段而非词对词，点亮节奏
  严格跟英文逐词时间；`claim()/glyphState()` 让每板认领自己的行画进原构图，未被认领的行走
  七个安全槽位+占用评分选位；`VOICES` 语域配对表（思源宋体配 Cormorant、思源黑 900 配
  Archivo 900）；字体子集脚本从"全部译文+扫描源码所有中文字符串字面量"生成；
- **`Intl.Segmenter('zh-CN',{granularity:'word'})` 中文分词**（StuGRua whale-localization.js）；
- **音节时间 `syl` 的最低成本来源**（pdoom-video-fr）：发音词典把缩写拼读成罗马化子词
  （`"P(doom)":"pe doum"`、`"NVDA":"en ve de a"`）→ 子词对齐天然产出音节时间戳，场景直接取
  `syl[1][0]` 做 "doum" 落地时刻；
- **双语校验**：加载时 `cues[i].en !== LY[i][2]` 即抛错——字幕与歌词强一致。

### A5. 渲染工程特效（确定性渲染器的工业层）
- **内容指纹帧缓存**（StuGRua render_whale.cjs:20）：`sha256(入口HTML+所有script+字体+资产
  逐文件sha+参数)` → 帧目录隔离 → 同指纹续渲安全；
- **多浏览器并发**：默认 6 个独立浏览器实例（每 worker 单独 launch），Vulkan/D3D11 ANGLE
  后端断言；3759 帧 1080p24 约 5 分 46 秒；
- **严格编码 gate**：ffmpeg `-v error -xerror` 且检查 stderr 非空 → ffprobe 断言帧数/分辨率
  /fps → 全流 decode 验证 → 才 rename 发布；
- **`--verify` 确定性验证**：乱序重绘同一 t 两次断言 buffer hash 相同；
- **memo/LRU**：昂贵静态层缓存（shot 间可引用其它 shot 的缓存 canvas）；`page.screenshot`
  优于 toDataURL（大画布）；PNG 帧直通 x264（halftone 类高频纹理比 JPEG 存活好）；
- **帧级截图时间 shim**（videowright src/cli/time_shim.ts）：两模式虚拟化
  `Date/performance.now/setTimeout/RAF/WAAPI`——浏览器内容确定性逐帧导出的完整参考实现。

## B. 转场增补

### B1. 手绘系转场 [2D]
- **brush wipe**（PDoomVideo timeline.js:70）：5 条粗颜料带左右扫过，p=.5 全遮盖时切场景
  再拖出，lead 边是 ragged 碎毛边+charcoal hatch——遮挡式切换比叠化更"手翻书"；
- **motivated transitions**（PDoomVideo STORYBOARD.md 规则）：嘴形 iris（`irisShape` 星形洞
  外填充，从嘴内开牙齿门）、chomp-to-black、火箭上升连续 tilt-up（相机跨"世界"跟随）、
  iris 收缩到黑；
- **舞台化转场注册表**（bohemian transitions.js）：`TX[type](ctx, A, B, k, opts)` 12 种——
  curtain（40 条波纹毡幕+脚光）、pixelate（2 的幂降采样崩解）、不对称 iris（闭在眼上开在
  typing dot 上）、echo（A 缩旋成镶框板、B 带 Droste 拷贝爆出）、filmburn（9 种子热点圆形
  扩张）；转场窗口内 A/B 各渲进缓冲再混合。

### B2. 印刷系转场 [2D]
- **riso feed**：新纸从上滑下把旧纸推进托盘，**新纸的墨在滑入过程中分色逐滚筒印上**
  （转场 override `FXO.roll` 三鼓错相）；**flip**：270 条带铰链卷曲，积分每条带 Y/Z 透视与
  bend 明暗；纸的装订边/edition 号永远钉在画框上不动；
- **声明式进入转场**（jessecaple motion/plan.json）：7 种——hard cut（默认，落在首唱词/
  downbeat）、tear-wipe、slam、crash zoom through、stutter（16 分音符新旧交替）、freeze
  （band stop 全冻结）、1-bit dissolve（ditherMix）；硬规则："band 停画面停"、"真实伤害新闻
  永不 shake/tear"。

### B3. 引擎系新招 [GLSL]
- **HANDOFF 表**（power-video _power.ts:100）：登记每板最后一帧的形状位置（蓝点坐标/总线 y/
  滚转角），下一板第一帧从该形状接续展开——比 pdoom 原版的字面常量拷贝更系统化；
- **`CUT_LEAD = 1/60`**（context-window shared/hook.ts:39）：所有剪点提前一帧——音节落地时
  画面已就位（对齐感知的剪点微调）；
- **timeline 全锚点可选**（power-video timeline.ts:42）：`tryT()` 包 try/catch，锚点丢失则
  entry 跳过、前板顺延——剪歌后时间轴自动降级不崩；锚点类型化 `{section}|{cut:lyric,nth,div}`，
  `div` 支持 8 分/16 分音符网格；
- **`f.under` 自定义转场**（context-window timeline.ts:40）：`TransitionSpec {kind:
  cut|crossfade|custom, beats, align}`——custom 时 incoming 场景拿到 outgoing 帧纹理自己合成
  （"被选中→压缩"这类跨切连续动作）；
- **禁 cross-dissolve**（Claude-Opus-5.5 skill 04-storyboard.md）：叠化读成 slideshow 且糊掉
  节拍——转场四式 impact 白闪/push through/rush/slam 16% scale punch；视觉比旁白**早 ~100ms**。

### B4. 转场参数化通用件
- `paintSet(o)/whip(dx,dy)` 全局信箱（functional-emotions lib.js:172）：shot 内逐帧覆写渲染器
  参数，让"内容层"驱动"媒介层"（whip smear 盖切点）；
- 转场时媒介参数 lerp（boil/bloom/flowK/套准在切点两侧数值过渡，functional-emotions main.js:16）；
- **章节表+shot 表两层时间轴**（PDoomVideo）：9 章 `chapter(name,start,end,[[t0,fn],…])`，
  每 shot `fn(t,lt,dur)` 纯函数——帧并行乱序渲染的合约就是签名。
