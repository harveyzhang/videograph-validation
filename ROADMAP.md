# VideoGraph 总体计划与进度

> **唯一计划文档。** 自 2026-09-30 起，所有后续架构、阶段任务、优先级和验收计划均在此维护；不再建立并行的 TODO/阶段规划文件。HANDOFF 只放运行、交接说明并链接这里。
> 状态约定：✅ 已实际验收；🚧 实现/验证中；⬜ 尚未完成。写出代码不等于完成。

## 一、产品目标与不变原则

服务 **ToB 产品宣发** 与 **C 端音乐人 PV**。以 `pdoom-video` 这类优秀 AI 创作工程为参照，做仿 ComfyUI 界面的创作产品，使工程可以稳定复现，人可以准确操作其中的镜头。

当前端到端目标：只提供该参考工程的 BGM，由 agent 通过 MCP 创建工程、操作镜头、校验预览，最终导出完整 PV。工程复现与“从零原创”必须区分；审美上的满意需要成片反馈，不能用“没有报错”代替“完美”。

**用户于 2026-09-30 确认的执行顺序：先完整复现 → 再用同一首歌独立创作自己的 PV → 对人类与 AI 共用的整个产品做交叉检查、修复问题并持续优化。** 两支成片使用独立工程与明确署名；不能只修改提示词、复用原画面就宣称完成独立创作。

1. **节点画布是核心，不是装饰。** 节点/连线对应真实输入、计算、产物和依赖；镜头带、时间线、参数面板和预览只是协同视图。
2. **人工意见是一等输入。** AI 生成整个工程后，必须按镜头/共享资源/风格/输出拆分，方便人添加针对性意见，不必推翻整片。
3. **保存工程而不只是提示词。** 源码、素材、字体、参数、时间轴、依赖版本、种子、引擎与渲染设置均可追踪。
4. **真实工程的表现力不能被模板限制。** Canvas 模板只用于测试/兜底；原始 Three.js、GLSL、字体轮廓、后期能力要能够接入。
5. **音乐是一个应用场景。** ToB 的品牌资料、产品卖点、旁白/脚本与音乐人的歌曲/歌词/节拍共享工程核心；歌词不是所有工程必填项。
6. **诚实标记来源与边界。** 参考源码、MCP 新写源码、缓存分析、重新分析、技术验证、人工接受，分别标记。
7. **本地优先、渐进迁移。** 不整仓重写，不动参考仓库；初期一个模块化服务和渲染子进程，不提前上微服务、Redis、K8s、插件市场或多人协作平台。

## 二、当前进度

### ✅ A：单镜头任务可靠性

- 已从工坊抽出卡片领域模型、生成协调器、执行通道和 MCP 客户端。
- API/MCP 共用静态检查、编译、5 时间点运行抽检与最多两轮修复。
- 输入编辑版本与成功产物版本分离；取消、编辑、同 ID 重规划会隔离旧结果。
- 失败不覆盖上一份有效产物；旧版本不冒充新输入结果。
- 修复批量 API 误走模板、ReactFlow 状态更新导致节点隐藏、favicon 404。
- 构建及六项回归通过；新增验收使用 mock API/队列，不花费真实模型额度。

### ✅ 原引擎接入验证

- 不修改 `pdoom-video`，在本产品中启动真实引擎。
- 已在 Windows + Edge + AMD GPU 上验证 1920×1080 静帧、原字体与场景/后期；引擎验收无错误。
- 已获本次开发的依赖安装、参考引擎运行及本地 MCP 代码渲染服务授权。

### 🚧 B/C：真工程 + 后台完整 PV

- 已实现 SQLite 工程/历史/任务、独立引擎副本、内容指纹、源码不可变版本。
- 已通过真实 MCP stdio 调用，仅以原始 BGM 路径创建一个 22 镜头工程。
- 已通过 MCP 发起真实镜头后台验证并完成 5 帧抽检。
- ✅ 完整参考版 1080p30 MP4 已生成：22 镜头、4700 帧、156.6667 秒、H.264 + AAC。
- ✅ 已用 ffprobe 核对帧数/音轨/时长，ffmpeg 全片解码无错误；导出音轨与源 BGM 的零偏移相关系数 0.999944。
- ✅ 第二次相同规格导出 22/22 分段缓存命中；参考工程 ID `62a1d69e-14a4-4012-984b-d6a18a62a58f`，成片任务 `cfa2128b-6596-4b4c-9d13-c7a10366b67f`，缓存验收任务 `8c7994af-b065-43c9-b375-7a06ab382b38`。
- 新工程节点界面已接入并通过构建；刷新恢复、服务重启、MCP 热更新的完整 UI 回归待完成。

### 🚧 独立创作：《THE LAST AUDIT / 最后的审计》

- 仅通过 MCP 提供原始 BGM 路径创建独立工程 `052d3bd1-dd0b-41fd-8775-e21468fb9163`，不改动参考复现工程。
- 复用：已对齐的音乐数据、字体和原渲染引擎。新写：整片审计装置失控的视觉叙事、所有镜头场景代码与设计参数。
- 新画面采用机械光圈、文件堆叠、折叠结构、审计印章、穿孔引信、递归档案等设计；保留词级同步与克制的色彩体系。
- 尚待：逐镜头技术/视觉检查、完整成片、署名/源码来源核验、与参考片的区分及全产品人/AI 操作审查。

### 🚧 歌词元素分析与独立转场（用户新增要求）

- 每镜头保存歌词证据、含义分析、具象/隐喻元素与视觉处理理由；引用必须来自该镜头实际歌词，不能仅按统一风格填充抽象图形。
- MCP 的镜头上下文提供窗口内词级歌词与元素方案；源码提交仍须绑定输入版本，元素方案本身不冒充视觉验收。
- 优先修正原创片中的关键语义：火花/电路、中文房间与蘑菇、怪物与眼睛、原子重排、月亮/算力、GPU/围栏等。
- 转场作为两个相邻镜头之间的一等实体与节点，独立保存指导意图、类型、时长、版本、锁定与意见；首版提供硬切/溶解/方向擦除/暗场过渡。
- 转场预览与导出使用同一渲染实现；只影响相邻边界的依赖，不能变成装饰连线。保持全曲总帧数和音轨时间不变，不提前展示尚未唱出的歌词。
- 验收：错误歌词引用拒绝、转场参数边界/版本保护、真实双镜头过渡、转场修改只使相邻合成缓存失效、人与 MCP 都可读取和指导。

### 🚧 人工修改意见闭环

- 正在增加独立修改意见节点、版本绑定、响应/接受状态、修改前后预览。
- 当前已写部分后端，尚未完成端到端验收。

## 三、最近要按顺序完成的任务

### 当前冲刺（2026-10-01 起，最高优先）：人工意见 → MCP 定位 → 改写视频代码

目标：人在节点界面针对某个镜头/转场写意见，能指明**哪里**（时间点、歌词元素、画面区域）要改、**什么**必须保留。agent 通过 MCP 一次拿到所有待办，看到对应画面，修改场景源码，逐条说明怎么响应，最后由人对比后采用。同时把蒸馏出的 shotcraft skill 纳入仓库，经 MCP 提供给 agent。

现状（已有，勿重写）：意见 `pending → responded → accepted`、`reviewBaseline` 冻结与拒绝回滚、`addressedFeedbackIds`、修改前预览、导出拦截未接受意见（`project-store.mjs`、`ProjectStudio.tsx`、27 项测试通过）。缺口：意见不能定位；agent 只能遍历 `project_get` 找意见；MCP 无法返回画面；响应无逐条说明；agent 无法提问澄清；skill 在仓库外（`C:\Users\Martis\.zcode\skills\shotcraft`），与平台说明会分叉。

**执行顺序与依赖：** `INT-00 → FB-01 →（FB-02 ∥ FB-03 ∥ SKILL-01）→ FB-04`。FB-01 定义数据契约，其余按它开发；FB-02/FB-03/SKILL-01 文件范围不重叠，可并行。

#### ✅ INT-00 收尾当前工作区（集成者，2026-10-02 完成：commit `4035ebe`）

- 现有 12 个已修改 + 4 个未跟踪文件（端口/Origin 可配、令牌在 listen 成功后写入、镜头预览按帧对齐区间、转场帧对齐、`transition-integration-audit.mjs`、`docs/THIRD-PARTY.md`、`.env.example`）。
- 跑 `npm run build`、三组 `node --test`、`node scripts/transition-integration-audit.mjs`；通过后在 `feat/lyrics-transitions` 提交，再从它切 `feat/feedback-anchors` 等分支。
- 验收：`git status` 干净；审计输出已记录在本节。
- 结果：`npm run build` 通过；`node --test` 全部领域测试通过（含 ASSET-01、SKILL-01 新增测试）。**`transition-integration-audit.mjs` 未运行**：它需要独立的 5288/5291 实例与 GPU，而本机 5288/5291 正被另一会话占用，不能共写同一实例；待独立实例空闲后补跑，补跑前转场 UI 集成仍算 🚧。

#### ✅ FB-01 意见数据契约与后端（2026-10-02 完成；独占 `src/server/feedback.mjs`（新建）、`scripts/tests/feedback/`；在 `project-store.mjs`/`index.mjs` 只做最小接线）

1. 新建 `feedback.mjs`，将意见校验与状态迁移从 `project-store.mjs` 抽出（行为不变，先让现有 27 项测试保持全绿）。
2. 意见新增可选字段（旧数据缺字段仍合法，无需迁移）：
   - `anchor`: `{ t?: number, range?: {start,end}, lyricElementId?: string, region?: {x,y,w,h}（0..1 归一化）, aspect?: 'composition'|'motion'|'typography'|'color'|'timing'|'lyrics'|'other' }`。服务端校验：`t`/`range` 必须落在目标镜头窗口（转场则在其时间窗）内；`lyricElementId` 必须存在于当前 `lyricPlan`；`region` 各值在 0..1。
   - `preserve: string[]`（≤12 条，每条 ≤300 字）：必须保留的内容。
   - `author: 'human'|'mcp'`，`thread: [{ by, text, at }]`：澄清对话。
3. 提交新增 `feedbackResponses: [{ feedbackId, outcome: 'addressed'|'partial', how: string }]`（≤2000 字）。兼容旧参数：只传 `addressedFeedbackIds` 时视为 `addressed` 且 `how` 为空。`partial` 也进入 `responded`，界面要突出显示。响应写入意见的 `response` 字段，绑定 `codeHash/inputToken`；后续再提交时，旧响应照常失效。
4. 新命令 `askFeedback(projectId, targetKind, targetId, feedbackId, question)`：agent 追加 `thread` 提问，意见状态改为 `needs-clarification`（不算 pending，也不能被接受）；人回复（`replyFeedback`）后回到 `pending`。导出拦截保持“存在未接受意见即拒绝”。
5. 新只读查询 `feedbackInbox({ projectId?, status? })`：返回每条意见的 `{ projectId, targetKind, targetId, title, window, inputRevision, locked, note, prompt, lyricPlan 摘要, baseline 是否存在, thumb, nextStep }`。`nextStep` 是给 agent 的明确下一步，例如“读源码 → 改写 → submit 带 feedbackResponses”。锁定目标标为“等待人解锁”。
6. HTTP：`GET /feedback?projectId=&status=`、`POST .../feedback/:fid/ask`、`POST .../feedback/:fid/reply`；`POST .../feedback` 接受 `anchor/preserve`。
- 交付：`src/server/feedback.mjs`（校验与状态迁移）；`project-store.mjs` 接线 `addShotFeedback(input 对象)`、`submitShotSource/configureTransition(..., feedbackResponses)`、`askFeedback/replyFeedback/feedbackInbox`；HTTP `GET /feedback`、`.../feedback/:fid/ask|reply`，`POST .../feedback` 接受 `anchor/preserve/author`；服务 apiVersion `project-service/v3-feedback-anchors`；前端类型 `ProjectFeedback` 扩展。
- 实现取舍：`askFeedback` 不改输入版本、不需要 expectedInputRevision（只改意见状态，事务内完成）；已响应的意见不能再提问（避免候选与问题并存）；旧响应失效后保留最多 10 条 `responseHistory`；MCP 的 `project_feedback_add` 记为 `author: mcp`。MCP 侧新参数/新工具留给 FB-03。
- 已运行：`scripts/tests/feedback/feedback-contract.test.mjs`（8 项）+ `feedback-http.test.mjs`（独立端口与临时目录的真实服务冒烟）通过；原有 27 项领域测试不变通过；`npm run build` 通过。
- 测试（不启服务）：锚点越界拒绝；lyricElementId 失效拒绝；partial 响应可见但需人接受；提问→回复→响应→接受全流程；旧格式意见与旧参数提交仍可用；inbox 不泄露服务令牌/本机绝对路径。

#### ✅ FB-02 人的意见输入与对比界面（2026-10-02 完成；独占 `src/project/FeedbackComposer.tsx`、`src/project/ReviewCompare.tsx`（新建）及其样式（追加在 `project.css` 尾部 FB-02 小节）；`ProjectStudio.tsx` 替换接线在本分支一并完成，集成者评审重点）

1. 意见节点改为 `FeedbackComposer`：正文；“定位到当前预览时间”按钮；从本镜头 `lyricPlan.elements` 下拉选择元素；方面 aspect 单选（radio group）；“必须保留”多行列表，并提供常用项一键添加（歌词时序 / 镜头时长 / 配色 / 文字内容）；可选在缩略图上框选区域（pointer 拖拽 + 数字输入键盘路径，0..1 归一化）。
2. 预览时间来源：`reference-server.mjs` 注入的播放器每 250ms `postMessage({ type: 'videograph:time', t })`（targetOrigin '*'，父页校验 `event.origin === 预览 origin` 且 `event.source === 预览 iframe.contentWindow`；时间取 `__videographTime()` 钩子或解析 `#info` 开头数字——真实 pdoom 播放器的 #info 格式以 project-view-audit 的既有断言为据，**待有参考仓库的机器实测确认**）。
3. 意见卡列表：锚点标签（`@12.40s`、`元素：火花`、区域、方面）、保留项、agent 的 `response.how`、partial ⚠ 警示、`needs-clarification` 的问答线程与回复框（回复走 `.../feedback/:fid/reply`）。
4. `ReviewCompare`：修改前 / 当前候选两列，同一时间点静帧并排（FB-03 stills），可切双播放器（两列 preview iframe 同起点）；采用/拒绝沿用现有 accept/reject 接口与“我已检查当前候选”确认约束。
5. 无障碍：所有输入有 label；radio/checkbox/按钮原生键盘可达；状态用 ○◐◑✓ 符号 + 文字 + 左边框样式区分，不只靠颜色。
- 交付：上述文件 + `scripts/tests/feedback/ui-feedback.audit.mjs`（无头 Edge + 独立临时 projects 目录 + 独立端口服务 + 独立 vite dev server + `helpers.mjs` 夹具引擎）。
- 已运行：`node scripts/tests/feedback/ui-feedback.audit.mjs` 通过——带锚点意见（t 来自预览播放器 postMessage）→ 刷新后仍在 → agent 提问后人在界面回复 → stills 双列对比 + 双播放器切换 → 确认采用（accepted），全程无页面错误；`npm run build` 通过。
- 诚实边界：本机无 `../pdoom-video` 参考仓库，UI 与渲染链路在 canvas 2D 夹具引擎上验证；真实引擎的时间广播解析（#info）与 ReviewCompare 画面需在具备参考仓库的机器补验（可并入 INT-00 遗留的 transition-integration-audit 补跑）。

#### ✅ FB-03 MCP 意见与画面工具（2026-10-02 完成；独占 `src/server/mcp-feedback-tools.ts`（新建）与 `scripts/tests/feedback/` 下三个新文件；`mcp-tools.ts`/`mcp-server.ts` 注册、`render-worker.mjs` stills 任务、`index.mjs` stills 路由为最小接线，在本分支一并完成，集成者评审重点）

1. `project_feedback_inbox({ projectId?, status? = 'pending' })`：调用 FB-01 inbox；不传 projectId 汇总所有工程，返回锚点/保留项/nextStep，是 agent 的入口。
2. `project_feedback_ask({ projectId, targetKind, targetId, feedbackId, question })`。
3. `project_shot_submit` / `project_transition_configure` 增加可选 `feedbackResponses`（schema 由 `withFeedbackResponsesSchema` 注入）；保留 `addressedFeedbackIds` 兼容；`project_feedback_add` / `project_transition_feedback_add` 透传 `anchor/preserve`。
4. `project_stills({ projectId, shotId|transitionId, times? ≤6, version: 'current'|'before-feedback', width? = 960 })`：后台 job（`POST /projects/:id/stills`）用与导出一致的引擎/加载路径渲染；缓存键 = 引擎 hash + 代码/依赖 + 版本 + t + 宽度；缩放在渲染页内用 canvas 完成（**不依赖 ffmpeg**）；完成后 `project_job_get` 以 MCP image content（base64 PNG）返回并附 `artifacts/<key>.png` 路径（MCP 进程需与工程服务一致的 `VIDEOGRAPH_PROJECTS`）。默认时间点 = 未接受意见锚点 t + 窗口 0/0.5/1（终点回退一帧）。stills 不受 `needs-generation` 拦截：意见加入即标记待改写，但 agent 恰要在改写前看到锚点现状。
5. 每个新工具描述及 submit/configure 描述均写明“AI 不能接受意见”。
- 验收（原计划扩展 `scripts/mcp-server-test.mjs`，该脚本硬编码旧机器 F:/ 路径与旧工坊队列、本机不可运行，等价验收落在 `scripts/tests/feedback/mcp-feedback-tools.test.mjs`）：真实 stdio 全链路通过——工具注册与描述 → 带锚点意见 → inbox → stills 返回 image 内容（校验 PNG magic 与宽度缩放）→ 提问 → `feedbackResponses` 提交 → before/current 同点产物不同 → validate done → 意见 responded 且 `response.how` 存在 → 其他镜头 codeHash 不变 → 越界时间/非法宽度/无基线版本被拒绝。
- 诚实边界：同 FB-02——真实 pdoom 引擎的 stills 画面未在本机验证（无参考仓库/无 ffmpeg，后者已不需要）；夹具引擎走的是同一条 reference-server + render-worker + Edge 真实渲染路径。

#### SKILL-01 shotcraft 纳入仓库并接入 MCP（独占 `skills/shotcraft/`、`scripts/skills/`、`scripts/tests/docs/`；MCP 注册提给集成者）

**质量审阅（2026-10-01，子代理只读审阅，评分 6/10）**

技法部分可靠。抽查 12 条引擎论断（DEFAULT_POST、Archivo 宽度 62–125、GLSL_COMMON hatch/engrave/heat、子帧序列、LineBatch 等），全部与 pdoom 源码一致。扣分集中在平台说明过时、单曲绑定、缺少反馈工作流三方面。下表按严重度排列，修改内容都在 SKILL-01 内完成：

| 级别 | 问题与证据 | 修改 |
|---|---|---|
| 高 | `platform-videograph.md:3` 称 HANDOFF.md 为权威；:6-16 将旧工坊路线 C 与全引擎路线 B 并列；description 含“工坊” | 权威源改为 `docs/MCP-GUIDE.md`；路线 C 移到 `legacy-workshop.md` 附录，并注明“新工程不用”；description 删除“工坊/队列” |
| 高 | 路线 B 与 `mcp-tools.ts` 不一致：lyricPlan 漏了必填的 `name`，又把可选的 `kind` 写成必填；:66 教 agent“先 update 解锁”，违反人工解锁规则；缺 transition_feedback_add、job_cancel、includeAnalysis、before-feedback；缺状态机，也没写 render 409 和二次 submit 使旧响应失效；工具前缀写死为 `mcp__videograph-pdoom__` | 路线 B 全部由 `sync-platform.mjs` 从 MCP-GUIDE 生成，不再手写；工具名不带客户端前缀 |
| 高 | `:40` 把 `f.a` 写成“六路包络”，实际是 8 路（rms/low/mid/high/vocal/drums/bass/other），还漏了 dt/seeked/preroll/barPhase/handlesTransition | 不手抄字段，改为引用工程内 `engine/docs/ENGINE.md`，并提示用 `project_shot_source` 返回的 contract 为准 |
| 高 | 缺“按人工意见改镜头”的流程，原文只有 :63-64 两行 | 新增 `references/feedback-workflow.md`，与 MCP-GUIDE §4 对齐。内容：读意见、锚点、保留项与 reviewBaseline；只改目标；`feedbackResponses` 逐条说明；只列真正处理的意见；最多修两轮（与 `MAX_SHOT_REPAIRS = 2` 一致）；AI 不能接受；意见含糊时用 ask 澄清。附 2 个正反例 |
| 高 | 单曲美术被写成“通用法则”：SKILL.md:27-29 的墨黑/骨白/#FF4D12，:47 的“风格圣经”= pdoom TREATMENT；`pipeline-playbook.md:109` 的“歌词不上屏”又与卡拉OK“硬约束”冲突 | 五条法则只保留真正通用的：确定性、时间从数据推导、强调色纪律（不指定色值）、一镜一主角、节拍律动。pdoom 调色板与卡拉OK规则改为 `styles/pdoom-default.md` 默认风格包，可被工程风格和 prompt 覆盖；卡拉OK写成“有歌词且风格要求时的规则” |
| 中 | 单曲绑定：:73 示例用 `lyrics.get(文本)`（导致 15 个场景换歌即抛错）；:183-186 用 full-song.json/cutAtLine；fx-tx:40、media-styles:164 用 pdoom 歌词作例；shots.md 按 pdoom 场景命名；没提 CJK 字体 | 示例改为 `lyrics.linesIn(start,end)`、按词索引和拍点取时间，`ly.get` 只用于本工程确认存在的歌词；新增“换歌注意”一节，覆盖器乐段、中文字级与字体、无 words 时回退到行级、不硬编码秒数；范式名改为功能名，pdoom 场景只作“范例”括注 |
| 中 | `fx-tx-addendum.md` 与 playbook §3/§4 重复；B3“禁 cross-dissolve”与 transitions.md:14 及平台 dissolve 冲突 | 撤销 addendum，内容分别并入 effects/transitions/pipeline；冲突改为“默认偏好 handshake，dissolve/dip 是平台内建选项，用于情绪段或兜底” |
| 中 | 本机绝对路径（SKILL.md:10/:47、media-styles:3、playbook:4/:143、fx-tx:3） | 改为上游仓库 URL 加 SOURCES.md 条目；测试禁止出现 `C:\Users`、`F:\aicg` |
| 中 | 许可：JohnHeibel/PDoomVideo 无 LICENSE，media-styles:21 的 paint 签名与 flushLetters hack、fx-tx:11 的 `randomSeed(1000+floor(T·BOIL))`（对应其 core.js:195）接近原文；nickmontag 的代码为 MIT，但歌词/分镜/风格笔记为 CC BY-NC | 无许可来源只保留用自己的话写的技法描述并重写示例；NC 来源的风格笔记只标出处、不转述细节；ClaudeAnimationBase 已确认为 MIT，可保留并署名 |
| 低 | description 约 800 字节，关键词堆砌 | 压到约 250 字：触发场景（为代码渲染的音乐视频/宣发片设计或修改镜头、转场、特效、媒介风格；处理 VideoGraph 镜头意见）加一句能力说明 |
| 低 | 没有最小 Scene 骨架和提交前自检清单；playbook §5/§7 的 Ruby 执行契约、实录派、prompt 词汇表与本平台关系弱；总量约 100KB | 新增 `templates/scene-template.ts`（通用、只用窗口歌词与拍点，与 SONG-03 的 `_window-template.ts` 同源）和自检清单；删除或下沉 SKILL.md:49-56 与 playbook §1/§5/§7/§8；media-styles 保留核心几种，其余放进 `media-styles-extra.md`，按需读取。目标总量 ≤60KB，SKILL.md ≤60 行 |

**目标结构**

```
skills/shotcraft/
  SKILL.md                 # ≤60 行；frontmatter: name/description/version/toolset
  SOURCES.md               # 每个 reference 的来源仓库、许可、处理方式（保留/改写/仅出处）
  references/
    feedback-workflow.md   # 新增，优先读
    shots.md  transitions.md  effects.md  pipeline.md
    media-styles.md  media-styles-extra.md
    platform-videograph.md # 生成文件，头部注明“勿手改”
    legacy-workshop.md     # 原路线 C
  styles/pdoom-default.md  # 默认风格包（调色板/卡拉OK/辉光纪律）
  templates/scene-template.ts
```

**适配步骤（按顺序；每步都要构建并测试通过）**

1. 复制原目录到 `skills/shotcraft/`，作为第一个提交，原样保留，方便看 diff。
2. 处理许可：写 SOURCES.md，改写或删除有问题的段落。下方“待确认”列出的仓库许可未核实，相关段落先改写为仅保留技法描述。
3. 结构调整：撤销 addendum；拆出 styles、legacy-workshop、media-styles-extra；精简 SKILL.md 和 description。
4. 内容修正：通用法则、换歌注意、Frame 改为引用 ENGINE.md；写 feedback-workflow.md 与 scene-template.ts。scene-template 要用真实引擎跑 `project_validate` 并通过。
5. 实现 `sync-platform.mjs` 生成平台说明，并加上版本、toolset 字段。
6. 分发：install 脚本、MCP resources、craft_guide、respond_to_feedback prompt（见下方原第 3 点）。
7. 回写源头：用户原来的 `C:\Users\Martis\.zcode\skills\shotcraft` 不直接覆盖。install 脚本加 `--user` 参数时，先备份原目录再替换，需要用户确认。
8. 效果验证：让一个新的 agent 只靠 skill 加 MCP，处理一条带锚点的测试意见。记录它是否读了正确的文件、有没有越界修改、有没有提交自检，作为 FB-04 的子项。

**待用户确认：**

- opus-video-audio-skill、Pdoom-video-anime-version、awesome-opus-5-5-video-prompts 三个仓库的许可尚未核实。
- pdoom 调色板是否作为产品级的默认风格包保留（建议保留，并标注为“默认，可替换”）。
- 用户级 skill 目录是否改为由仓库版本覆盖（建议改为由仓库单向同步）。

**原计划要点（保留）：**

1. **来源与许可先行**：把 `C:\Users\Martis\.zcode\skills\shotcraft\` 复制到仓库 `skills/shotcraft/`，并新增 `skills/shotcraft/SOURCES.md`，逐个 references 文件标注技法来源仓库及其许可。对无 license 或 NC 许可的仓库（JohnHeibel/PDoomVideo、nickmontag 等），只保留技法描述与自写示例，删去逐字复制的代码片段；无法判断的段落列给用户确认。完成前不推送公开远端。
2. 单一事实源：`platform-videograph.md` 路线 B 改为由 `docs/MCP-GUIDE.md` 生成（`scripts/skills/sync-platform.mjs`），路线 C 保留。`SKILL.md` frontmatter 增加 `version` 与 `toolset`（与 MCP-GUIDE 的 toolset 行一致）。
3. 分发给 agent，三条通道：
   - Claude Code / ZCode：`scripts/skills/install.mjs`，把 `skills/shotcraft` 链接或复制到 `.claude/skills/shotcraft`（项目级）或 `~/.zcode/skills/shotcraft`（用户级，需显式参数）。默认项目级，不改用户全局目录。
   - MCP resources：`videograph://skills/shotcraft/SKILL.md` 与 `.../references/<name>.md`、`videograph://docs/mcp-guide`。server capabilities 增加 `resources`。
   - MCP tool `craft_guide({ topic?: 'shots'|'transitions'|'effects'|'media-styles'|'pipeline'|'platform', query? })`：给不支持 resources 的客户端，按标题段落返回匹配节选（≤12k 字符）。
   - MCP prompt `respond_to_feedback({ projectId? })`：内容为 MCP-GUIDE §4 流程 + shotcraft 五条法则 + “不能接受意见、只改目标、逐条 feedbackResponses”。
4. inbox 的 `nextStep` 中提示相关技法入口（如 aspect=motion → effects.md §节拍冲击；转场意见 → transitions.md）。
- 测试：`scripts/tests/docs/mcp-guide-sync.test.mjs` 比对 `projectToolDefinitions` 与 MCP-GUIDE §3 的工具名，不一致即失败；resources 列表与读取；`craft_guide` 节选长度上限；skill 目录不含绝对用户路径与密钥。

#### FB-04 端到端验收（QA-01 owner，独占 `scripts/tests/collaboration/`；只测，不改实现）

1. 夹具：独立 `VIDEOGRAPH_PROJECTS` 临时目录、独立端口与令牌，从参考 BGM 建工程。
2. 人（Playwright）在镜头 A 加带时间锚点与保留项的意见 → agent 脚本（真实 MCP stdio）：inbox → stills → 提问 → 人回复 → submit + feedbackResponses → validate → 人对比后采用 → 导出放行。
3. 断言：只有镜头 A 的 codeHash 改变；保留项涉及的歌词时序未变（抽 3 个词起点帧比较字幕状态）；修改前版本仍可预览；旧候选不能被接受；导出清单记录新版本。
4. 真实案例：在独立创作工程上用真实 agent 处理 `prompt1` 的现有意见“是不是有点太素了，多加转场”。这条意见跨越镜头与转场，验证 agent 能提问澄清或拆成转场意见。结果交由人审美确认，不由脚本判定。
5. 全部加入 `npm run audit`。

#### 文档同步规则（所有工作包适用）

- 改动 MCP 工具名、参数或语义 → 同一提交更新 `docs/MCP-GUIDE.md`（工具表、流程、toolset 行），再运行 `node scripts/skills/sync-platform.mjs`；`mcp-guide-sync` 测试兜底。
- 改动 skill → bump `skills/shotcraft/SKILL.md` 的 version，并重新运行 install 脚本。
- 完成工作包 → 在本节将状态改为 ✅，附运行过的命令与结果。

### 并行冲刺 SONG：任意歌曲拆解与建工程（2026-10-01 规划）

目标：用户给出任意本地音频（可选附歌词文本或 LRC），系统产出经人确认的分析数据，包括节拍/小节/段落、包络与鼓点、可选分轨、词级歌词。在此基础上规划镜头、由 agent 写场景、导出成片。ToB 无歌词配乐与音乐人有歌词 PV 走同一条路径。

**现状（2026-10-01 核对代码）：只支持 pdoom 这一首歌。** 单一歌曲的绑定点如下，每一处都要拆：

| 绑定点 | 位置 | 处理工作包 |
|---|---|---|
| 音频字节指纹不匹配即 422 拒绝 | `project-store.mjs` `createProjectFromAudio` | SONG-05 |
| 分析数据固定读 `src/shot/full-song.json` | 同上 | SONG-00 |
| 22 个镜头切点按 pdoom 歌词原文硬编码 | `reference-plan.mjs` | SONG-04 |
| 引擎时间线 `timeline.ts` 按 pdoom 歌词硬编码；覆盖逻辑依赖 `original.find(id)` | 参考引擎 + `reference-server.mjs` transform | SONG-03 |
| 40 个参考场景中 15 个调用 `ly.get('某句原词')`，换歌会直接抛错 | `engine/app/src/scenes/*.ts` | SONG-03 |
| 音频固定为 `audio/pdoom.mp3` | 参考 `main.ts`、`render-worker.mjs` ffmpeg 混音 | SONG-03 |
| 字体仅拉丁字形（Archivo/Cormorant/Plex Mono），中文歌词无字形 | `app/public/fonts` | SONG-03 |
| 参考分析管线依赖 mlx-whisper（仅 macOS）、手调 `SECTION_BARS`/`ANCHORS`、固定 mp3 编码延迟 | `pdoom-video/analysis/*.py` | SONG-01（不复用其手调部分） |

**原则：**

- 分析结果是**带来源与置信度的草稿**，人确认后才能用于规划。ASR 识别出的歌词文本必须经人确认，AI 不能代替人确认。
- 无歌词就是器乐工程，不伪造歌词。
- 参考 pdoom 工程继续走指纹导入，作为分析质量的基准真值。
- 模型、权重和 Python 环境要先列出体积与许可，经用户同意后才下载。

**本机环境（2026-10-01 实测）：**

- Windows，RTX 5070 Laptop 8GB；空闲显存 7.26GB。
- 已有 conda 环境 `pytorch`（`D:\Users\Martis\anaconda3\envs\pytorch`，9.2GB）：
  - Python 3.9.23、torch 2.8.0+cu128；架构列表含 sm_120，GPU 矩阵运算已实测通过。
  - 已装：torchaudio 2.8.0、transformers 4.57.6、accelerate 1.10.1、onnxruntime-gpu 1.19.2、numpy 2.0.2、scipy 1.13.1。
  - 未装：librosa、demucs、ASR 相关包。
- base 环境是 Python 3.13，torch 为 CPU 版，不使用。
- ffmpeg 9 可用；没有 uv。
- 磁盘：D 盘剩余 29GB、F 盘剩余 71GB。模型缓存统一放 F 盘（`HF_HOME`、`TORCH_HOME` 指向 `F:/aicg/.models`，不进仓库）。

**执行顺序：** `SONG-00 →（SONG-01 ∥ SONG-02 ∥ SONG-03）→ SONG-04 → SONG-05 → SONG-06`。SONG-00/01 只涉及新目录，可以和反馈冲刺并行；SONG-03/05 会碰热点文件，排在 FB-01 合并之后。

#### SONG-00 分析数据契约与参考适配器（独占 `src/song/contract.mjs`、`src/song/adapters/`、`scripts/tests/song/`）

1. 定义 `videograph-analysis/v2`（JSON Schema 并带校验器），分层存储，每层带 `provenance: { tool, version, model?, params, startedAt, confidence }`：
   - `audio`：hash、时长、采样率、声道、解码器偏移（mp3 编码延迟按解码结果实测，不写死）。
   - `rhythm`：bpm 或 tempo map、beats、downbeats、拍号、置信度。
   - `sections`：起止、标签（intro/verse/chorus/bridge/outro/unknown）、置信度。
   - `envelopes`：rms/low/mid/high，有分轨时加 vocal/drums/bass/other，并记录帧率。
   - `onsets`：kick/snare/hat/vocal 及强度。
   - `stems?`：分轨文件 hash（不内嵌字节）。
   - `lyrics?`：语言、文本来源（user/lrc/asr）、文本是否经人确认；行/词/可选音节，每个元素带 conf。
   - `overrides`：人工修正层，记录作者与时间，不覆盖原始分析。
2. 适配器：
   - `fromPdoom()`：把现有 `pdoom-video/data/*.json` 转成 v2，provenance 标为 reference-import。
   - `toEngine()`：生成引擎读取的 `data/audio.json` 和 `data/lyrics.json`。
   - `toFullSong()`：兼容旧工坊格式。
3. 测试：pdoom 数据往返转换后，与原文件在数值上一致（误差 ≤1e-6）；缺少 lyrics 的器乐数据校验通过；词时间越界或倒序会被拒绝。

#### SONG-01 本地分析器（独占新目录 `analyzer/`（Python 子工程）与 `src/song/analyzer-runner.mjs`）

1. **Python 环境：复用本机 `pytorch` 环境的 CUDA 版 torch，但不改动原环境。**
   - **方案 A（默认）**：`conda create -n videograph-analyzer --clone pytorch`，在克隆出的环境里装分析依赖，不用重新下载约 3GB 的 torch cu128。要注意的是：
     - Python 3.9 已停止维护，依赖版本必须选仍支持 3.9 的：`librosa 0.10.2.post1`（1.0 要求 3.12+）、`demucs 4.0.1`（4.1 要求 3.10+）、`beat-this 1.1.0`、`faster-whisper 1.2.1`、`qwen-asr 0.0.6`。
     - qwen-asr 固定 `transformers==4.57.6`，与现有环境一致；它要求 `accelerate==1.12.0`，在克隆环境里升级即可。
     - 克隆约占 D 盘 9GB；空间不够时改用方案 B。
   - **方案 B（A 出现依赖冲突时改用）**：新建 Python 3.12 conda 环境，从 PyTorch 官方 cu128 源安装 torch 2.8 系列（约 3GB 下载）。版本锁定与 A 相同，可以改用 librosa 1.0 和 demucs 4.1。
   - 两种方案都写在 `analyzer/environment.md` 与 `analyzer/requirements-*.txt` 里，用精确版本号锁定。runner 通过 `VIDEOGRAPH_ANALYZER_PYTHON` 指定解释器的绝对路径，不从 PATH 里猜。
   - `analyzer/doctor.py` 自检：Python 和 torch 版本、`cuda.is_available()`、sm_120、空闲显存、ffmpeg、各模型是否已缓存，输出 JSON。
   - 安装脚本先打印需要下载的组件与体积，用户同意后再执行。
2. 只开放固定的任务表（沿用 `pdoom/tasks.ts` 的思路），每个阶段是一个可缓存任务。缓存键为 `audioHash + stage + 工具/模型版本 + 参数`，产物先写临时文件再原子发布。
   - **T0 解码**：ffmpeg 解码为 44.1k PCM，同时记录偏移。
   - **T1 节奏与结构（beat_this 用 GPU 更快，CPU 也能跑）**：
     - 包络与 onset 用 librosa。
     - 鼓点不靠分轨：用 librosa HPSS 分出打击成分，再按低/中高频段区分 kick/snare/hat。
     - beats/downbeats 用 `beat_this`（模型很小，可走 CPU）；librosa `beat_track` 作为兜底（它不出 downbeat，按拍号与重音推算并标为低置信）。
     - 段落用自相似矩阵与新颖度曲线切分，并吸附到小节线。
     - 只有这一级时也能完成器乐工程。
   - **T2 分轨（可选；默认关闭，见下方许可表）**：只用于提升人声包络和对齐质量。ASR 与对齐的默认路径直接处理混音，不依赖分轨。
   - **T3 歌词**：
     - **用户提供文本或 LRC 时**：按行切段（每段不超过 5 分钟），用 `Qwen3-ForcedAligner-0.6B` 做强制对齐；中文出字级时间，英文出词级时间。
     - **没有文本时**：用 `Qwen3-ASR-1.7B` 识别（官方支持演唱和带伴奏的歌曲；显存不够时退到 0.6B），得到草稿；人确认文本后再做对齐。
     - 对齐完成后用信号细化词首尾，再计算置信度。
     - 置信度低时，用备选对齐器复跑并取两者的一致性。
3. **模型选型与商用许可**：建 `analyzer/MODELS.md`，写明每个模型的用途、体积、许可和商用是否可行。默认链路只放许可清楚、可以商用的模型；NC 或许可不明的只能显式开启，并在工程 provenance 和导出清单中记录。
   - 2026-10-01 初步核查如下。“待核实”的条目，SONG-01 实施时要读权重仓库里的 LICENSE 原文并存档链接；在那之前不算“可商用”。
     | 用途 | 默认（可商用） | 备选 | 排除出默认（原因） |
     |---|---|---|---|
     | 节拍/下拍 | `beat_this` 1.1.0：代码与权重均为 MIT（README 声明）。部分训练数据有版权限制，作者提示使用者自行判断 | librosa 0.10/1.0 `beat_track`（ISC，纯算法、无权重） | madmom 预训练模型（CC BY-NC-SA 4.0，明确禁止商用）；all-in-one（权重许可未写明，训练数据为 Harmonix；Windows 上需从源码编译 NATTEN） |
     | 段落 | 自研：librosa 自相似矩阵、新颖度曲线，吸附到小节线（ISC） | 人工在 SONG-02 校正 | all-in-one（同上） |
     | 鼓点 | librosa HPSS 加频段 onset（ISC） | 开启分轨后改用 drums 分轨 | — |
     | 人声分离（可选） | 默认不分轨 | Spleeter 2.4.2：代码 MIT，权重未单独声明，但已被 iZotope RX 等商业软件使用，按相对低风险处理。它需要 TensorFlow、Python 3.8–3.11，要放在单独的环境里 | Demucs htdemucs：代码 MIT，权重训练用了 MUSDB18（仅限学术用途），issue #327 至今没有官方答复，属于灰色地带。只能由用户显式开启，并记录在导出清单里 |
     | 歌词识别 | `Qwen3-ASR-1.7B` / `0.6B`：仓库为 Apache-2.0，权重卡许可**待核实**；支持 52 种语言/方言，其中有中文和英文 | `faster-whisper` 1.2.1（MIT）加 Whisper large-v3 权重（OpenAI 以 MIT 发布，待核实） | — |
     | 强制对齐 | `Qwen3-ForcedAligner-0.6B`：模型卡标注 Apache-2.0（待核实 LICENSE 原文）；支持 11 种语言，含中、英、粤、日、韩；单次不超过 5 分钟；模型卡写的是“语音”，**对演唱的效果没有官方数据，要用 pdoom 基准实测** | Montreal Forced Aligner 的 english_mfa / mandarin_mfa（CC BY 4.0，需要署名；Windows 上走 conda-forge 安装）；stable-ts（MIT）细化 Whisper 词时间，作为最后兜底 | MMS_FA（CC-BY-NC，pdoom 原管线在用）；whisperX 默认的 wav2vec2 对齐模型（不同语言的模型许可不一，部分为 NC） |
   - 版权提醒：模型许可不覆盖用户输入的歌曲。界面要提示用户只处理自己有权使用的音频。
   - 实施时按顺序验证：先 T1（只需 pip 依赖和 beat_this 的小权重），再 Qwen3-ForcedAligner（约 1.2GB）、Qwen3-ASR-1.7B（约 3.5GB，fp16 推理约 4–5GB 显存，8GB 卡可行但要实测），最后才是备选。每次下载前列出体积，等用户同意。
4. 失败分级：缺依赖、显存不足、模型下载失败与分析质量低要分开报告。显存不足时自动降级（分块处理或改用 CPU），并在 provenance 里记录。
5. 测试：
   - 合成 click track（已知 BPM 和拍号，由 ffmpeg/numpy 生成）验证 T1：拍点 F-measure ≥0.98，bpm 误差 ≤0.5。
   - 用 pdoom 原 BGM 和参考数据对比，记录 beat F-measure 以及词首时间中位误差和 P90 误差，作为基准写入本节。目标是中位误差 ≤50ms；达不到时如实记录。
   - 对齐器对比：在 pdoom 基准上分别测 Qwen3-ForcedAligner 直接处理混音、Qwen3-ForcedAligner 处理 Spleeter 人声、MFA 三种方案。只有某种组合达标，才把它定为默认。
   - 中文：用一首用户提供的中文歌（不入库），人工标注 20 个字的起点作为抽样基准，测字级误差。

#### SONG-02 分析节点与人工校正界面（独占 `src/song/ui/`；节点接入 `ProjectStudio.tsx` 由集成者合并）

1. 节点画布新增“音频 → 分析 → 歌词 → 节奏/段落”节点。每个节点显示来源、置信度、状态：草稿、待人确认、已确认、已修正。
2. 校正视图（Canvas 自绘，不新增重型依赖）包括：
   - 波形与频谱、拍网格；
   - 全局偏移与 BPM 微调、tap tempo；
   - 段落边界拖动与重命名；
   - 歌词粘贴/LRC 导入，逐词拖动起止时间，低置信词高亮；
   - 点击任意词即从该处播放。
3. 所有修改写入 `overrides`，可撤销，并显示与原始分析的差异。歌词文本“已确认”只能由人点击，按钮旁说明确认后可以开始规划镜头。
4. 分析修改后的影响：时间窗受影响的镜头标为“待更新”，导出被拦截；不影响的镜头保持原状。
5. 无障碍：词时间编辑可以用键盘完成（选中词后用方向键按 10ms/1 帧微调）。

#### SONG-03 引擎解耦（`reference-server.mjs`、`render-worker.mjs` 属于集成者；场景模板和字体放 `engine-base/`）

1. 音频路径参数化：工程记录 `audio.file`（`engine/audio/<hash>.<ext>`），预览播放器和 ffmpeg 混音都读这个字段，不再写死 `pdoom.mp3`。
2. 时间线完全由工程镜头列表生成：不依赖参考 `timeline.ts` 里的条目，每个镜头直接映射到 `module/params/post`。参考工程的行为保持不变，现有导出缓存键要么不变，要么显式升版本。
3. 场景分级：
   - 给 40 个参考场景标注“通用”或“绑定 pdoom 歌词”，记录在 `engine-base/SCENES.md`。
   - 新歌工程只复制引擎核心和通用场景。
   - 新增 `engine-base/scenes/_window-template.ts`：只用 `lyrics.linesIn(start, end)` 和拍点事件，给 agent 当起点。
   - 静态检查：场景里 `ly.get('字面量')` 的文本必须存在于本工程歌词中，否则提交时拒绝，避免运行时才抛错。
4. 字体：新增字体资源登记（文件 hash、许可、来源）。中文默认用 Noto Sans SC / Source Han（OFL），按工程歌词用 fonttools 子集化，只放进工程目录，不提交仓库。opentype 轮廓文字效果对中文要实测性能。
5. 引擎来源说明：新歌工程的 CREDITS 写明“引擎核心来自 pdoom-video（MIT），场景为本工程新写”，不再复制 pdoom 的 README 当作品署名。

#### SONG-04 新歌镜头规划（独占 `src/song/planner.mjs`、`scripts/tests/song/planner*`）

1. 候选切点生成：把 pdoom `cutAtLine` 的规则通用化：在歌词行首词之前取最近的拍；器乐段改用小节线或段落边界；镜头时长有上下限（默认 2–12s，可配置）。所有切点量化到输出帧。
2. 规划由 agent 结构化提交，服务端校验：
   - 覆盖 `0..duration`，无空隙、无重叠、单调递增；
   - 每个镜头的锚点（歌词行或段落）必须存在；
   - 切点不能落在一个词的中间。
3. 产出的镜头状态为 `needs-generation`，来源 `ai-original`，带 `lyricPlan` 草稿。之后沿用现有“读上下文 → submit → validate”流程。转场节点按相邻镜头自动生成。
4. 内置的确定性规划只用于测试和兜底（每段一个镜头），并明确标注不是 AI 创作。

#### SONG-05 建工程与 MCP 接入（服务路由和 MCP 注册由集成者合并；同步更新 `docs/MCP-GUIDE.md`）

1. `createProjectFromAudio` 改为：
   - 指纹命中参考曲 → 现有导入流程（保留）。
   - 否则 → 新建空工程：复制音频，状态为 `analysis-pending`，排队执行 T0–T3（按用户选择的级别）。
2. 工程状态机：`analysis-pending → analysis-draft → analysis-confirmed → planned → 正常镜头流程`。规划前必须是 `analysis-confirmed`；分析被修改后，进入受控回退流程。
3. MCP 工具：
   - `project_create_from_audio`：参数 `audioPath, name?, lyricsText?, lrcPath?, language?, tier?`，`project_create_from_bgm` 保留为别名。
   - `song_analysis_get`：可分层读取、可按时间段读取。
   - `song_analysis_run`：只接受固定的 stage 名。
   - `song_lyrics_submit`：agent 可以提交歌词文本草稿，状态仍是“待人确认”。
   - `song_analysis_patch`：agent 的修正标为 mcp 来源。
   - `project_plan_submit`。
   - **不提供** AI 确认分析的工具。
4. 用户素材只留在本机，MCP 输出不包含音频字节和本机绝对路径。

#### SONG-06 验收（QA owner；只测，不改实现）

1. 合成 click track：从建工程到 T1 分析、人确认、规划（确定性兜底）、3 个镜头，再到导出全流程跑通。用 ffprobe 核对帧数与时长，导出音轨与源音频的相关系数 ≥0.999。
2. 回归：pdoom 原 BGM 仍走指纹导入，现有参考工程和导出缓存不受影响。
3. 基准：pdoom BGM 强制走新分析器，对比参考数据，结果写入本节。
4. 用户提供的真实歌曲（至少一首中文、一首无歌词配乐；文件不入库）：
   - 分析 → 人工校正 → 规划 → agent 创作 → 导出；
   - 记录人工校正花了多久、改了多少处；
   - 审美由人确认。
5. 未知音频且没有提供歌词时，不出现任何旧工程的歌词；歌词校验门拒绝引用不存在的句子。

### 既有任务清单

1. ⬜ 完成新工程界面集成与构建；节点可选择/导航，工程可刷新恢复，后台任务和产物可见。
2. ⬜ 完成人工意见节点：保留原始 prompt，添加意见只影响目标镜头；MCP 读取意见并明确声明响应了哪些意见。
3. ⬜ 完成“待响应 → 已响应/待人工确认 → 已接受”；技术校验不自动代替人工接受。
4. ⬜ 保留修改前场景，支持修改前/候选预览；锁定、旧版本提交、过时回答均有保护。
5. ⬜ 用真实 MCP 改写一个镜头源码，验证其视觉变化、歌词时序和其他镜头未被重写。
6. ⬜ 验收完整成片：ffprobe 检查视频帧率/帧数、音轨、时长；看抽帧和实际播放，不仅检查文件存在。
7. ⬜ 第二次导出验证增量缓存：只重渲染改过的镜头，其余内容哈希命中；输出清单记录冻结版本。
8. ⬜ 新增工程/MCP/人工反馈/恢复的自动化验收，并运行既有全量回归。
9. ⬜ 更新本文件完成状态与 HANDOFF 操作说明；保留真实测试结果和可打开的成片链接。

## 四、人工参与的正式设计

### 工程拆分

- 工程级：目标、风格规范、品牌约束、输出规格。
- 资源级：BGM、旁白、产品图、字体、字幕/歌词、公共素材。
- 镜头级：视觉意图、时间窗、参数、场景源码、预览、产物版本。
- 修改意见级：独立节点连接到目标镜头；未来可扩展到共享风格/素材和分幕。
- 输出级：时间线、合成、渲染规格、导出版本。

首版先做好**镜头级修改意见**，不把任意函数都暴露成节点。展开复杂镜头子图应展示有意义的图层、参数、素材和效果，而不是代码行级拆分。

### 修改意见模型与状态

保存 `id / target / text / baseInputRevision / createdAt / status / responseCodeHash / acceptedRevision`。

- 原 prompt 和人新增的意见分别保存；不悄悄覆盖原始意图。
- 意见可以包含要改的部分和必须保留的部分（歌词时序、产品 Logo、镜头长度等）。
- agent 读取目标镜头、原始要求、当前源码、意见与真实引擎契约，返回完整新源码。
- 仅输入版本仍匹配时接受提交；成功后是“已响应”，不是“用户已满意”。
- 候选先技术校验，再由人前后比较并选择采用；明确的人工意见未经接受，不作为已确认修改进入正式交付。
- 当前已导出的文件保持冻结版本；新意见不会改变旧成片。
- 拒绝候选/补充意见/恢复之前版本属于后续必须补齐的版本操作。

## 五、目标架构

### 编辑器

React/ReactFlow 读取工程快照、发送命令，不决定模型调用、重试、持久化与作业成败。节点位置/折叠/选择为视图状态；执行依赖来自领域模型，不能只依据视觉连线任意执行。

### 本地工程服务

一个 Node 模块化单体：命令、SQLite 仓库、任务调度、缓存索引、素材与产物管理。HTTP 命令/查询已开始接入，SSE 事件流是后续替代轮询的方向。开发 Vite 与生产工程服务分离，最终不需要 Vite 才能运行。

MCP 与 UI 共用命令层。MCP 不是自动调用模型的魔法：未有 agent 执行时必须显示等待外部 agent。文件队列只保留为旧工坊兼容通道，不再作为新工程的事实源。

### 渲染宿主与执行进程

场景准备/渲染/释放有统一生命周期；预览、校验、离线导出使用相同场景版本和时间模型。Canvas2D、原引擎/Three.js、未来 GLSL/素材合成为不同后端；不能各维护一套互不兼容的时间/播放/导出语义。

编辑器与生成代码隔离，渲染进程可中止；本机服务绑定 loopback、校验 Origin/会话令牌。原引擎宿主限制文件读取范围和网络来源。`new Function`/静态 lint 不是安全沙箱；仍要补进程超时、资源预算及异常场景的强制回收。

## 六、数据、版本、依赖与存储

核心对象：
- `Project`：工程 ID/schema、素材引用、风格版本、输出规格、时间线版本。
- `Analysis`：音频指纹、分析器版本、词级/节拍/包络与来源；无歌词工程也合法。
- `ShotSpec/ShotRevision`：稳定镜头 ID、编辑快照、参数、种子、时间窗与锁定。
- `Feedback`：人工意见及目标/响应/接受版本。
- `Job/Attempt`：冻结输入、执行通道、进度、次数/费用预算、诊断、取消/恢复。
- `Artifact`：源码、报告、缩略图、视频段等不可变产物及真实依赖。
- `TimelineRevision`：剪辑顺序/窗口与选用的版本，导出前冻结。

每工程独立目录，SQLite 为元数据与历史事实源，素材/引擎快照/产物/导出存文件。事务与 expectedRevision/inputToken 阻止覆盖；先临时写文件再原子发布，半成品不能命中缓存。JSON 可以作为导入/导出格式，不能与 SQLite 双重可写。备份必须一致性快照，不能盲拷正在写入的 WAL。

黑板只做产物/缓存/依赖展示；记忆做风格与上下文检索，不能代替完整历史或真实任务状态。API key 不进入工程、提示词、产物或 MCP 输出；旧工坊浏览器凭据仍需后续迁移。

**时间线与依赖图区分：** B 排在 A 后面不代表 B 依赖 A。只有明确引用尾帧、共享素材或跨镜头效果时才传播失效。转场区间需合成，不能把整条时间线顺序依赖成全量重算。

## 七、复现、缓存与导出

复现清单应包含源码/素材/字体 hash、依赖锁、引擎与宿主版本、参数/seed、分析数据、输出规格、渲染环境。固定环境内验证重现；不承诺跨 GPU/浏览器逐像素一致。

两类缓存分离：
1. LLM 精确请求缓存：provider/model/完整消息/采样参数。
2. 确定性构建缓存：规范化输入 + SHA-256，包含源码、真实上游 hash、窗口/参数/seed、引擎版本、输出规格与编码设置。

失效例子：移动节点不计算；改分辨率只重渲染、不重问模型；改一镜头只更新真实下游；改全局风格标记相关镜头待更新；锁定旧风格版本须显示差异。

导出：时间线按整数帧/明确帧率量化；片段只编码视频，最后一次性混音/封装完整 BGM，避免逐段音频编码间隙。编码/时间基等兼容才可以直接拼接；转场单独合成。每帧错误必须中止并报告，不能黑帧吞错。输出清单记录冻结版本、帧区间、缓存、工具链与音频来源。

后续补齐：分辨率/画幅与质量预设、更多采样策略、任务超时/暂停/恢复、一致性备份/迁移、缓存清理与磁盘预算、选定版本回滚。

## 八、从指定 BGM 到通用 AI 创作

### 第一条可复现路径（当前）

给定 `pdoom-video` 原始 BGM，以字节指纹命中已提交的分析数据，导入真实引擎/源码/素材，再通过 MCP 做局部创作与修改。明确标记这是**参考工程导入 + 新版本创作**，不是从音频凭空推断出原始作品。

### 通用音频输入（未完成 → 已拆为第三节“并行冲刺 SONG”）

- 实施计划、单曲绑定点清单与验收见 SONG-00～06。
- 不匹配原曲的输入不得复用旧歌词时间轴；无歌词时生成器乐型方案，不伪造歌词。
- 音乐数据参数化，ToB 脚本/旁白后续使用同一时间模型（旁白对齐可复用 SONG-01 的强制对齐阶段）。

### AI 一键创作（未完成）

- 全局创意/风格圣经 → 可编辑分镜方案 → 素材需求 → 各镜头源码/参数 → 多帧校验 → 片段审阅 → 整片输出。
- 原始工程通过显式 importer/manifest 接入，保持运行依赖，不强行转成简化 Canvas。
- 模型输出结构化参数/场景代码，能力由版本化引擎契约约束。
- 将原工程校验/错误回喂也接入与旧工坊同等的有限修复循环。
- 外部 agent 任务增加 claim/lease/attemptToken、幂等提交、断线恢复；网络/鉴权/预算错误与代码修复分开。
- 总尝试次数、费用、磁盘、渲染时间有预算；审美审核和用户意见优先，不无限重试。

## 九、ToB 与高级创作阶段（后续）

- 品牌包：Logo、产品图、字体/色板、禁用规范、文案与法律/版权信息。
- 宣发脚本/旁白 → 分镜，与音乐人 PV 使用同一镜头与反馈模型。
- 多画幅/时长/语言版本，不靠重新生成整片；可锁定共享素材与已确认镜头。
- 分幕、折叠组、拆合卡、时间窗边界编辑、过渡和图层参数。
- 参数 schema 驱动控件；复杂镜头按语义子图展开（构图/文字/3D/后期），支持局部意见的明确作用域。
- 版本对比/采用/拒绝/回滚，导出审批、来源与版权清单。
- 达到单机可交付质量后，再评估多人角色、团队素材库、部署方式和远程渲染；不提前做通用插件市场或云集群。

## 十、验收矩阵与完成定义

| 领域 | 必须证明的行为 |
|---|---|
| 输入 | 只给指定 BGM 即建工程；未知音频不套旧数据；来源可见 |
| 持久化 | 刷新、关页、服务重启后项目/源码/历史仍在 |
| 修改意见 | 独立节点、原始意图不丢、目标与版本正确、只改对应镜头 |
| 采用 | AI 响应 ≠ 人工接受；候选可比较，未经接受的意见不可冒充已确认 |
| 任务 | 取消/超时/服务断开可诊断，旧结果和重复提交不能覆盖新编辑 |
| 校验 | 编译错误、多时刻错误、晚发错误均能呈现；不伪造视觉验收 |
| 真实引擎 | 字体/GLSL/Three.js/后期保留，不以模板代替原表现力 |
| 导出 | 完整视频+音轨、帧数/时长正确、逐帧无错误、可打开播放 |
| 增量 | 改一镜头再次导出，只重算真实影响范围，其余缓存命中 |
| 安全/权利 | 本机权限隔离、无任意 shell 接口、不泄露凭据、不丢原作者与素材权利说明 |

现有基线：`npm run build`、`npm run audit`（六项）、`npm run audit:reference`。新工程与人工反馈验收脚本完成后加入同一回归入口。任何尚未执行或失败的检查，都必须留在进行中状态。

## 十一、并行协作与冲突控制

> 目的：让人类同事与 AI 在明确边界内并行，减少冲突；不是承诺 Git 能自动解决所有语义冲突。此节也是工作认领与交接入口，不再另建计划文件。

### 当前工作包

| 工作包 | 负责人/状态 | 独占修改范围 | 交付与边界 |
|---|---|---|---|
| CORE-01 歌词元素与转场闭环 | 当前 AI 实现中 | `src/server/lyric-elements.mjs`、`transitions.mjs`、`transition-runtime.mjs`，`src/project/LyricInspector.tsx`、`TransitionInspector.tsx`，相关专属测试 | 真实歌词依据、转场节点/意见、预览与导出一致；不扩展品牌素材领域 |
| PV-01 独立 PV | 当前 AI 实现中 | `examples/last-audit/`、`scripts/author-last-audit.mjs`、专属视觉验收脚本 | 只通过 MCP 修改独立创作工程，不动参考工程；歌词相关元素要可解释 |
| ASSET-01 品牌与产品素材 | ✅ ZCode 会话（2026-10-01）：已写代码+已运行验证，**未接入主界面**，等集成者挂载 | 新目录 `src/brand/`、`src/server/brand/`、`scripts/tests/brand/`、`public/brand-demo/`；未改工作区现有未提交文件 | 独立实现品牌资料/素材元数据与管理面板；先使用测试数据和适配接口，不直接改主界面或工程数据库。交付记录见下方"ASSET-01 交付状态" |
| QA-01 人与 AI 操作检查 | ✅ ZCode 会话认领（2026-09-30，用户指派），第一切片已交付 | 新目录 `scripts/tests/collaboration/`、独立测试夹具 | 反馈生命周期多步序列：拒绝→重新响应→接受、重复拒绝恢复一致、human/mcp 来源组合；服务级与权限测试留待后续切片；不能改产品实现来让测试变绿 |
| FEEDBACK-02 人工反馈闭环收尾 | ✅ ZCode 会话认领（2026-09-30，用户指派），后端完成 | `src/server/project-store.mjs` 反馈/接受/拒绝语义、`scripts/project-store-test.mjs` | 拒绝候选按快照键完整恢复、不残留候选字段（shots 与 transitions 共用）；提交只标记明确响应的意见。`ProjectStudio.tsx` 源码弹窗勾选 UI 在集成者手中，交接要点：按 shot.feedback 渲染 pending 意见复选框，仅提交勾选项，勿自动全选 |
| SKILL-01 shotcraft 纳入仓库 | ✅ ZCode 会话认领（2026-10-01）：已写代码+已运行验证，分支 feat/skill-shotcraft | skills/shotcraft/、scripts/skills/、scripts/tests/docs/（已交付）；MCP resources/craft_guide/respond_to_feedback 注册提给集成者 | 内容为原创蒸馏，许可归档见 skills/shotcraft/SOURCES.md（8 无许可仓库仅思路级、StuGRua 按受限处理）；分发用 scripts/skills/install.mjs；工具速查表由 sync-platform.mjs 从 MCP-GUIDE 生成，mcp-guide-sync 测试兜底（1 项占位等集成者注册后启用） |
| INT-00 / FB-01 | ✅ 集成者（本会话）2026-10-02 完成，已合并 main | `src/server/feedback.mjs`、`scripts/tests/feedback/` | 见第三节 |
| FB-02 / FB-03 | ✅ ZCode 会话 2026-10-02 完成，分支 `feat/feedback-ui-mcp`（待评审合并）：FB-02 独占 `src/project/FeedbackComposer.tsx`、`ReviewCompare.tsx`；FB-03 独占 `src/server/mcp-feedback-tools.ts`、`scripts/tests/feedback/mcp-feedback-tools.test.mjs`、`ui-feedback.audit.mjs`、`helpers.mjs`。热点文件的最小接线也在本分支完成（`ProjectStudio.tsx` 替换接线、`reference-server.mjs` 时间广播、`render-worker.mjs` stills 任务、`index.mjs` stills 路由、`mcp-tools.ts`/`mcp-server.ts` 工具注册、`mcp-guide-sync.test.mjs` 合并读取两个工具源文件），集成者评审时重点看这几处 | 见第三节两个 ✅ 小节的命令与结果 |
| FB-04 端到端验收 | ⬜ 待认领（QA-01 owner）；FB-02/FB-03 已就绪，可开工 | `scripts/tests/collaboration/`；只测，不改实现 | 见第三节 |
| SONG-00 ～ SONG-06 任意歌曲拆解 | ⬜ 待认领（2026-10-01 规划），详见第三节“并行冲刺 SONG” | `src/song/`、`analyzer/`、`engine-base/`、`scripts/tests/song/` | SONG-00/01 可与反馈冲刺并行；下载模型/建 Python 环境前须用户确认 |
| INTEGRATION 集成与发布检查 | 当前 AI 暂任，交接时明确更换 | 下述共享热点文件 | 审阅接口变更、统一接线、合并分支、跑全量验收，最后更新本计划 |

认领方式：先在本节登记工作包、分支、范围与状态，再开始编辑。没有登记的同事不被视为已经接单；需要跨范围修改时，先把建议交给对应 owner/集成者，不能两边同时覆盖同一文件。

### 共享热点：单一集成者修改

- `src/project/ProjectStudio.tsx`、`src/project/api.ts`、`src/main.tsx`：主界面接线与共享类型。
- `src/server/project-store.mjs`、`src/server/index.mjs`、`src/server/mcp-tools.ts`：持久化、命令路由与 MCP 注册。
- `src/server/render-worker.mjs`、`src/server/reference-server.mjs`：当前渲染接线。
- `package.json`、`package-lock.json`、`vite.config.ts`、`tsconfig.json`、公共样式与 `ROADMAP.md`。

ASSET-01 的面板和路由先从自己的目录导出；集成者在热点文件中完成 import/路由注册。需要新依赖时提交“包名、用途、版本”给集成者，由一人更新依赖及 lockfile，避免并行安装造成锁文件冲突。

### ASSET-01 可独立推进的边界

1. 先实现素材元数据：稳定 ID、名称、类型（产品图/Logo/字体/音频）、内容 hash、受控资源引用、版权/来源说明、锁定状态。
2. 品牌规范：色板、允许字体、必保留元素、禁用规则。不要将 API key、本机绝对路径或文件字节混入前端业务对象。
3. UI 通过注入的适配器做 `list / import / update / remove`；初期用独立 fixture 验证，不自行写 `projects/*/project.sqlite`。
4. 先交付面板、类型与测试，再由集成者把品牌资产引用接入镜头依赖和缓存键。删除被引用素材的行为必须有明确保护，不能默认直接删除。
5. 不自行改视频引擎契约、歌词时间、转场模型、MCP 全局注册或数据库 schema。

#### ASSET-01 交付状态（2026-10-01，ZCode 会话）

- **已交付**：`src/server/brand/validation.mjs`（纯校验：类型白名单、锁定补丁规则、色板 #RRGGBB、字体字重 100..900、引用键）；`src/server/brand/brand-store.mjs`（JSON 元数据 + 内容寻址 blob `blobs/<sha256>`、原子写、相同字节共享 blob、修订号递增；删除保护：锁定或 `referencedBy` 非空一律 409，解除后回收孤儿 blob）；`src/brand/types.ts`（前端契约 + `BrandAssetAdapter` 注入接口）；`src/brand/BrandPanel.tsx`（导入/锁定/删除/色板/必保留/禁用编辑，自包含样式不动公共 CSS）；`src/brand/fixture.ts`（内存演示适配器）；`public/brand-demo/`（示例库与占位 Logo）；`scripts/tests/brand/brand-store.test.mjs`（9 项）。
- **给集成者**：挂载 `BrandPanel` 时提供真实 adapter（HTTP 接 `brand-store.mjs` 即可）；接入镜头依赖时调用 `bindBrandReference/unbindBrandReference`（键形如 `shot:<id>:<用途>`），缓存键应包含素材 `hash`。素材库默认在本机 `.cache/brand/`（`VIDEOGRAPH_BRAND_DIR` 可覆盖），已被 .gitignore 覆盖。
- **已运行验证**：`npm run build` ✓；`node --test scripts/tests/brand/brand-store.test.mjs scripts/tests/collaboration/feedback-lifecycle.test.mjs scripts/project-store-test.mjs scripts/lyrics-transitions-test.mjs` → 36/36 通过。
- **已知限制（诚实边界）**：未接 HTTP 路由与主界面（属集成者）；引用计数由调用方维护，删除保护依赖它；无跨设备同步；`fixture.ts` 的 hash 是演示摘要，非持久实现。

### Git 与运行环境

- 产品目录已建立独立 Git 仓库；参考仓库在边界外。依赖、缓存、令牌、数据库、BGM 与成片已由 `.gitignore` 排除。
- **基线已建立并推送（2026-09-30，用户指令）：commit `3c8243a` → github.com/G1en-114/videograph-validation main。**
- **2026-10-02 集成合并（用户指令）**：main 快进合并 `feat/brand-assets`（ASSET-01）→ `feat/skill-shotcraft`（SKILL-01）→ INT-00 → FB-01，历史线性无冲突；合并后构建与全部领域测试通过。 之后的功能改动按工作包登记范围进行；不要把未登记的混合工作区当作可合并基线。
- 基线形成后，每人使用独立 clone 或独立工作副本和独立功能分支：`feat/lyrics-transitions`、`feat/brand-assets`、`test/collaboration`。不共享同一工作目录来回切分支。
- 同机并行时使用不同端口、独立 `.cache/`、`.queue/` 和 `projects/`；不得让两个开发服务同时写同一份工程数据库/服务令牌。前端 service URL、后端允许的 Origin 与 MCP service URL 必须对应同一套实例。
- 当前默认实例是前端 5188、后端 5191；同事建议预留前端 5288、后端 5291。隔离配置还需在代码中接通后验收，未接通前应使用不同机器或只运行一套服务。
- 不 force-push、不重写他人已共享历史、不为消除冲突使用整文件覆盖或 `reset --hard`。冲突先按领域意图合并，再跑测试。

### 合并顺序与验收门槛

1. 先合并纯数据契约/模块内部测试，再合并实现，最后由集成者接入主界面、路由和 MCP。
2. 每个工作包说明：新增/修改文件、公开接口、数据迁移、需要的配置、已执行测试、已知限制。不要只交一张截图。
3. 要求至少构建通过、工作包测试通过；涉及共享核心或验收脚本时再跑全量回归。
4. 不用真实用户工程做破坏性测试；夹具使用独立临时目录和服务实例，结束后只清理本次创建的数据。
5. 只有集成验收通过，才在这里将状态改成完成。其他协作者的尚未验收成果不得被当作事实依赖。

