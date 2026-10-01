# platform-videograph.md — VideoGraph 平台适配

平台根目录：本仓库（权威交接文档：`HANDOFF.md`）。
两条执行管线共用同一套分析数据与审美法则，**写代码前先确认自己在哪条管线上**：

| | 路线 B：全引擎管线 | 路线 C：工坊 mini-engine |
|---|---|---|
| 入口 | `videograph-pdoom` MCP 的 `project_*` 工具 | 工坊前端卡片 / `shot_queue_*` MCP 工具 |
| 场景契约 | **Scene 类**（three.js + GLSL + Canvas2D 分层，pdoom 引擎同源） | **`draw(ctx, f, api)` 单函数**（纯 Canvas 2D） |
| 工程 | `projects/<uuid>/engine/`（完整引擎拷贝）+ `project.sqlite` + `artifacts/`（验证 png/mp4）+ `exports/` | 前端 `src/shot/`（engine.ts/runtime.ts/validation.ts）+ `src/shot/full-song.json` 数据集 |
| 转场 | 引擎级（参数化配置）+ 镜头自转场 | 无引擎转场——全靠相邻卡首末帧 handshake |
| 产物 | 编译+5 帧抽检 → 预览 → 整片 MP4 导出 | 卡片缩略图/预览/单段 WebM（MediaRecorder） |

判断方法：会话里挂着 `mcp__videograph-pdoom__project_*` 工具且用户在谈某个 PV 工程 → 路线 B；
用户谈镜头卡/工坊/队列/`draw` 函数 → 路线 C。两条都可能出现（工坊排版 + 全引擎出片）。

---

## 路线 B：全引擎管线（videograph-pdoom MCP）

### 工程结构

```
projects/<uuid>/
  project.sqlite          # 工程状态（镜头/版本/转场/反馈/任务）
  engine/                 # 引擎完整拷贝（app/src/engine|scenes、data、audio、docs）
  artifacts/<hash>.{json,png,mp4}   # 验证抽帧/导出产物
  exports/<uuid>/         # 成片
```

### 场景契约（= pdoom 引擎，与 `engine/docs/ENGINE.md` 一致）

- 文件 `engine/app/src/scenes/<name>.ts`，默认导出 `extends Scene` 的类；
  `render(f: Frame, out)` 必须完全覆盖 out（HalfFloat 线性 HDR），返回 PostOverrides。
- 工具：`FSPass`（全屏 GLSL3，自动前置 GLSL_COMMON：调色板常量/hash/snoise/fbm/SDF/smin/
  hatch/engrave/heat/aaFill/aaStroke/pxLine/heat）、`Layer2D`（Canvas2D 层，`comp.draw` 合成，
  mode normal/add/screen/multiply/max）、`LineBatch`（GPU 胶囊线段 seg2/polyline，1 万–20 万段）、
  `type.ts` 字体（Archivo 可变宽度 62–125/权重 300–900、IBM Plex Mono、Cormorant）、
  `stroke.ts` 单笔画字体、`_motifs.ts` 火花/面具。
- Frame：`f.t/lt/p/a(六路包络+kick/snare/hat/vonset)/beat/beatPhase/bar/under/tin/tout`。
- **本 skill 的 effects.md/shots.md 全部手法在路线上 B 原样可用**（范例代码就在
  `engine/app/src/scenes/` 里，直接照抄模式）。

### 工具链工作流（按序，勿跳步）

<!-- BEGIN:generated-from-MCP-GUIDE (scripts/skills/sync-platform.mjs 自动生成；勿手编) -->

**工具速查（自动生成自 `docs/MCP-GUIDE.md` §3，toolset 2026-10-02；勿手编——更新请跑 `node scripts/skills/sync-platform.mjs`）**

| 工具 | 参数 | 作用 |
|---|---|---|
| `project_list` | — | 本地工程列表 |
| `project_create_from_bgm` | `audioPath` | **当前只支持 pdoom-video 原始 BGM**（字节指纹匹配，复用已对齐分析，标记为参考导入）；其他音频返回 422。任意歌曲见 §… |
| `project_get` | `projectId` | 完整工程：镜头、转场、意见、版本、输出规格。默认只返回歌曲摘要，`includeAnalysis: true` 返回完整词级歌词/节拍/包络 |
| `project_shot_lyrics` | `projectId, shotId` | 镜头窗口内词级歌词、`instrumental` 标记、已有 `lyricPlan` |
| `project_shot_source` | `projectId, shotId` | `{ shot, code, contract, lyricContext, source }`：当前真实 TS 源码与完整引擎契约（ENGI… |
| `project_shot_update` | `projectId, shotId, expectedInputRevision, patch` | patch 仅允许 `title / prompt / params / lyricPlan / locked`。改 `prompt` 或 `… |
| `project_shot_submit` | `projectId, shotId, expectedInputRevision, code` | 提交**完整**场景文件（无 markdown 围栏），可带 `summary`、`feedbackResponses: [{ feedbac… |
| `project_feedback_add` | `projectId, shotId, expectedInputRevision, text` | 新增镜头意见（≤8000 字符），可带 `anchor`（`t/range/lyricElementId/region/aspect`，服务端… |
| `project_transition_get` | `projectId, transitionId` | 转场节点、意见、配置、前后镜头元素方案、准确时间窗 |
| `project_transition_update` | `projectId, transitionId, expectedInputRevision, patch` | patch 仅 `intent / locked`；新 intent → `needs-generation`，需随后 configure |
| `project_transition_configure` | `projectId, transitionId, expectedInputRevision, config` | `config: { mode, duration ≤1.5, easing, direction }`，可带 `feedbackRespon… |
| `project_transition_feedback_add` | `projectId, transitionId, expectedInputRevision, text` | 新增转场意见（可带 `anchor/preserve`，锚点窗口为前后镜头合并窗口），同时冻结两侧镜头版本 |
| `project_transition_validate` | `projectId, transitionId` | 后台抽检切点前后 5 帧，返回 job |
| `project_feedback_inbox` | — | 可选 `projectId`、`status`（默认 `pending`；`open` 为全部未接受）。agent 的入口：返回每条意见的目标… |
| `project_feedback_ask` | `projectId, targetKind, targetId, feedbackId, question` | 意图含糊时向人提问：意见转 `needs-clarification`，人回复后回 `pending`；提问不改输入版本。AI 不能替人回复 |
| `project_stills` | `projectId`（另需 `shotId` 或 `transitionId`） | 可选 `times`（≤6 个、须在目标时间窗内；默认 = 未接受意见锚点 t + 窗口 0/0.5/1）、`version: current… |
| `project_preview` | `projectId` | 可选 `shotId / transitionId / version: current|before-feedback`。返回本机真实引擎播… |
| `project_validate` | `projectId, shotId` | 后台编译 + 5 时间点抽检，返回 job；完成后镜头 `validation.thumb` 指向 `artifacts/<key>.png`… |
| `project_render` | `projectId` | 可选 `fps: 24/30/60`、`samples: 1/4/12`。后台导出完整 MP4，冻结当前版本，命中分段缓存 |
| `project_job_get` | `projectId` | 可选 `jobId`；省略则列出最近任务。看 `status / progress / error / result` |
| `project_job_cancel` | `projectId, jobId` | 取消排队或运行中的任务 |

硬规则：AI 不能接受意见。 只改目标：`project_shot_submit` 只作用于一个镜头并生成不可变的新源码文件；不要借响应一条意见顺手重写其他镜头。 保留原始意图：不要用 `project_shot_update` 把人的意见写进 `prompt` 覆盖原文；意见本身已单独保存。 锁定的镜头/转场必须由人解锁后才能修改；不要自行解锁来完成任务。 时间一律从分析数据推导（词起点、拍点），不在场景代码里硬编码秒数。 有未接受意见或 `needs-generation` 的镜头/转场时，`project_render` 会被拒绝，这是预期行为。
<!-- END:generated-from-MCP-GUIDE -->

1. `project_list` / `project_get`：读工程、镜头卡片（id/标题/时间窗/提示词/状态/当前版本）。
2. `project_shot_lyrics`：读目标镜头窗口内的**词级歌词**；同时把视觉构思写成 `lyricPlan`
   （summary + elements[]，每个 element = `{kind: entity|action|metaphor, quote, meaning,
   treatment, cueWord?}`——**quote 必须是真实歌词原文，会被校验**），用
   `project_shot_update` 保存。先想清楚"这句词怎么变成画面"再动代码。
3. `project_shot_source`：读该镜头**当前真实 TS 源码 + 完整引擎契约**。改代码基于它，不要凭空写。
4. `project_shot_submit`：提交**完整文件**（不带 markdown 围栏），必须带
   `expectedInputRevision`（并发控制；revision 不匹配先重读）。保存为不可变新版本、标记待验证。
   若本次修改响应了某些 pending 反馈，把反馈 id 放进 `addressedFeedbackIds`——注意这只是
   "已响应"标记，**是否采用由用户在界面确认**。
5. `project_validate`：后台编译+抽检 5 帧 → `project_job_get` 查结果（错误/静帧地址）。
   **通过 ≠ 审美通过**——用 `project_preview` 人工看，`artifacts/` 里的 png 用 Read 看。
6. 转场：`project_transition_get` 读相邻镜头间的转场节点与准确时间窗；
   `project_transition_configure` 配置 `{mode: cut|dissolve|wipe|dip, duration ≤1.5s,
   easing: linear|smooth, direction: left|right}`——**新配置需预览验证**；
   `project_transition_validate` 抽检切点前后 5 帧；指导性意见走 `project_transition_update`
   （新的指导标为待配置，不会假装效果已变）。
7. 反馈回路：人的修改意见经 `project_feedback_add` 成为独立反馈节点（保留原始 prompt 与
   修改前版本，只影响目标镜头）；改代码时在 submit 里带上 `addressedFeedbackIds`。
8. 出片：`project_render`（fps 24/30/60，samples 1/4/12）后台导出 MP4 → `project_job_get` 查进度。
   锁定（locked）镜头要先 `project_shot_update` 解锁才能改。

### 路线 B 铁律

- 提示词（prompt）修改后**必须重新提交代码**（提示词与代码是一对的）。
- 不覆盖其他镜头、不覆盖原参考实现——submit 只作用于目标镜头且产生新版本。
- 验证/渲染都是后台任务：提交后轮询 `project_job_get`，不要并行提交同一镜头多版本。
- 词/拍时间一律来自 `ctx.lyrics / ctx.audio`（`lyrics.get(文本).words[i].start`、
  `audio.timeOfBeat/beatAt/events`），绝不硬编码秒数——换 BGM/换对齐数据就全崩。

---

## 路线 C：工坊 mini-engine（`draw(ctx, f, api)`）

### 契约（注入给生成器的唯一接口，源：`src/shot/engine.ts` + `codegen.ts ENGINE_CONTRACT`）

```ts
export function draw(ctx: CanvasRenderingContext2D, f: Frame, api: Api): void
```

**Frame f**（所有时间是全曲秒）：
- `f.t` 全曲时间；`f.lt` 镜头内局部时间；`f.p` 0..1 镜头进度
- `f.W, f.H` 画布逻辑尺寸（可能是 1920×1080 或更小的预览）——**布局全部用比例推导，绝不硬编码像素**
- `f.audio`: `{ rms, low, mid, high, vocal, drums }`（0..1 包络）+ `{ beat, downbeat }`
  （**衰减脉冲 1→0，halfLife≈0.14/0.22s——不是拍号！要事件数组用 api 的**）+ `{ beatPhase }`（0..1 拍内相位）
- `f.lyric.lines`: 本窗口内歌词行（已过滤，±0.15s 容差），每行
  `{ text, start, end, words: [{ w, start, end }] }`

**Api api**：
- `api.palette`: ink/ink2/graphite/ash/bone/**signal**/ember/blood/acid（hex 字符串）
- `api.ease`: `{ outExpo, inOutCubic, inOutQuad, outBack }`
- `api.rng(seed)` → 确定性随机函数（mulberry32）
- `api.clamp / api.lerp`
- `api.wordProgress(word, t)` 词进度 0..1 —— **卡拉OK上色的唯一时间来源**
- `api.lineCharProgress(line, t)` 整行已唱字符数（含小数，逐字符擦除用）
- `api.pulse(t, events, halfLife=0.14)` 事件脉冲（t 之前最近事件按半衰期衰减）
- `api.beatEvents / downbeatEvents / kickEvents / snareEvents` 本窗口内事件数组（配 pulse 用）

**七条硬规则**（违反会被验证门打回）：
1. 纯函数：输出只依赖 f 和 api.rng 种子；禁 `Math.random()/Date.now()/performance.now()`。
2. 禁 import、fetch、动态导入、外部图片/字体资源；只用 Canvas 2D。
3. 每帧先铺背景（fillRect 覆盖全画布），save/restore 配平。
4. 字体只用系统栈 `'Arial, sans-serif'` 或 `'monospace'`，字号用 f.H 比例。
5. 卡拉OK：未唱 bone 30% 透明度、已唱 bone、唱中 signal 橙；**绝不跑在人声前面**。
6. 大变化落在拍上（`f.audio.beat/downbeat`、`api.pulse`）；重音用 signal/ember 辉光
   （`shadowBlur + shadowColor`）。
7. **代码 ≤120 行**，输出一个 ```ts 代码块 + 一行 `SUMMARY: <一句话>`，别无其他。

### 验证门（提交后自动跑，源：`src/shot/validation.ts`）

`lint 静态约束 → compile（sucrase 转译）→ render 抽检 5 帧`（进度 0/0.25/0.45/0.75 + 末帧−1/30，
400×225，第 3 帧当缩略图）。失败自动回喂修复 **≤2 次**（诊断+上一版代码一起回给生成器）。
抽检只保证"不崩、每帧有内容"——审美仍要人/agent 看缩略图与预览。

### 队列协议（前端无 LLM API key 时，agent 就是生成器）

1. `shot_queue_list`：列出待处理请求（req-*.json）。
2. `shot_queue_get(id)`：读完整 prompt（system=角色+美术基调+引擎契约；user=卡片+窗口+词级歌词
   +音频特征+mini 范例）。
3. 自己按契约生成，`shot_queue_submit(id, content, model?)`：
   - **plan 请求** → content = JSON 数组文本（按 user 里的 schema：镜头卡列表，含锚行/窗口/提示词）
   - **codegen 请求** → content = 一个 ```ts 代码块 + 一行 `SUMMARY: <一句话>`
   提交前自查：符合七条硬规则、JSON 可解析、无 import、≤120 行。
4. 无法生成/违规 → `shot_queue_reject(id, reason)`。
- 工具侧卡片读写：`shot_cards_read`（id/标题/时间窗/提示词/状态快照）、
  `shot_cards_update_prompt(cardId, prompt)`（改提示词，卡片转"待重算"，前端热合并）。

### mini-engine 惯用模式（120 行预算内的高质量写法）

- **行数分配**：铺底+构图 ~10 行；主角动效 ~50 行；卡拉OK ~20 行；节拍冲击/辅助装饰 ~20 行；
  留 ~20 行余量。**一卡一主角**——effects.md 选 L0 手法里的一条做深，不要堆三个弱效果。
- **卡拉OK标准写法**：`for (const w of line.words)` + `api.wordProgress(w, f.t)` 三态上色
  （0→bone α0.3，(0,1)→signal，≥1→bone）；逐字符擦除用 `api.lineCharProgress`。
- **拍冲击**：`const k = api.pulse(f.t, api.downbeatEvents, 0.14)` → scale/位移/shadowBlur 乘 k；
  sweep 用 `f.audio.beatPhase`（0..1 拍内相位做扫描线/进度环）。
- **确定性布置**：`const r = api.rng(7)` 在函数顶部一次创建，循环内取值——每帧同序列=确定性。
- **辉光**：`ctx.shadowColor = api.palette.ember; ctx.shadowBlur = 10..24`，用完清零；只给
  signal/ember 元素。
- **hairline**：`lineWidth = Math.max(1, f.H * 0.0015)` 一档；排线版画=for 循环 stroke 平行线，
  alpha 随"明暗"变化。
- **比例布局**：一切坐标写成 `f.W * 0.x / f.H * 0.x`；字号 `Math.round(f.H * 0.06)` 级。

### 路线 C 已知坑

- `f.audio.beat/downbeat` 是**脉冲**（1→0 衰减），不是连续拍号——要"第几拍"用事件数组自己数
  （`api.beatEvents.filter(e => e <= f.t).length`）。
- `f.lyric.lines` 只含窗口 ±0.15s 的行；预览画布可能小于 1920×1080，别按绝对像素排。
- 生成代码经 sucrase 转译；别用太新的 JS 语法特性，别依赖 DOM（只给 ctx/f/api）。
- vite 配置改动需重启 dev server（5188）；外部直接改 cards.json 有与前端防抖保存的竞态——
  改卡片提示词走 `shot_cards_update_prompt`，不要手改文件。
- 会话启动时加载的 MCP 工具集是旧的：要用 shot_* 工具而列表里没有 → 重连 MCP/重启会话。

---

## 手法降级矩阵（effects.md → 两条管线）

| effects.md 手法 | 路线 B 全引擎 | 路线 C mini-engine |
|---|---|---|
| A 全帧后期（bloom/halation/CA/grain） | 引擎内建，返回 PostOverrides | 无后期链：辉光用 shadowBlur、颗粒可省略或每帧少量随机点（以帧号为种子）、晕影用径向渐变 |
| B 自适应子帧运动模糊 | 引擎内建（守三规则即可） | 无子帧：快速运动自己画 2–4 份时间偏移残影（α 递减） |
| C 火花系统 | `_motifs` 直接用（LineBatch） | Canvas2D 版：径向渐变头 + 'lighter' 短线段粒子（出生钟模型照抄，rng 种子驱动） |
| D1 hatch/engrave/heat | GLSL_COMMON 现成 | clip+平行 stroke；heat 用色表插值 |
| D2 fwidth 图表线 | 直接用 | 折线 stroke + 密集时降 alpha |
| D3–D5 G-buffer/实体光照/抗摩尔刻线 | 直接用（raymarch 板） | 不可用 → 预生成排线离屏层 + 遮罩位移；或改用线框/剪影语言 |
| D6 纸墨/印章/撕纸 | 直接用（通道编码+Beer-Lambert） | 分次直接绘制多"墨色"模拟叠印；撕纸=两块 clip 各自 transform+锯齿边路径 |
| E 卡拉OK十二变体 | 全部可用 | clip wipe/书写模拟（自己造单笔画折线）/弧排（rotate 摆字）/字宽跳变（用系统字体粗细档模拟）可用；可变字体轴、opentype 轮廓、3D 双通道字不可用 |
| F 相机系统 | 全部可用 | UI 空间 setTransform 相机 / Shot 表 / match-cut 锚定 / 冲击语法可用；CPU pinhole 可做但注意线段预算（<5k 段） |
| G 确定性时间/模拟 | 全部可用 | 全部可用（构造期=闭包内首次调用时惰性建表并缓存到模块级变量——仍确定性，因为只依赖种子） |
| H 仪表/图表 | 全部可用 | 全部可用（odometer 用 clip 窗滚鼓式） |
| I 大场面 | 按 [GLSL]/[3D] 标注可用 | 只可用 [2D] 行（分支爆炸/碎裂/生长/时间重映射/字形形变/倒带/strobe） |
| J 参数量级 | 直接用 | 直接用（flash 概念换成一次性全屏 bone 叠加 α，0.05–0.3） |

> 通用降级心法：L1/L2 手法落到 L0 时，保**时间结构**（同样的 ease/脉冲/前沿），牺牲**介质精度**
> （shader 换分层绘制、raymarch 换预生成+位移）。观感的 80% 来自时间结构与配色纪律，不是渲染精度。

## 数据集（两条管线同源）

`src/shot/full-song.json`：`{ song, bpm, duration, envFps, lines[](词级), sections[], beats[],
downbeats[], kick[](强度对), snare[], rms/low/mid/high/vocal/drums[] }`——从 pdoom-video 的
data/*.json 切出。规划器复用 pdoom 的切点逻辑（`cutAtLine/afterLine/findLine`）。
换歌 = 重新生成该数据集，契约不变。
