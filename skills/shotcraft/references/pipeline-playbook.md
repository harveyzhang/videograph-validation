# pipeline-playbook.md — 制作管线与工作流（25 个 Opus 5.5 视频仓库蒸馏）

三条产品级管线、换歌/本地化改造清单、验证闭环、agent 编排模式、风格 prompt 词汇表。
范例路径相对语料目录（清单见 [SOURCES.md](../SOURCES.md)）。

---

## 1. 三派管线对比

| 维度 | 代码逐帧渲染派 | 浏览器实录派 | AI 生成混合派 |
|---|---|---|---|
| 代表 | videowright / super-motion-graphics / opus-video-audio-skill / PDoomVideo 系 | ndemo | makevoid 两插件（Fal GPT Image + MiniMax H3 + p5 合成） |
| 画面来源 | 代码是唯一画家（Canvas/WebGL/DOM/Remotion） | 真应用在真浏览器跑，CDP screencast 抓帧 | AI 关键帧+图生视频 sprite + p5 合成层 |
| 确定性 | 帧=f(t)+seeded RNG；virtual time shim；byte-identical 回归 | 无逐帧确定性，靠 fixtures+setup 复位近似 | 无帧级确定性；靠身份 sheet 锁定+style bible 逐字复用+accept 审查替代 |
| 主时钟 | TTS 词级时间戳 / 音乐 beat grid / MIDI note events 三种子型 | TTS 旁白时长（先拿 audioDuration，动作拉伸对齐） | 歌曲母带（帧区间精确覆盖 master，禁变速改拍） |
| 验证 | CR checklist+渲染断言+contact sheet+测量报告 | `done` 条件逐动作断言+单段实测 | accept 审查门+lipsync 三看（正常速/慢放/嘴部 crop）+帧数校验 |
| 适用 | 风格可控、精确节拍、无限迭代复用 | 演示真实存在的应用 | 有预算的角色叙事内容 |

**共同底线**：音频/节拍数据先行（measure, never estimate）；画面必须被"看"（Read the PNG /
contact sheet / 独立 critic）；导出后机器验证（ffprobe/全解码/帧数断言）。

## 2. 换歌改造清单（把一套确定性引擎适配新 BGM，六层按依赖序）

- **L1 音频分析**：Demucs 分 stems → librosa tempo ±8% 搜索窗拟合常速拍网格（防半倍/双倍）
  → kick/snare 相位定 downbeat（`--bar-offset`）→ 手写 sections.json 命名段落。范例
  power-video/docs/ADAPTING.md（裸 mp3→成片 9 步全流程）。
- **L2 对齐**：vocal stem 上 MMS_FA 出 CTC emissions（20ms 帧）→ 全局 Viterbi + 行窗口约束
  （每行只能在草稿 ±1.5s 落）+ 行间 garbage 态 → 与 Whisper 词时间交叉验证出置信度（1.0/0.6/0.3）
  → PRON 词典拼读缩写。进阶：双模型融合（MMS_FA+wav2vec2 LV60K）。
- **L3 剪辑（可选）**：bar-grid 剪辑器只删整小节保拍网格，剪接点在人声最安静的合法偏移
  （downbeat ±范围 5ms 步进搜两侧 RMS 最小），重映射全部时间数据，recut 出 social/long
  多版本 `?cut=` 加载。范例 power-video/analysis/make_edit.py。
- **L4 场景/时间轴**：锚点全数据驱动+可选化+缺失段 fallback 到 dev karaoke 调试板（先验数据
  再做画面）；模板场景参数化复用；共享 handoff 几何常量表；16 场景级项目先写 BEATSHEET 分镜表
  （context-window/docs/BEATSHEET.md）。
- **L5 调色板（换皮肤第一刀）**：只改 3 个文件——palette 的 signal 三阶色+post halation
  着色+GLSL heat ramp；上游命名保留可 merge。UI 拟物皮肤则 THEME 表跟随叙事。
- **L6 导出**：按 measured cost（非等时）切段、整帧边界、各段 --noaudio、无损 concat 后一次
  mux 音频（防 AAC priming 咔哒）；多浏览器并行可断点续渲。

**先写歌后做画面**（context-window/docs/SUNO.md）：Style prompt 里直接为画面埋钩子（stutter
edits、打击乐=打字节拍、abrupt ending），歌词结构即分镜表；生成 4–6 版挑"咬字最清楚"的方便对齐。

## 3. 本地化双语卡拉OK（fr + Zh-CN 合并结论）

1. 发音词典（MMS_FA 只吃罗马化字母，缩写/连诵拼读）；
2. 子词切分 → 每词 `syl:[[start,end],…]` 音节时间，`wordProgress()` 按音节分段 wipe；
3. 译文**不替换而是按语义切段**，`to[]` 索引绑英文词区间，随英文逐词时间逐字点亮；
4. 板内 UI 文案 `tr(en,zh)` 包裹，歌词层走语域配对表（中文衬线配英文衬线）；
5. 字体子集脚本从"全部译文+扫描源码所有中文字符串"生成，改文案后重跑；
6. 加载时校验字幕与歌词数据强一致，不一致即抛错。

## 4. 验证闭环汇总（各仓库最佳实践）

- **"看"的纪律**：`render.ts stills` 出 PNG 后 **Read every PNG**；contact sheet 审片
  （`--sheet`，章节接缝用 `--cuts` 逐 cut 检查 hand-off 匹配 shape/colour/position）；三级
  自检=sheet（全片形状）→ strip（关键动作逐帧）→ crop（脸部全分辨率）（ClaudeAnimationBase
  ANIMATION_GUIDE.md:169）。
- **音频不可听补偿**（opus-video-audio-skill）："You cannot hear audio. Never tell a user a
  cue 'sounds good'"——storyboard 写成带 `expect quiet/loud` 时间码断言的 cue spec，envelope
  断言不过 exit 非零；**变体指纹**防假对比（sed 改源后四个"不同乐器"变体指标完全相同的事故）；
  TTS 用 Whisper 转写回与脚本 difflib 比对。
- **独立 critic 子代理**：每轮渲染、人看片之前，发给全新 sub-agent；不看代码只看图+rubric；
  固定四段输出（rubric 打分+时间戳证据 / Top5 问题按代价排序 / Protect 最多 3 个不许丢的 /
  上轮问题 fixed?）——现成可复用审查模板（opus-video-audio-skill critic_prompt.md）。
- **回归**："one change, one default"+重渲已批准帧做 **byte-identical diff** 作为不动已签核
  内容的证明（Claude-Opus-5.5 skill）。
- **交付 gate**：全帧解码验证+音频相关性采样（>0.9998）+逐词投影出框检查点+静止段筛查+
  ffprobe 规格断言+sha256 写入 export.json（pdoom-the-printed-world qa/、StuGRua）。
- **渲染物理**：角度→像素先算 `px=angular_size/fov×frame_height`（"月亮只有 11px"案例）；
  线性光累加+末尾一次 tone map；曝光随视场反号 `exposure=(fov_v/fov_tele)^-1.35`；
  stale-frame 防御（fresh dir+等进程退出）；"numbers catch exposure and geometry; only
  looking catches composition"。

## 5. Agent 编排模式

- **lead + 平行 scene agents**（super-motion-graphics / functional-emotions 7 章 / PDoomVideo）：
  lead 独占 palette/_motifs/timeline；scene agent 拿 brief（需求段落**逐字粘贴**——"agents
  start cold"），只许写自己的场景文件，共享文件只读、bug 上报；集成后 tsc+sheet --cuts 接缝检查。
- **TREATMENT 先行**（super-motion-graphics SKILL.md:54）：概念/贯穿 motif/tone+项目专属
  not-slop list/palette+type 规则/sync 规则/**plate table**（每板逐镜头段落：画面、落点、
  笑点、与下一板的 hand-off）→ 用户批准后才写代码；用户笔记记为 `Revision N` 循环。
- **wave 调度+accept 审查门**（makevoid）：子代理 wave 式放量（2→3-4→4-8→6-10），JSONL 持久
  日志，`work:accept` 门——"不能因为模型请求成功就 accept"；plan hash+授权范围记录，授权后
  standing authorization 不逐场景问。
- **执行契约**（makevoid）：Ruby 是唯一执行入口层（`mv.rb` → 服务 → Fal/ffmpeg/ImageMagick），
  禁 agent 直接 curl/SDK——可复现、可审计、权限集中。
- **intent-dispatch skill**（videowright SKILL.md）：入口按意图路由到 references/*.md 按需
  加载；CR checklist 嵌入创作循环（每 segment 写完即过 9 项 render-safety 审查）而非事后审查；
  工具薄、skill 厚（ndemo：工具刻意不造 agent loop/重试/元素发现）。
- **实录派接口**（ndemo）：`intent`（自然语言，给 agent 看）与 `actions`（结构化，工具执行）
  分离的 playbook；agent 读 a11y tree 把 intent 翻译成 actions；每动作带机器可验证 `done` 条件。
- **AI 生成隔离律**（makevoid prompts.md:11）：*"H3 只演角色，世界属于 p5"*——绿幕 #00B140
  纯平、锁相机、无地板阴影；每 clip 一角色；背景=AI 生成 still plate 由 p5 持有移动；全帧
  AI 全片最多 1–2 次且须在 plan 里 justify——**把非确定性隔离在 sprite 内**。
- **narration-first**（makevoid lesson）：TTS master 听校后**冻结**才算帧区间；只延 tail 不
  移已有词；~150 spoken words/min 起步；捆绑资产包（角色 sheet/教室/loop/幕布）替代每次重生成。

## 6. 叙事 spine 模板

- **场景→音乐结构映射**（Claude-Opus-5.5 skill 04-storyboard.md）：cold open=识别瞬间 / build=
  悬念无产品 / drop1=reveal 名字+承诺 / verse=工作循环每乐句一特性 / breakdown=信任时刻 /
  drop2=规模 / final drop=三四个词 rapid-fire / tail=安静一句+卡片。**cut list as code
  comment**——整个剪辑以时间表写在组件上方注释里，"This list is the film"。
- **教学课 spine**（makevoid lesson SKILL.md:46）：≤15s cold-open 悬念/演示 → host/title →
  概念用例子与图解讲 → complication/峰值 → synthesis → callback joke；结尾仪式模板：callback
  joke → 音乐停 → 2.0s 静默反应 → tada+iris to black → 幕布 → end card+卡司巡游 → credits。
- **节奏三原则**（functional-emotions 从 PDoomVideo 继承）：短 shot（1.4–4s）、每 shot 一个
  动作、镜头永远在动。**被拒第一版的教训**：排版精致的 lyric video 被否，因为"还是 lyric
  video"——故事、场景、表演才是 MV；歌词时间只用来打点，不上屏。
- **"Say only what the product says"**（产品视频）：旁白必须是源码里存在的字符串（真实状态
  消息/按钮/空态），"Task complete" 和 "Done!" 是两个产品；界面数字从源码取不从截图猜。

## 7. 风格 prompt 词汇表（awesome-opus-5-5-video-prompts 语料归纳）

8 个描述维度（原文高频词）：
1. **媒介/材料**（一词定调）：glass and gold-leaf mosaic / sand animation / painted animation
   with visible brushstrokes / pixel art / voxel / line-art / paper-cutout collage with
   halftone print / engraving, oscilloscope, paperwork, blueprint, UI idioms / risograph；
2. **质感/后期**：light film grain / vignette / subtle light flicker（每 8–10s） / motion
   blur on fast moves / bloom-halation-CA / 反向禁用 no gradients, no anti-aliasing（保像素干净）；
3. **色彩**：a deep dark background with one warm accent color that evolves across eras /
   ~24-color palette / body-highlight-shadow 三段 hex / one accent colour per scene；
4. **镜头**：locked camera, no zoom（绿幕铁律）/ one continuous camera, no hard cuts /
   pushes-pulls-pans 1.5–3s ease-in-out / handheld life — breathing sway and micro-tremor /
   half the speed you'd default to（AI 导演高频校准语）；
5. **节奏/剪辑**：cut on the beat / hard cuts on downbeats / hit-stop / snap, then hold /
   alternate dense and calm moments / one event per sung line / on twos, 15 fps / easing:
   never linear；
6. **参考锚**（最高效压缩）：Kurzgesagt meets a Pixar opening / Wes Anderson's Grand Budapest /
   16-bit console era / 90s cartoon, Pixar-level polish；
7. **品质/排除**：cinematic and painterly rather than photorealistic / not a slideshow / no
   dead air, static frames, template look / no text of any kind；
8. **技术约束**：single self-contained HTML / no external assets / deterministic — no
   Math.random/Date.now / 1920×1080 60fps / zero allocations in the render loop。

**五段式 prompt 模板**（语料反复出现，可直接当分镜骨架）：
`① 硬约束前置`（时长/画幅/技术栈/禁项）→ `② 叙事 spine`（三幕，含 recurring motif）→
`③ 分段时间表`（秒级）→ `④ craft rules 分维度列出`（color/motion/typography/pacing 各 2–4 条）
→ `⑤ 自检要求`（"generate 3 stills and criticize them before finishing"）。
先用维度 1–6 填"风格 bible"（一段话逐字复用），再用维度 5 绑 beat grid，最后用维度 8 收口。

## 8. 语料索引（25 仓库，逐条许可见 [SOURCES.md](../SOURCES.md)）

- **MV 正片**：PDoomVideo（p5.brush 水彩）、pdoom-the-printed-world（纯排版）、
  power-video（换歌+信号蓝）、context-window（复刻+洋红 16 场景）、pdoom-video-win95（UI 拟物）、
  pdoom-video-fr / Zh-CN-pdoom-video / StuGRua-PDoomVideo（本地化）、jessecaple-pdoom-video
  （报纸 1-bit）、bohemian-tokenry-video（五风格纸剧场）、functional-emotions-video（GPU 笔刷）、
  why-wont-you-let-me-help（risograph）、opus-5.5-music-video-art-styles（18 媒介引擎）、
  pdoom-video（Alice7371 纯镜像）、GitRaymond-glitch-pop（空，只有 mp3）、shelter-mv（上游已删除，
  本地克隆损坏）。
- **基建**：videowright、ndemo、motion-graphics-music-video-skill、
  motion-graphics-animated-lesson-plugin、super-motion-graphics、
  Claude-Opus-5.5-Motion-Video-Skill、opus-video-audio-skill、ClaudeAnimationBase、
  awesome-opus-5-5-video-prompts（本地克隆为空，内容见 GitHub README）。
- 未克隆（用户叫停）：gglucass/headroom-animation、2606156052/Pdoom-video-anime-version。

技法归属：媒介风格→`media-styles.md`；特效/转场增补→`fx-tx-addendum.md`；管线/验证/编排/
prompt 词汇→本文件。
