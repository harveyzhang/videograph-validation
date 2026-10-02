# platform-videograph.md — VideoGraph 平台适配

平台根目录：本仓库（权威交接文档：`HANDOFF.md`）。
唯一执行管线是**全引擎管线**（旧工坊 mini-engine 队列已随 CLEANUP-01 移除）：

| | 全引擎管线 |
|---|---|
| 入口 | `videograph` MCP（旧名 videograph-pdoom） 的 `project_*` 工具 |
| 场景契约 | **Scene 类**（three.js + GLSL + Canvas2D 分层，pdoom 引擎同源） |
| 工程 | `projects/<uuid>/engine/`（完整引擎拷贝）+ `project.sqlite` + `artifacts/`（验证 png/mp4）+ `exports/` |
| 转场 | 引擎级（参数化配置）+ 镜头自转场 |
| 产物 | 编译+5 帧抽检 → 预览 → 整片 MP4 导出 |

判断方法：会话里挂着 `mcp__videograph__project_*`（或旧名 `mcp__videograph-pdoom__project_*`） 工具且用户在谈某个 PV 工程 → 本路线。

---

## 全引擎管线（videograph MCP）

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
- **本 skill 的 effects.md/shots.md 全部手法在本路线上原样可用**（范例代码就在
  `engine/app/src/scenes/` 里，直接照抄模式）。

### 工具链工作流（按序，勿跳步）

<!-- BEGIN:generated-from-MCP-GUIDE (scripts/skills/sync-platform.mjs 自动生成；勿手编) -->

**工具速查（自动生成自 `docs/MCP-GUIDE.md` §3，toolset 2026-10-02；勿手编——更新请跑 `node scripts/skills/sync-platform.mjs`）**

| 工具 | 参数 | 作用 |
|---|---|---|
| `project_list` | — | 本地工程列表 |
| `project_create_from_audio` | `audioPath` | 任意本地音频建工程，可选 `name / lyricsText / lrcPath / language / stages`（`t0/t1/t… |
| `project_create_from_bgm` | `audioPath` | `project_create_from_audio` 的别名（保留兼容） |
| `project_get` | `projectId` | 完整工程：镜头、转场、意见、版本、输出规格。默认只返回歌曲摘要，`includeAnalysis: true` 返回完整词级歌词/节拍/包络 |
| `song_analysis_get` | `projectId` | 读取 `videograph-analysis/v2` 分析与 `provenance`、当前 `inputRevision`。默认层 `au… |
| `song_lyrics_submit` | `projectId, expectedInputRevision, lyrics` | 整层替换歌词：`{ lines: [{ text, start, end, words: [{ w, start, end }] }], la… |
| `song_analysis_confirm` | `projectId` | 确认分析，`analysis-draft → analysis-confirmed`。agent 可调用，记为 `confirmedBy: m… |
| `project_plan_submit` | `projectId, expectedInputRevision` | 仅 `analysis-confirmed` 可用。`plan: [{ lineText | sectionIndex | t, title?… |
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
| `project_job_get` | `projectId` | 可选 `jobId`；省略则列出最近任务。看 `status / progress / error / result`。带 `waitSeco… |
| `project_job_cancel` | `projectId, jobId` | 取消排队或运行中的任务 |
| `song_cue_sheet` | `projectId` | 按小节的文本节奏表：时间、段落（▶段首）、能量 1–5（小节 rms 在全曲 p5–p95 中的位置）、每拍 2 格鼓点型（`K` kick … |
| `project_filmstrip` | `projectId` | 一段连续帧拼成一张网格图（≤24 格），每格标 `时间 小节.拍 ●下拍 K S “词”`，下拍帧橙框。范围：`shotId` / `tran… |
| `project_contact_sheet` | `projectId` | 全片每镜头 1–3 帧（`ratios`，默认 `[0.45]`）拼图，标序号/标题/时间/段落/状态；无源码镜头画占位。看全片一致性、色彩推… |
| `project_rhythm_report` | `projectId` | 顺序渲染目标时间段（范围参数同 filmstrip；`sampleFps` 10–60，默认 ≤30 秒用工程帧率、更长用 15），返回文本报… |
| `craft_guide` | — | shotcraft 技法库节选（≤12k 字符）。`topic`：`shots / transitions / effects / media… |

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

### 铁律

- 提示词（prompt）修改后**必须重新提交代码**（提示词与代码是一对的）。
- 不覆盖其他镜头、不覆盖原参考实现——submit 只作用于目标镜头且产生新版本。
- 验证/渲染都是后台任务：提交后轮询 `project_job_get`，不要并行提交同一镜头多版本。
- 词/拍时间一律来自 `ctx.lyrics / ctx.audio`（`lyrics.get(文本).words[i].start`、
  `audio.timeOfBeat/beatAt/events`），绝不硬编码秒数——换 BGM/换对齐数据就全崩。

## 数据集

`src/song/data/full-song.json`：`{ song, bpm, duration, envFps, lines[](词级), sections[], beats[],
downbeats[], kick[](强度对), snare[], rms/low/mid/high/vocal/drums[] }`——从 pdoom-video 的
data/*.json 切出，工程服务建工程（指纹导入）时读取。
换歌 = 重新生成该数据集（SONG 冲刺的通用分析管线），契约不变。
