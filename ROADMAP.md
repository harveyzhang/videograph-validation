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

#### INT-00 收尾当前工作区（集成者，先做）

- 现有 12 个已修改 + 4 个未跟踪文件（端口/Origin 可配、令牌在 listen 成功后写入、镜头预览按帧对齐区间、转场帧对齐、`transition-integration-audit.mjs`、`docs/THIRD-PARTY.md`、`.env.example`）。
- 跑 `npm run build`、三组 `node --test`、`node scripts/transition-integration-audit.mjs`；通过后在 `feat/lyrics-transitions` 提交，再从它切 `feat/feedback-anchors` 等分支。
- 验收：`git status` 干净；审计输出已记录在本节。

#### FB-01 意见数据契约与后端（独占 `src/server/feedback.mjs`（新建）、`scripts/tests/feedback/`；在 `project-store.mjs`/`index.mjs` 只做最小接线）

1. 新建 `feedback.mjs`，将意见校验与状态迁移从 `project-store.mjs` 抽出（行为不变，先让现有 27 项测试保持全绿）。
2. 意见新增可选字段（旧数据缺字段仍合法，无需迁移）：
   - `anchor`: `{ t?: number, range?: {start,end}, lyricElementId?: string, region?: {x,y,w,h}（0..1 归一化）, aspect?: 'composition'|'motion'|'typography'|'color'|'timing'|'lyrics'|'other' }`。服务端校验：`t`/`range` 必须落在目标镜头窗口（转场则在其时间窗）内；`lyricElementId` 必须存在于当前 `lyricPlan`；`region` 各值在 0..1。
   - `preserve: string[]`（≤12 条，每条 ≤300 字）：必须保留的内容。
   - `author: 'human'|'mcp'`，`thread: [{ by, text, at }]`：澄清对话。
3. 提交新增 `feedbackResponses: [{ feedbackId, outcome: 'addressed'|'partial', how: string }]`（≤2000 字）。兼容旧参数：只传 `addressedFeedbackIds` 时视为 `addressed` 且 `how` 为空。`partial` 也进入 `responded`，界面要突出显示。响应写入意见的 `response` 字段，绑定 `codeHash/inputToken`；后续再提交时，旧响应照常失效。
4. 新命令 `askFeedback(projectId, targetKind, targetId, feedbackId, question)`：agent 追加 `thread` 提问，意见状态改为 `needs-clarification`（不算 pending，也不能被接受）；人回复（`replyFeedback`）后回到 `pending`。导出拦截保持“存在未接受意见即拒绝”。
5. 新只读查询 `feedbackInbox({ projectId?, status? })`：返回每条意见的 `{ projectId, targetKind, targetId, title, window, inputRevision, locked, note, prompt, lyricPlan 摘要, baseline 是否存在, thumb, nextStep }`。`nextStep` 是给 agent 的明确下一步，例如“读源码 → 改写 → submit 带 feedbackResponses”。锁定目标标为“等待人解锁”。
6. HTTP：`GET /feedback?projectId=&status=`、`POST .../feedback/:fid/ask`、`POST .../feedback/:fid/reply`；`POST .../feedback` 接受 `anchor/preserve`。
- 测试（不启服务）：锚点越界拒绝；lyricElementId 失效拒绝；partial 响应可见但需人接受；提问→回复→响应→接受全流程；旧格式意见与旧参数提交仍可用；inbox 不泄露服务令牌/本机绝对路径。

#### FB-02 人的意见输入与对比界面（独占 `src/project/FeedbackComposer.tsx`、`src/project/ReviewCompare.tsx`（新建）及其样式；`ProjectStudio.tsx` 只做替换接线，由集成者合并）

1. 意见节点改为 `FeedbackComposer`：正文；“定位到当前预览时间”按钮；从本镜头 `lyricPlan.elements` 下拉选择元素；方面 aspect 单选；“必须保留”多行列表，并提供常用项一键添加（歌词时序 / 镜头时长 / 配色 / 文字内容）；可选在缩略图上框选区域。
2. 预览时间来源：`reference-server.mjs` 注入的播放器每 250ms 以 `postMessage({ type: 'videograph:time', t })` 告诉父页面（只接受来自预览 origin 的消息）。这处改动属于热点文件，提给集成者。
3. 意见列表显示：锚点标签（`@12.40s`、`元素：火花`）、保留项、agent 的 `response.how`、`partial` 警示、`needs-clarification` 下的问题与回复框。
4. `ReviewCompare`：修改前 / 当前候选两列，同一时间点的静帧并排显示（用 FB-03 的 stills），并可切到双播放器；“采用 / 拒绝”按钮沿用现有接口与“我已检查当前候选”的确认约束。
5. 无障碍：所有输入有 label；键盘可完成添加意见与采用；状态不只靠颜色区分。
- 验收：`scripts/tests/feedback/ui-feedback.audit.mjs`（无头 Edge + 独立临时 projects 目录 + mock 服务或独立端口）覆盖添加带锚点意见、刷新后仍在、回复澄清、对比后采用。

#### FB-03 MCP 意见与画面工具（独占 `src/server/mcp-feedback-tools.ts`（新建）；`mcp-tools.ts`/`mcp-server.ts` 注册由集成者合并；stills 渲染在 `render-worker.mjs` 增加任务种类，提给集成者）

1. `project_feedback_inbox({ projectId?, status? = 'pending' })`：调用 FB-01 的 inbox。不传 projectId 时返回所有工程的待办，这是 agent 的入口。
2. `project_feedback_ask({ projectId, targetKind, targetId, feedbackId, question })`。
3. `project_shot_submit` / `project_transition_configure` 增加可选 `feedbackResponses`；保留 `addressedFeedbackIds` 兼容。
4. `project_stills({ projectId, shotId|transitionId, times?: number[] (≤6), version: 'current'|'before-feedback', width? = 960 })`：后台 job 用真实引擎渲染指定时间点，缓存键 = 版本 key + t + 宽度。完成后，`project_job_get` 以 **MCP image content**（base64 PNG）返回图片，同时返回文件路径。默认时间点：意见锚点 `t`，再加窗口的 0/0.5/1。agent 借此“看到哪里要改”，并能对比修改前后。
5. 每个工具描述写明“AI 不能接受意见”。
- 验收：扩展 `scripts/mcp-server-test.mjs`，走真实 stdio：inbox 返回带锚点意见 → stills 返回 image 内容 → 带 feedbackResponses 提交 → validate → 意见为 responded 且 `response.how` 存在 → 其他镜头 codeHash 不变。

#### SKILL-01 shotcraft 纳入仓库并接入 MCP（独占 `skills/shotcraft/`、`scripts/skills/`、`scripts/tests/docs/`；MCP 注册提给集成者）

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

### 通用音频输入（未完成）

- 本地音频元数据、响度/包络、节拍/段落分析；输出来源与置信度。
- 可选人声分离、歌词识别和强制对齐；模型/权重下载、GPU/磁盘成本须明确，不未经许可拉取数 GB 依赖。
- 不匹配原曲的输入不得复用旧歌词时间轴；无歌词时生成器乐型方案，不伪造歌词。
- 音乐数据参数化，ToB 脚本/旁白使用同一时间模型。

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
| INT-00 / FB-01 / FB-02 / FB-03 / SKILL-01 / FB-04 | ⬜ 待认领（2026-10-01 规划），详见第三节“当前冲刺” | 各包在第三节写明独占文件 | 认领时在此行拆分登记负责人与分支；热点文件只交集成者合并 |
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
- **基线已建立并推送（2026-09-30，用户指令）：commit `3c8243a` → github.com/G1en-114/videograph-validation main。** 之后的功能改动按工作包登记范围进行；不要把未登记的混合工作区当作可合并基线。
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

