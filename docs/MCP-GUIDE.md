# VideoGraph MCP 使用指南

> 写给通过 MCP 操作 VideoGraph 工程的 agent，以及维护 MCP 的开发者。
> **维护规则：** 新增、删除、改名或改变任何 MCP 工具的参数/语义时，必须在同一提交中更新本文件（工具表 + 相关流程），并更新下方 `toolset` 版本行。`scripts/tests/docs/mcp-guide-sync.test.mjs`（SKILL-01 交付）会检查工具名与本文件一致。
> 计划与进度不写在这里，见 [ROADMAP.md](../ROADMAP.md)。

toolset: 2026-10-01 · server `videograph-pdoom` 0.2.0 · 状态：§3 为已实现工具；§6 为计划中工具，未实现前不要调用。

> CLEANUP-01（2026-10-01）：旧演示视图（单镜头工坊 / P(DOOM) 教学）的 `shot_queue_*`、`shot_cards_*`、`pdoom_*`、`lyric_research_draft` 工具已随代码一并移除；本指南只覆盖真实工作台的 `project_*` 工具。

## 1. 启动与连接

```sh
npm run service      # 工程服务 127.0.0.1:5191，写 .cache/service-token
npm run mcp:pdoom    # MCP stdio server（由 MCP 客户端拉起，一般不手动运行）
```

MCP server 只是工程服务的本机客户端：所有 `project_*` 工具经 HTTP + 服务令牌调用 5191，不直接写数据库或工程文件。工具返回 `工程服务需要运行` 时，先启动 service。

客户端配置示例（stdio；路径按本机修改。该配置尚未在每种客户端中逐一验证）：

```json
{
  "mcpServers": {
    "videograph": {
      "command": "node",
      "args": ["--experimental-strip-types", "--no-warnings", "F:/aicg/video-graph-demo/src/pdoom/mcp-server.ts"],
      "env": {
        "VIDEOGRAPH_SERVICE_URL": "http://127.0.0.1:5191"
      }
    }
  }
}
```

- 并行实例使用独立端口与令牌：同时设置 `VIDEOGRAPH_SERVICE_URL` 和 `VIDEOGRAPH_SERVICE_TOKEN_FILE`，与该实例的 service 一致（见 `.env.example`）。
- 工具列表在客户端会话启动时加载；MCP 代码更新后需重连 MCP 才能看到新工具。

## 2. 核心概念

| 概念 | 含义 |
|---|---|
| 镜头 shot | 稳定 `id`、`title`、时间窗 `start/end`（全曲秒）、`prompt`（原始意图）、`params`、`lyricPlan`、`module`（场景源码文件）、`codeHash`、`source`（imported / mcp-authored / human-authored） |
| 转场 transition | 相邻两镜头之间的独立节点：`intent`、`mode`(cut/dissolve/wipe/dip)、`duration`、`easing`、`direction` |
| `inputRevision` | 每个镜头/转场各自的输入版本。所有写操作必须传 `expectedInputRevision`；不匹配返回 409，先重读再改 |
| 镜头状态 | `imported` 参考导入待验证 → `needs-generation` 待 AI 改写 → `needs-validation` 待验证 → `ready` 已通过 5 帧抽检 |
| 修改意见 feedback | 挂在镜头/转场上的独立记录：`pending` 待 AI 响应 →（可选 `needs-clarification` AI 提问·待人回复 → `pending`）→ `responded` 已响应·待人确认 → `accepted` 人已采用。可带 `anchor`（`t / range / lyricElementId / region / aspect`）、`preserve`（必须保留项）、`thread`（澄清对话）、`response`（`outcome: addressed|partial`、`how`） |
| `reviewBaseline` | 首条未接受意见加入时冻结的“修改前版本”，用于对比与拒绝回滚 |

硬规则：

1. **AI 不能接受意见。** `accepted` 只能由人在界面完成，MCP 没有也不会有接受工具。技术验证通过 ≠ 人满意。
2. 只改目标：`project_shot_submit` 只作用于一个镜头并生成不可变的新源码文件；不要借响应一条意见顺手重写其他镜头。
3. 保留原始意图：不要用 `project_shot_update` 把人的意见写进 `prompt` 覆盖原文；意见本身已单独保存。
4. 锁定的镜头/转场必须由人解锁后才能修改；不要自行解锁来完成任务。
5. 时间一律从分析数据推导（词起点、拍点），不在场景代码里硬编码秒数。
6. 有未接受意见或 `needs-generation` 的镜头/转场时，`project_render` 会被拒绝，这是预期行为。

## 3. 工具参考（已实现）

### 工程

| 工具 | 必填参数 | 作用 / 返回 |
|---|---|---|
| `project_list` | — | 本地工程列表 |
| `project_create_from_bgm` | `audioPath` | **当前只支持 pdoom-video 原始 BGM**（字节指纹匹配，复用已对齐分析，标记为参考导入）；其他音频返回 422。任意歌曲见 §6 与 ROADMAP SONG 冲刺 |
| `project_get` | `projectId` | 完整工程：镜头、转场、意见、版本、输出规格。默认只返回歌曲摘要，`includeAnalysis: true` 返回完整词级歌词/节拍/包络 |

### 镜头

| 工具 | 必填参数 | 作用 / 返回 |
|---|---|---|
| `project_shot_lyrics` | `projectId, shotId` | 镜头窗口内词级歌词、`instrumental` 标记、已有 `lyricPlan` |
| `project_shot_source` | `projectId, shotId` | `{ shot, code, contract, lyricContext, source }`：当前真实 TS 源码与完整引擎契约（ENGINE.md） |
| `project_shot_update` | `projectId, shotId, expectedInputRevision, patch` | patch 仅允许 `title / prompt / params / lyricPlan / locked`。改 `prompt` 或 `lyricPlan` → `needs-generation`；改 `params` → `needs-validation`；三者都会让已响应意见退回 `pending` |
| `project_shot_submit` | `projectId, shotId, expectedInputRevision, code` | 提交**完整**场景文件（无 markdown 围栏），可带 `summary`、`addressedFeedbackIds`。生成 `vg-<sha256>` 不可变模块，状态 → `needs-validation` |
| `project_feedback_add` | `projectId, shotId, expectedInputRevision, text` | 新增镜头意见（≤8000 字符），记为 `author: mcp`（代人转述时在正文注明）；首条未接受意见时冻结 `reviewBaseline`；镜头 → `needs-generation` |

`lyricPlan` 结构：`{ summary, elements: [{ name, quote, meaning, treatment, kind?: entity|action|metaphor, cueWord? }] }`。`quote` 必须是本镜头窗口内的真实歌词，`cueWord` 必须在该句中，否则拒绝。有歌词的镜头至少一个元素。

### 转场

| 工具 | 必填参数 | 作用 / 返回 |
|---|---|---|
| `project_transition_get` | `projectId, transitionId` | 转场节点、意见、配置、前后镜头元素方案、准确时间窗 |
| `project_transition_update` | `projectId, transitionId, expectedInputRevision, patch` | patch 仅 `intent / locked`；新 intent → `needs-generation`，需随后 configure |
| `project_transition_configure` | `projectId, transitionId, expectedInputRevision, config` | `config: { mode, duration ≤1.5, easing, direction }`，可带 `addressedFeedbackIds`。过渡在切点后发生，不改全曲时长与歌词时序 |
| `project_transition_feedback_add` | `projectId, transitionId, expectedInputRevision, text` | 新增转场意见，同时冻结两侧镜头版本 |
| `project_transition_validate` | `projectId, transitionId` | 后台抽检切点前后 5 帧，返回 job |

### 预览、验证、导出、任务

| 工具 | 必填参数 | 作用 / 返回 |
|---|---|---|
| `project_preview` | `projectId` | 可选 `shotId / transitionId / version: current\|before-feedback`。返回本机真实引擎播放器 `url` 与 `range`。供有浏览器能力的人/agent 查看 |
| `project_validate` | `projectId, shotId` | 后台编译 + 5 时间点抽检，返回 job；完成后镜头 `validation.thumb` 指向 `artifacts/<key>.png`（**单张**缩略图） |
| `project_render` | `projectId` | 可选 `fps: 24/30/60`、`samples: 1/4/12`。后台导出完整 MP4，冻结当前版本，命中分段缓存 |
| `project_job_get` | `projectId` | 可选 `jobId`；省略则列出最近任务。看 `status / progress / error / result` |
| `project_job_cancel` | `projectId, jobId` | 取消排队或运行中的任务 |

产物文件位于 `projects/<projectId>/<file>`（如 `artifacts/<key>.png`、`exports/<jobId>/pv.mp4`），同机 agent 可直接读取 PNG 做视觉检查。

## 4. 标准流程：响应人的修改意见

```
找意见 → 读上下文 → 看画面 → 改代码 → 提交并声明响应 → 验证 → 自查 → 交给人确认
```

1. **找到待处理意见**：`project_list` → `project_get`，筛选 `shots[].feedback` 与 `transitions[].feedback` 中 `status === 'pending'` 的条目；注意读 `anchor`（定位到哪里）和 `preserve`（不能动什么）。（FB-03 完成后改用 `project_feedback_inbox` 一次取全。）
2. **读上下文**：对目标镜头调用 `project_shot_lyrics` 与 `project_shot_source`。同时读：原始 `prompt`（不能丢的意图）、意见原文、`reviewBaseline`（修改前版本）、当前 `inputRevision`。
3. **看画面**：先看现有 `validation.thumb`；需要动态时用 `project_preview`。不要只凭代码猜效果。
4. **改代码**：在当前源码基础上修改，遵守引擎契约与 shotcraft 技法（见 §7）；只改意见指向的部分，意见说要保留的内容（歌词时序、Logo、镜头长度等）保持不变。
5. **提交**：`project_shot_submit`，`expectedInputRevision` 取刚读到的值，`addressedFeedbackIds` 只列这次**真正处理了**的意见，`summary` 写清改了什么。
6. **验证**：`project_validate` → 轮询 `project_job_get` 直到 `done/error`。失败时读 `error`，修正后重新提交（最多两轮，仍失败就停下来报告）。
7. **自查**：读新缩略图，确认意见被处理、保留项没坏、其他镜头的 `codeHash` 没变。
8. **交接给人**：回复中写明处理了哪些意见、如何处理、哪些没有处理及原因。然后停止：采用或拒绝由人在界面完成。

转场意见同理：`project_transition_get` → `project_transition_configure`（带 `addressedFeedbackIds`）→ `project_transition_validate`。

## 5. 常见错误与陷阱

| 现象 | 原因 / 处理 |
|---|---|
| 409 `镜头版本已改变` | 别人或界面刚改过；重新 `project_get` / `project_shot_source` 后基于新版本重做 |
| 二次提交后旧意见变回 `pending` | 每次 submit 都会使旧响应失效（它们针对旧代码）。新提交里要把仍然成立的意见 ID 一并放入 `addressedFeedbackIds` |
| `反馈 ID 必须来自本镜头尚未接受的意见` | ID 拼错、属于其他镜头，或已被接受 |
| 拒绝后镜头是 `needs-generation` | 人拒绝候选会恢复修改前代码，但仍需按意见重新改写 |
| `project_render` 返回 409 | 还有未接受意见、待改写镜头或待配置转场；不要试图绕过 |
| 场景运行报错或黑帧 | 先看 `project_job_get` 的 `error`；引擎每帧错误会中止，不会静默黑帧 |
| 新工具不可见 | MCP 会话需要重连 |

## 6. 计划中的工具与字段（未实现，见 ROADMAP「当前冲刺」）

| 名称 | 预期作用 |
|---|---|
| `project_feedback_inbox` | 跨镜头/转场（可跨工程）列出意见，带定位、上下文和下一步提示。**后端已就绪**：`GET /feedback?projectId=&status=open|pending|needs-clarification|responded|accepted` |
| `project_feedback_ask` | AI 向人提问澄清。**后端已就绪**：`POST /projects/:id/{shots|transitions}/:tid/feedback/:fid/ask`（人回复走 `.../reply`，仅限 human） |
| `project_shot_submit` / `project_transition_configure` 的 `feedbackResponses` | 逐条说明响应：`[{ feedbackId, outcome: addressed|partial, how }]`，partial 必须写 how。**后端已就绪**，MCP 参数待 FB-03 暴露；目前只能用 `addressedFeedbackIds` |
| `project_feedback_add` 的 `anchor` / `preserve` | 后端已就绪（人从界面添加时使用）；MCP 参数待 FB-03 |
| `project_stills` | 按指定时间点渲染多张静帧（当前版本或修改前版本），供 agent 看画面 |
| `craft_guide` + MCP resources/prompts | 通过 MCP 读取 shotcraft 技法与“按意见改镜头”流程模板 |
| `project_create_from_audio` | 任意本地音频建工程（可附歌词/LRC/语言/分析级别）；参考曲仍走指纹导入。`project_create_from_bgm` 保留为别名 |
| `song_analysis_get / song_analysis_run / song_analysis_patch` | 分层读取、运行固定分析阶段、提交修正（标 mcp 来源） |
| `song_lyrics_submit` | 提交歌词文本草稿；仍需人确认，AI 不能确认分析 |
| `project_plan_submit` | 提交新歌的镜头规划（覆盖全曲、切点吸附拍且不切词），校验后生成待改写镜头 |

实现后：把条目移入 §3，更新 §4 流程，并修改 toolset 版本行。

## 7. 与 shotcraft skill 的分工

- 本文件：**平台操作**（有哪些工具、状态机、版本规则、流程）。
- shotcraft skill：**创作技法**（分镜范式、转场、特效、媒介风格、卡拉OK/节拍纪律）。源目录在 SKILL-01 完成后为仓库内 `skills/shotcraft/`。
- skill 中的平台说明（`references/platform-videograph.md` 路线 B）以本文件为准；SKILL-01 让同步脚本从本文件生成，避免两份说明分叉。
