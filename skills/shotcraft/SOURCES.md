# SOURCES.md — shotcraft 语料来源与许可归档

> 本文件是 shotcraft 技法库的许可与来源事实源（SKILL-01 要求）。分发或修改技法内容前先读这里。
> **蒸馏方式声明**：shotcraft 全部内容为**原创文字描述与自写伪代码**——逐条技法是"怎么想、怎么写"
> 的通用工艺总结，不含任何上游仓库的逐字代码、场景文件或资产。全库 7 个代码围栏均为自写
> 伪代码/公式（其中 effects.md 的火花/后期公式改述自 MIT 许可的 pdoom-video 引擎行为）。
> 逐行级的"哪句话来自哪个仓库"映射未追踪；本表记录各文件的主要语料与许可等级，处理规则按等级执行。

## 一、逐文件来源

| 文件 | 主要语料 | 许可等级 | 处理 |
|---|---|---|---|
| `SKILL.md` | pdoom-video + 全部语料的总纲 | 见下表 | 原创 |
| `references/shots.md` | pdoom-video（MIT）17 种分镜范式 + three.js 换歌系 | MIT 为主 | 原创；MIT 语料可对照 |
| `references/transitions.md` | pdoom-video handshake 等 | MIT | 原创 |
| `references/effects.md` | pdoom-video 引擎手法（火花/后期/odometer…） | MIT | 原创；公式为改述 |
| `references/media-styles.md` | opus-5.5-music-video-art-styles（MIT，"Simulate the process, not the look" 宪法）、bohemian-tokenry-video、super-motion-graphics、power-video 等 | MIT 为主 | 原创；已署名宪法出处 |
| `references/fx-tx-addendum.md` | pdoom-video-fr（MIT）等生态新增 | MIT 为主，个别无许可仓库仅思路级 | 原创 |
| `references/pipeline-playbook.md` | videowright、motion-graphics-music-video-skill、Claude-Opus-5.5-Motion-Video-Skill、awesome-opus-5-5-video-prompts 等 | 混合；无许可仓库仅思路级 | 原创 |
| `references/platform-videograph.md` | 本项目自有（`src/server/`、`src/shot/`、`docs/MCP-GUIDE.md`） | 无外部来源 | 其中工具速查表由 `scripts/skills/sync-platform.mjs` 自动生成 |

## 二、语料仓库清单（27 个，2026-09 快照）

### MIT / ISC（18）——可引用、可对照、可复用代码（保留出处）

| 仓库 | 许可 |
|---|---|
| pdoom-video（Giacomo Magnanini，主语料） | MIT |
| pdoom-the-printed-world、Zh-CN-pdoom-video | MIT |
| pdoom-video-fr | MIT |
| ClaudeAnimationBase（John Heibel） | MIT |
| Pdoom-video-anime-version（John Heibel、yingdao） | ISC |
| opus-5.5-music-video-art-styles（Miranda Dixon-Luinenburg） | MIT |
| bohemian-tokenry-video（Joshua Ledbetter） | MIT |
| videowright（Videowright Contributors） | MIT |
| context-window、functional-emotions-video、jessecaple-pdoom-video | MIT |
| motion-graphics-animated-lesson-plugin、motion-graphics-music-video-skill | MIT |
| opus-video-audio-skill、power-video、super-motion-graphics、why-wont-you-let-me-help | MIT |

### 无许可（8）——**仅思路级描述**，不保留其文字表达或代码

Claude-Opus-5.5-Motion-Video-Skill、GitRaymond-glitch-pop、PDoomVideo、
awesome-opus-5-5-video-prompts、headroom-animation、ndemo、pdoom-video-win95、shelter-mv

### 自定义受限许可（1）——按无许可处理

StuGRua-PDoomVideo（`LICENSE.md` 为"许可范围"混合权利声明：代码/音乐/歌词/字体/角色素材分属
不同权利来源，不能整体套用同一许可证）——本库对其只做思路级描述。

## 三、处理规则（修改技法内容前必读）

1. 新增技法引用了上表 MIT/ISC 仓库的表达 → 允许，但须在本文件登记出处。
2. 涉及无许可/受限仓库 → 只写自己组织的技法描述，逐字段落一律不收；拿不准的段落先列给用户确认。
3. 音乐、歌词、字体、角色素材的权利**不因技法蒸馏而转移**；本库不含任何此类素材。
4. 上游许可快照为 2026-09；上游变更许可时须重新审查本文件。

## 四、待用户确认清单

- 无。当前快照审查中未发现需要删除的逐字段落；StuGRua-PDoomVideo 已按最保守方式处理。
