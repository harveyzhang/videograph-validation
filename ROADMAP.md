# VideoGraph 总体计划与进度

> **唯一计划文档。** 自 2026-09-30 起，所有后续架构、阶段任务、优先级和验收计划均在此维护；不再建立并行的 TODO/阶段规划文件。HANDOFF 只放运行、交接说明并链接这里。
> 状态约定：✅ 已实际验收；🚧 实现/验证中；⬜ 尚未完成。写出代码不等于完成。

## 一、产品目标与不变原则

服务 **ToB 产品宣发** 与 **C 端音乐人 PV**。以 `pdoom-video` 这类优秀 AI 创作工程为参照，使工程可以稳定复现、局部修改。

**定位（2026-10-02 用户确认）：VideoGraph 是 LLM 的 After Effects。** LLM 是操作者，经 MCP 建合成、写镜头、调节奏、渲染与自查；前端是**给人看片和提修改意见的审阅室**（看、定位、对比、采用/拒绝），不是让人手工编辑的 AE。能力优先补给 LLM：让它看得见运动、量得出节奏、读得懂音乐结构、能局部修改；审美由人通过意见与采用来裁决。

当前端到端目标：只提供该参考工程的 BGM，由 agent 通过 MCP 创建工程、操作镜头、校验预览，最终导出完整 PV。工程复现与“从零原创”必须区分；审美上的满意需要成片反馈，不能用“没有报错”代替“完美”。

**用户于 2026-09-30 确认的执行顺序：先完整复现 → 再用同一首歌独立创作自己的 PV → 对人类与 AI 共用的整个产品做交叉检查、修复问题并持续优化。** 两支成片使用独立工程与明确署名；不能只修改提示词、复用原画面就宣称完成独立创作。

1. **LLM 是操作者，人是审阅者。** 工程结构、工具与反馈都为 LLM 精确操作而设计；前端以带音乐的全片播放、时间线、定位意见、版本对比为主。节点画布降为结构视图（依赖关系说明），不再是核心交互（2026-10-02 前为“节点画布是核心”）。
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

### LLM-AE 冲刺（2026-10-02 起，最高优先；分支 `feat/llm-ae`，集成者本会话）

目标：补齐 LLM 作为“AE 操作者”的感知与控制能力，重点是**节奏把控**和**审美自查**；前端转为审阅室。顺序：`AE-P0 → AE-P1 → AE-P2 → AE-P3`，每个工作包完成后在此记录命令与结果。

#### AE-P0 感知工具（LLM 的眼睛、耳朵和尺子）

| 编号 | 交付 | 验收 |
|---|---|---|
| AE-01 | `song_cue_sheet`：按小节输出文本节奏表（时间、段落、能量 1–5、拍内鼓点型 `K`/`S`/`.`、人声、歌词、镜头/转场边界、能量突变标记），可按时间段读取 | 纯函数单测：小节划分、能量分级、鼓点量化、无歌词/无下拍回退；参考工程实跑 |
| AE-02 | `project_filmstrip`：一段连续帧拼成一张带时间/拍号/下拍标记的网格图（≤24 格，或 `around` 某时刻 ±N 帧） | 真实服务+渲染进程跑通，返回 MCP image |
| AE-03 | `project_contact_sheet`：全片每镜头 1–3 帧拼图，标镜头序号/标题/段落/时长；未生成镜头画占位 | 同上 |
| AE-04 | `project_rhythm_report`：顺序渲染低分辨率帧，算画面运动能量与亮度，对照下拍/kick/snare 计算命中率、超前滞后、相关系数（含最佳偏移）、死区、过忙、段落能量跟随、闪烁风险；返回文本报告 + 能量对照图 | 指标纯函数单测（合成序列）；真实服务跑通；对 pdoom 参考片跑一次作为“好作品”基准写入此处 |
| AE-05 | 技法库经 MCP 提供：`craft_guide` 工具、`videograph://` resources、`respond_to_feedback` / `design_rhythm` prompts | mcp-guide-sync 占位测试改为真实断言 |
| AE-06 | 工具好用性：`project_job_get` 支持 `waitSeconds` 阻塞等待；MCP server 更名 `videograph`（保留 `mcp:pdoom` 脚本别名） | 单测/冒烟 |
| AE-07 | 清理：构建修复（`VideoProject` 补 `status`/`analysis.error`/`confirmedBy` 可选类型）；删除与本文件重复的四份状态文档 | `npm run build` 通过 |

**AE-P0 交付记录（2026-10-02，集成者，分支 `feat/llm-ae`，独立 worktree `../vg-llm-ae`，未提交）**

- 状态：AE-01～07 ✅ 已写代码 + 已运行验证（夹具引擎全自动；真实 pdoom 引擎在独立实例 5391 上实跑）。**人工未验收**：节奏指标与图片对 LLM 创作的实际帮助，要在《THE LAST AUDIT》上用真实 agent 试用后由人判断。
- 新文件：`src/server/rhythm.mjs`（节奏表与节奏报告纯函数）、`src/server/ae-page.mjs`（渲染页内采样/拼图/画图）、`src/server/mcp-ae-tools.ts`（5 个 MCP 工具）、`scripts/tests/ae/rhythm.test.mjs`（13 项）、`scripts/tests/ae/ae-tools.test.mjs`（8 项真实 stdio + 服务 + Edge 渲染）、`scripts/ae-reference-baseline.mjs`（参考片基准脚本）。
- 接线：`render-worker.mjs` 新任务 `filmstrip / contact-sheet / rhythm`（只读、内容寻址缓存；节奏采样帧 `.gray` 与报告分离，指标升级 `RHYTHM_VERSION` 只重算不重渲）；`index.mjs` 入队校验、`GET /projects/:id/cue-sheet`、`GET .../jobs/:jid?wait=`（≤50s），apiVersion `project-service/v5-llm-ae`；`mcp-server.ts` 更名 `videograph` 0.3.0，注册 resources（指南 + shotcraft）与 prompts（`respond_to_feedback`、`design_rhythm`）；`package.json` 新增 `npm run mcp`（`mcp:pdoom` 为别名）；`api.ts` 补 `status/analysis.error/confirmedBy` 可选类型（另一会话未提交的 `SongStagePanel.tsx` 已验证可编译）。
- 文档：MCP-GUIDE（toolset 行、§3 新小节、§4/新歌流程自查步骤、§6 移除已实现项）、shotcraft 1.2.0 + sync-platform、README/CLAUDE.md 新定位；`mcp-guide-sync` 占位测试改为真实断言。删除四份重复状态文档。
- 已运行：`node --test "scripts/tests/**/*.test.mjs" scripts/project-store-test.mjs scripts/lyrics-transitions-test.mjs` → **117 项全过、0 失败、0 跳过**（原 96 项/1 跳过；新增 AE 21 项，SKILL-01 占位测试转为真实断言）；`npm run build` ✓；`node scripts/ae-reference-baseline.mjs`（真实引擎，独立实例 5391）✓。
- **参考片基准（pdoom 参考复现，工程 `75efaf18`，独立实例，15fps 全片 2350 帧）**：画面峰 128 个（0.82/s），94% 落在拍/鼓点/词起点上；下拍命中 38%（33/87），中位偏移 25ms；高能量小节下拍命中 39%；运动中位 0.0155。分镜头：镜头 1（器乐+人声、无鼓）75% 在拍/词上；副歌 1 下拍命中 71%、85% 在拍上。“问题”只剩闪烁：22.9–23.8s 与 124.5–125.3s 副歌字块整屏黑/白/橙交替 6–7 次/秒（已用 filmstrip 逐帧确认属实，是原作风格，按规则只报告给人）。四处“死区”（第二/三次恳求、结尾）与 14 小节不跟拍均为参考片有意的克制，归为风格提示。
- 校准过程（如实记录）：首版用绝对阈值与 gamma 亮度，参考片被报“过忙/命中率低/闪烁 6 次”等大量假阳性 → 改为：灰度 8×8 子采样压颗粒；运动等级以参考片小节运动五分位（0.014/0.021/0.033/0.049）为刻度；闪光改线性相对亮度且暗侧 <0.8；词起点计入节奏锚；发现分“问题/风格提示”。
- 耗时：节奏报告瓶颈是 1080p 真实渲染（引擎 scale 只支持整数 ≥1），约 90–140ms/帧：单镜头 30fps 约 25–75s，全片 15fps 约 5.5 分钟；采样帧缓存后重算 <3s。filmstrip ≈2–5s，全片缩略图（22 镜头）≈30s。
- 发现的平台约束：MCP SDK 客户端默认请求超时 60s → 所有等待上限 50s。
- 诚实边界：闪烁只看全画面平均亮度，局部大面积闪光会漏报，不能代替正式光敏检测；与鼓点包络的相关系数在参考片上接近 0，目前只作信息展示，不产生“问题”；指标只对“节奏是否在拍上”有把握，不评价审美。

#### AE-P1 节奏设计与审阅室

- **节奏设计节点**：LLM 写镜头前先提交 `rhythm plan`（每段强度目标、切镜密度、重音落点清单、留白），服务端校验重音对应真实鼓点、段落间有反差、镜头时长分布合理；人可在渲染前对它提意见。
- **风格基准节点**：色板、字体体系、材质颗粒、运动语言、构图规则、参考图；所有镜头读取，静态检查颜色是否在色板内。
- **意见范围扩展**：全片 / 段落 / 风格范围的意见（如“太素了，多加转场”跨镜头）。
- **审阅室前端**：主视图为带音乐的全片播放器 + 时间线（段落、拍网格、歌词、镜头、转场、意见标记、画面/音频能量曲线）；划像对比与同步播放；每版显示 LLM 的修改说明；参数 JSON/源码编辑改为只读或折叠。
- **提交前自评**：校验后 LLM 必须看 filmstrip + contact sheet + rhythm report，按层次/构图/可读性/节奏/一致性/新意逐项写证据帧；自评不代替人采用。

#### AE-P2 可局部修改的工程结构

- 场景声明可调属性 schema 与“提示轨”（关键帧时间写成 `{ bar }` / `{ beat }` / `{ word }`，自动吸附拍点）；新增 `property_set` / `keyframe_set`，LLM 局部修改不必重写整个场景。
- 引擎节拍工具函数：`f.events.next('downbeat')`、`sinceLast('snare')`、`anticipate(event, lead)`、`phraseProgress`；scene-lint 禁止大动作写死秒数。
- 多变体：同一镜头 2–3 个变体静帧供人二选一。

#### AE-P3 图层与偏好

- 合成/图层模型（文字、形状、图片/Logo、3D、代码图层），每层变换/混合/入出点；ToB“换 Logo、改标题”变为属性修改。
- 偏好记忆：从采用/拒绝历史提炼工程级偏好，随收件箱提供；独立上下文的评审 agent。
- 不从音频建工程：ToB“脚本 + 素材”入口（接 ASSET-01）。

#### 继续推进的既有工作（与 AE 并行）

修构建并提交 SONG-02 半成品（其他会话）；SKILL-01 接入 MCP（=AE-05）；完成《THE LAST AUDIT》并用 AE 工具自查；《琵琶行》全链路成片 + SONG-03 中文字体子集化与 scene-lint；BUG-03/04；ASSET-01 接入工程；重跑转场集成审计。停止：人直接编辑参数/源码的功能扩展。

### 人工意见冲刺（2026-10-01 起，已基本完成）：人工意见 → MCP 定位 → 改写视频代码

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

#### ✅ FB-04 端到端验收（QA-01 owner，2026-10-02 完成；独占 `scripts/tests/collaboration/feedback-e2e.audit.mjs`、`helpers-fb04.mjs`；另改 `scripts/audit-all.mjs` 接线；只测，不改实现）

- **交付**：`scripts/tests/collaboration/feedback-e2e.audit.mjs`（人机协作端到端）+ `helpers-fb04.mjs`（带 `__pdoom.stream` 的 1920×1080 微型导出引擎与 8 秒两镜头工程，用于导出清单/增量缓存断言）；`audit-all.mjs` 追加该审计（`SKIP_FB04_E2E=1` 可跳过）。
- **运行**：`node scripts/tests/collaboration/feedback-e2e.audit.mjs` → **全绿，约 1 分钟**（第 17 轮定稿）。主线（真实参考工程 + 无头 Edge 人 + 真实 MCP stdio agent）：指纹导入 22 镜头/21 转场 → 人在预览播放器上定位时间锚点+保留项「歌词时序」→ 刷新仍在 → MCP inbox/stills(PNG)/ask → 人界面回复 → 外科式改写+feedbackResponses → 校验 → **只改目标镜头**（其余 21 镜头 module/inputRevision/codeHash 逐项不变）→ 导出 409 拦截 → 人拒绝（恢复参考源码、响应入 responseHistory、旧候选接受 409）→ 再改写 → 过期版本号接受 409 → 修改前版本可预览 → 并排对比（真实引擎双静帧）→ 采用 → **导出放行**（202 受理+取消验证闸门）。
- **保留项逐像素证明**：改写前后在 3 个词起点帧（now/servant/and +0.12s）对比——改写可见（掩码内 351/1570/1927 像素变化），掩码外 **0 像素差异**（确定性引擎，卡拉OK状态逐像素未变）。
- **微型工程完整导出**：意见闭环后导出 8s×24fps=192 帧（真实 ffmpeg x264+aac，混音用参考 BGM），`manifest.json` 记录采用后冻结版本 revision=4、audioHash=参考 BGM 指纹、两镜头新渲染分段；二次导出 2/2 分段缓存命中；歌词数据零改动。
- **实现取舍**：参考工程 156s 全片导出对回归过重（HTTP 校验 fps 只许 24/30/60 → 3759 帧），改用「202+取消」证明放行，完整导出+清单断言落到微型工程；微型工程的人机步骤走与 UI 同一 HTTP/MCP 契约（等价性由 ui-feedback.audit 验证）。
- **新坑（已写进夹具与记忆）**：① vite 预览服务 `fs.allow` 对系统 Temp 路径下的文件不生效——真引擎 `fetch /data/lyrics.json` 被 SPA 回退成 index.html；夹具必须放仓库 `.cache/` 下（FB-02/03 的夹具引擎不 fetch 数据文件所以没踩到）。② vite dev server 用 `localhost` 偶发绑到 ::1 导致探测全拒，必须显式 `--host 127.0.0.1`；启动失败自动换端口重试一次。③ transition-runtime 顶层 import 依赖 `gl.ts` 的 `FSPass/makeRT` 可解析，微型引擎须照抄这两个导出。④ 导出期间 publishValidation 会递增工程版本，`manifest.revision` 是入队时冻结的版本。
- **回归**：`node --test`（96 项：95 过 0 失败 1 跳过-有意）通过；完整 `npm run audit`（project-view-audit + feedback-e2e）**全绿**；`npm run build` 失败——3 个类型错误全部位于并行会话的未提交 WIP `src/project/SongStagePanel.tsx`（SONG-02 范围，非本会话产物，不代改）；本工作包交付物均在 scripts/ 与 ROADMAP.md，不在 tsc 编译范围。

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

> **🚧 2026-10-02 集成者（本会话）部分完成**：第 1 条（`audio.engineFile`，预览/导出/混音均读该字段；参考工程缺省 `audio/pdoom.mp3`，缓存键不变）、第 2 条（新歌工程 `timeline.ts` 为空表，时间线完全来自工程镜头；未生成镜头回落到通用模板）、第 3 条前三项（复制引擎核心 + 通用场景，排除 24 个绑定原曲的场景文件；`_window-template.ts` 已按真实 Scene API 重写——原版用了引擎不存在的 `begin2D/f.window/word.progress`，无法编译）、第 5 条（新歌工程写独立 CREDITS）。**未做**：第 3 条的提交时 scene-lint 接线、第 4 条中文字体子集化（中文歌词目前会落到浏览器回退字体）、新歌工程仍会构造 P(DOOM) HUD（模板以 `hud: 0` 关闭）。

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

#### ✅ SONG-05 建工程与 MCP 接入（2026-10-02 集成者完成，已运行验证；服务路由和 MCP 注册由集成者合并；同步更新 `docs/MCP-GUIDE.md`）

> 交付：`src/server/song-project.mjs`（新建：建工程/通用引擎快照、分析落盘与契约校验、确认、歌词修正、规划）、`src/server/analysis-jobs.mjs`（后台分析，失败转 `analysis-failed`，可经 HTTP `POST .../song/analysis/retry` 重试）；`project-store.mjs`/`index.mjs`/`reference-server.mjs`/`render-worker.mjs`/`mcp-tools.ts` 接线；服务 apiVersion `project-service/v4-song`。
> 实现取舍：MCP 工具为 `project_create_from_audio`（`_from_bgm` 为别名）、`song_analysis_get`、`song_lyrics_submit`、`song_analysis_confirm`、`project_plan_submit`；`song_analysis_run/patch` 未做（留在 MCP-GUIDE §6）。v2 分析存于工程目录 `analysis/analysis-v2.json`，工程快照只存 `toFullSong` 派生数据；歌词原文不进快照/MCP 输出。规划复用 SONG-04 `validatePlan`（锚点推导切点），省略 plan 时用 `planFromSections` 兜底并标注非 AI。新歌工程在 `planned` 前拒绝 validate/stills/render；导出拒绝无源码镜头。修复草稿中的问题：分析器被当 CLI 调用、`listProjects` 遇无 song 工程崩溃、分析任务重启后被塞进渲染队列、拍点过滤按对象字段写错、`song_analysis_get` 用 POST 发出。
> 验证：`node --test "scripts/tests/**/*.test.mjs" scripts/project-store-test.mjs scripts/lyrics-transitions-test.mjs` 96 项 95 过 0 失败 1 跳过（新增 `scripts/tests/song/song-project.test.mjs` 10 项）；`npm run build` 通过；端到端见 SONG-06 记录。

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
   - `song_analysis_confirm`：确认分析。**2026-10-02 用户决定允许 AI 确认**（原计划为仅人工确认）；MCP 调用记为 `confirmedBy: mcp`，界面/HTTP 默认 `human`，人仍可复核。
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

#### SONG-06 第 1 项验收记录（2026-10-02，集成者，合成 click track）

- 命令：`node --experimental-strip-types --no-warnings scripts/song-e2e-audit.mjs`（音频 `.cache/e2e-song/click132.wav`：132 BPM、12 小节、21.82s，由 `analyzer/clicktrack_test.make_click_track` 生成，不入库）。脚本起独立服务（端口 5291、独立工程目录与令牌），**全程走 MCP 工具函数**。
- 结果 ✅：建工程 → T1 分析 6s（bpm 132.01、49 拍 / 13 下拍、1 段，无歌词层）→ agent `song_analysis_confirm`（`confirmedBy: mcp`）→ 锚点规划 3 镜（0–7.267 / 7.267–14.567 / 14.567–21.818）→ 每镜模板改写提交 + validate 通过 → 导出 h264 655 帧 @30（= 曲长 × 30）+ AAC，ffprobe 逐帧计数一致 → 导出音轨与源音频零偏移相关系数 **0.999111**（≥0.999）→ 二次导出缓存命中 **3/3**。
- 拒绝路径：分析未确认时规划 409；镜头未生成时导出 409；无歌词音频不出现任何歌词。
- 抽帧人工查看（9.0s）：镜头 2 青色节拍框 + 拍号计数，真实引擎渲染，无 P(DOOM) HUD。
- 第 2 项回归：新增单测确认 pdoom 原 BGM 仍走指纹导入（22 镜头、无新歌状态、音频缺省 pdoom.mp3）；未在本轮跑浏览器级 `npm run audit:reference`。
- 尚未做：第 4 项真实歌曲（《琵琶行》）尚未走新服务全链路。

#### SONG-06 真实歌曲验收记录（2026-10-02，《琵琶行》沉-海，用户提供不入库）

- **全链路**：T0 解码（126.69s/44.1k）→ T1 beat_this GPU（bpm 169.45、342 拍、85 下拍、4 段）→ T3 分段 ASR（64 行 / 371 字级 token、零时间词 0）→ validateAnalysis PASS → planFromSections 兜底 5 镜 → toFullSong 兼容导出（包络 3801 帧@30fps）。
- **分段修复（本轮实现）**：全曲一次 ASR 中文时间戳不可用（156/291 零时间、时刻堆积）→ 按 T1 下拍切 ~28s 段逐段转写后 0 零时间；段边界时间回退由 _monotonic_lines 全局不减钳制修复（契约要求行按时间排列）。
- **中文适配**：ASR 切行按中文标点（。，、！？；）；token 配额按字数（西文按词）。
- **待人确认（SONG-02 界面接线后操作）**：① 转写有误听（古风唱词，如「一封情意是花」等句需人校对）；② bpm 169.45 偏高（琵琶轮指密集），需人耳校验或在校正界面 tap tempo；③ 段落只有 4 段且无标签（unknown），需人命名。
- 回归：66/66 测试 + build ✓（分段实现在 analyze.py，无 Node 侧改动）。

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

### 已登记问题（2026-10-01 产品测试轮，登记人：QA-01 ZCode 会话）

本轮全量产品测试（领域测试、六项回归、工程视图、参考引擎、转场集成审计）结论为产品功能无缺陷；以下为测试中发现并登记的工具链/运维问题。均为 ⬜ 未修复；BUG-01/02 与 FB-04 同属验收脚本域，可在 FB-04 开工时一并处理（修复须按 QA-01 边界：只改测试脚本，不为让测试变绿改产品实现）。

- **BUG-01** ✅ 已修复（2026-10-01，随 CLEANUP-01）：断言改为数据驱动——从镜头列表读取所选镜头真实标题再断言 inspector，不再硬编码文案。`scripts/project-view-audit.mjs` 对任意工程可用。
- **BUG-02** ✅ 已作废（2026-10-02，QA-01 核实）：`scripts/mcp-server-test.mjs` 已随 CLEANUP-01 与旧工坊一起删除，`.queue/` 目录不复存在，残留问题失去载体；等价验收已由 `scripts/tests/feedback/mcp-feedback-tools.test.mjs`（真实 stdio、自带临时目录清理）覆盖。无需修复。
- **BUG-03** ⬜（运维提醒，低优先）工程服务（5191）无热重载，启动早于源码修改时静默运行旧代码：本轮实测服务 19:12:44 启动、27 个源文件 19:16:03 修改，测试前提失效，重启后全绿。建议任选其一：启动日志打印启动时间与提示；或 `/health` 返回 `bootTime`，审计脚本比对 `src/` 最新 mtime 并警告。
- **BUG-04** ⬜（2026-10-02，QA-01 登记并实测）共享实例的**缓存预览服务会退化**：长驻 5191 上 spawn 的 preview vite（`previews` Map 缓存）在一段时间/兄弟审计实例启停后，其 esbuild 转换子进程死亡（`The service is no longer running: write EPIPE`），所有 `/src/*.ts` 500 → 引擎页起不来、project-view-audit 的 `#info` 走秒超时；重启 `npm run service` 立即恢复（已实测两轮）。建议：/preview 命中缓存后先探活（GET /@vite/client 或一次 main.ts transform），失败即 evict + respawn；顺带评估多个 vite 实例共享 `cacheDir=.cache/reference-vite` 的写冲突。

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
| SKILL-01 shotcraft 纳入仓库 | ✅ ZCode 会话认领（2026-10-01）：已写代码+已运行验证，已合并 main（分支已删除） | skills/shotcraft/、scripts/skills/、scripts/tests/docs/（已交付）；MCP resources/craft_guide/respond_to_feedback 注册提给集成者 | 内容为原创蒸馏，许可归档见 skills/shotcraft/SOURCES.md（8 无许可仓库仅思路级、StuGRua 按受限处理）；分发用 scripts/skills/install.mjs；工具速查表由 sync-platform.mjs 从 MCP-GUIDE 生成，mcp-guide-sync 测试兜底（1 项占位等集成者注册后启用） |
| INT-00 / FB-01 | ✅ 集成者（本会话）2026-10-02 完成，已合并 main | `src/server/feedback.mjs`、`scripts/tests/feedback/` | 见第三节 |
| FB-02 / FB-03 | ✅ ZCode 会话 2026-10-02 完成，PR #1 已于 2026-10-02 合并 main（e258508，构建通过；node --test 86 项 82 过 0 失败 4 跳过）：FB-02 独占 `src/project/FeedbackComposer.tsx`、`ReviewCompare.tsx`；FB-03 独占 `src/server/mcp-feedback-tools.ts`、`scripts/tests/feedback/mcp-feedback-tools.test.mjs`、`ui-feedback.audit.mjs`、`helpers.mjs`。热点文件的最小接线也在本分支完成（`ProjectStudio.tsx` 替换接线、`reference-server.mjs` 时间广播、`render-worker.mjs` stills 任务、`index.mjs` stills 路由、`mcp-tools.ts`/`mcp-server.ts` 工具注册、`mcp-guide-sync.test.mjs` 合并读取两个工具源文件），集成者评审时重点看这几处 | 见第三节两个 ✅ 小节的命令与结果 |
| FB-04 端到端验收 | ✅ ZCode 会话（QA-01 owner）2026-10-02 完成，全绿（约 1 分钟/轮） | `scripts/tests/collaboration/feedback-e2e.audit.mjs`、`helpers-fb04.mjs`（另接线 `scripts/audit-all.mjs`）；只测不改实现 | 见第三节 ✅ 小节：真实参考工程人机闭环 + 微型工程完整导出/清单/缓存断言 + 词起点帧逐像素保留项证明；BUG-02 已核实随 CLEANUP-01 作废 |
| SONG-00～06 任意歌曲拆解 | ✅ ZCode 会话（2026-10-02）：SONG-00 契约/适配器已验收（e2b2138）；SONG-01 代码+T1 click track 验收通过（F0.9961/bpm误差0.002/下拍32/32，librosa 兜底），pdoom 基准 F0.8372/bpm误差0.65，T3 环境+权重部署中；SONG-02 校正界面、SONG-03 engine-base+scene-lint、SONG-04 规划器已交付代码（66/66 测试）；SONG-05 ✅ 集成者 2026-10-02 接线完成；SONG-06 第 1 项（click track 全链路）✅，第 2/4 项待做；SONG-03 部分完成（见第三节） | `src/song/`、`analyzer/`、`engine-base/`、`scripts/tests/song/`；SONG-03/05 的 `reference-server.mjs`/`render-worker.mjs`/`project-store.mjs` 接线归集成者 | 环境：videograph-analyzer(py3.9,T0/T1) + videograph-t3(py3.12,T3+beat_this)；模型缓存 F:icg\.models；许可表 analyzer/MODELS.md（NC 模型一律不进默认链路）；双环境详情见 analyzer/environment.md；SONG-06 验收由本会话（QA-01 owner）执行 |
| AE LLM-AE 冲刺 | 🚧 集成者（本会话）2026-10-02 起，分支 `feat/llm-ae`（独立 worktree `../vg-llm-ae`）；AE-P0 ✅ 已运行验证（见第三节记录），AE-P1 起未开始 | `src/server/rhythm.mjs`、`src/server/mcp-ae-tools.ts`、`scripts/tests/ae/`，以及 render-worker/index/mcp-server 接线 | 见第三节 LLM-AE 冲刺 |
| INTEGRATION 集成与发布检查 | 当前 AI 暂任，交接时明确更换 | 下述共享热点文件 | 审阅接口变更、统一接线、合并分支、跑全量验收，最后更新本计划 |
| CLEANUP-01 移除旧演示视图（单镜头工坊/教学/创意/旧工作流），只保留真实工作台 | ✅ ZCode 会话（集成者）2026-10-01 完成，已合回 main | 删除 `src/shot/`（full-song.json 迁至 `src/song/data/`）、`src/components/`、`src/llm/`、`src/blackboard/`、`src/memory/`、`src/lyrics/`、`src/render/`、`src/pdoom/tasks.ts`、`src/types.ts`、`src/styles.css`（其中工程工作台复用的 53 条外壳/节点样式迁入 `project.css`）、7 个旧审计脚本；重写 `main.tsx`、`vite.config.ts`、`audit-all.mjs`、`mcp-server.ts`（0.2.0，仅 `project_*` 工具）；移除顶栏死链接 | 已运行验证：`npm run build`（包体 1706KB→451KB）、领域测试 24/24 + brand/协作/文档/反馈套件 45 过、`npm run audit`（project-view-audit 全绿）、`npm run audit:reference`、`transition-integration-audit`（隔离实例四模式全过）；MCP-GUIDE 同步 + sync-platform + skill 1.1.0。附注：audit-all 默认目标为参考复现工程，`VIDEOGRAPH_AUDIT_PROJECT` 可覆盖 |

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


---

## 十二、代码审查记录（2026-10-01 快照；同日的 CODE_REVIEW/EXECUTIVE_SUMMARY/PROGRESS_DASHBOARD/PROJECT_STATUS 四份重复文档已于 2026-10-02 删除，以本文件为准）

### ✅ 2026-10-01 全面代码审查

**审查范围**: 全项目功能实现、架构质量、测试覆盖、待办事项

**总体评分**: 7.5/10 (良好，可上线但需完成关键集成)

**代码规模**:
- 源文件: 36 个
- 代码行数: 3,278 行 (src/)
- 测试通过率: 85/86 (98.8%)
- 包体大小: 451KB (gzip: 146KB)

**质量评分**:
| 维度 | 评分 | 说明 |
|------|------|------|
| 功能完整性 | 7/10 | 核心链路通，待完成 SONG 集成、FB-04、独立创作验收 |
| 代码质量 | 8/10 | 清晰的领域模型，良好的测试，部分文件偏大 |
| 架构设计 | 8/10 | 职责清晰，版本控制完善，缺分布式支持 |
| 测试覆盖 | 7/10 | 85/86 通过，缺 E2E 和性能测试 |
| 性能 | 8/10 | 缓存命中率高，轮询待改 SSE |
| 安全性 | 6/10 | 基础隔离到位，渲染沙箱待加强 |
| 可维护性 | 8/10 | 文档详尽，代码可读，部分模块待拆分 |
| UI/UX | 8/10 | ComfyUI 风格统一，功能完整，响应性待优化 |

**关键发现**:

✅ **优点**:
- 清晰的领域模型: inputRevision/inputToken/codeHash 版本控制
- 完整的人工意见闭环: FB-01/02/03 全部实现并测试通过
- 高缓存命中率: 22/22 增量导出
- 详尽的文档: ROADMAP、MCP-GUIDE、技法库
- ComfyUI 风格 UI 统一

🔴 **P0 阻塞问题**:
1. 工作区有未提交改动 (12 个文件已修改，4 个未跟踪)
2. 独立工程有待响应意见 (镜头 prompt1: "多加转场")
3. 单曲绑定未解除 (15 个场景 `ly.get('原句')`)

🟠 **P1 重要问题**:
4. 转场功能未实际使用 (21 个转场全是硬切)
5. 歌词元素未实际使用 (22 个 lyricPlan 都是空的)
6. 渲染进程端口冲突 (历史上 2 次失败)

🟡 **P2 次要问题**:
7. 轮询延迟 2500ms (应改 SSE)
8. 包体可优化 (451KB，可按路由懒加载)
9. 部分文件偏大 (ProjectStudio.tsx/project-store.mjs 各 578 行)

**技术债务**:
- 安全性: 渲染进程无超时/资源限制，new Function 无沙箱
- 可靠性: 转场集成审计未运行，缺 E2E 测试
- 架构: 缺分布式锁、架构图、HTTP API 文档

**上线检查清单**:

必须完成 (阻塞上线):
- [ ] 提交当前工作区改动 (INT-00)
- [ ] 解除单曲绑定 (SONG-03)
- [ ] 完成 SONG 集成 (SONG-02-06)
- [ ] FB-04 端到端验收通过
- [ ] 独立创作工程审美验收

强烈建议 (影响体验):
- [ ] 修复渲染端口冲突
- [ ] 响应"多加转场"意见
- [ ] 添加 SSE 替代轮询
- [ ] 加强渲染沙箱 (超时+资源限制)

**详细报告**:
- 原详细报告（CODE_REVIEW 等）已删除，可在 git 历史 `ffc8f49` 查阅。

**审查人**: Claude (Opus 5.5)  
**下次审查**: 2026-10-14 (两周后)

