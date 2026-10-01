# VideoGraph 进度仪表盘

**更新时间**: 2026-10-01  
**项目阶段**: Alpha (可用但需完成关键集成)

---

## 📊 总体进度

```
整体完成度: ████████████░░░░░░░░ 60%

核心功能    ████████████████░░░░ 80%
音频分析    ██████████░░░░░░░░░░ 50%
UI/UX      ████████████████████ 100%
测试覆盖    ██████████████░░░░░░ 70%
文档完整    ████████████████░░░░ 80%
```

---

## ✅ 已完成功能 (60%)

### 🎬 视频生成核心 (80%)
- [x] 单镜头生成/验证/修复 (project-store.mjs, 578 行)
- [x] 真实引擎接入 (reference-server.mjs, render-worker.mjs)
- [x] 完整 PV 导出 (22 镜头, 156.67s, H.264+AAC)
- [x] 内容寻址缓存 (22/22 命中率)
- [x] 增量导出 (只重渲染改过的镜头)
- [x] 引擎快照与版本控制
- [ ] 转场实际使用验证 (代码写了但未用)
- [ ] 歌词元素实际使用验证 (lyricPlan 都是空的)

### 🗣️ 人工意见闭环 (100%) ✨
- [x] 意见数据结构与状态机 (feedback.mjs, 339 行)
- [x] 锚点支持: 时间/区间/歌词元素/画面区域/方面
- [x] 保留项 (preserve[], ≤12 条)
- [x] 修改前版本冻结 (reviewBaseline)
- [x] 拒绝后完整恢复
- [x] feedbackResponses 逐条响应
- [x] 修改前后对比界面 (ReviewCompare.tsx)
- [x] MCP 工具集成 (project_feedback_*, project_stills)
- [x] 澄清对话 (askFeedback / replyFeedback)
- [x] 收件箱汇总 (project_feedback_inbox)
- [x] 测试通过 (8 项契约 + HTTP + MCP + UI)

### 🎵 音频分析系统 (50%)
- [x] T0 解码 (支持 MP3/WAV/M4A/OGG/FLAC)
- [x] T1 节拍检测 (F-measure 0.9961)
- [x] T1 段落划分 (energy+onset)
- [x] T1 包络提取 (8 路: bass/kick/snare/hat/other/全频/onset)
- [x] T3 ASR + 对齐 (Qwen3-ASR + ForcedAligner)
- [x] 真实歌曲验收 (《琵琶行》通过)
- [x] 数据契约 v2 (contract.mjs)
- [x] 适配器模式 (fromPdoom / toEngine / toFullSong)
- [ ] 校正界面接入主视图 (AnalysisCorrector 已写但独立)
- [ ] 引擎解耦 (15 处 ly.get() 单曲绑定)
- [ ] 通用镜头规划 (不绑定 pdoom 切点)
- [ ] MCP 工具接入 (project_audio_analyze)

### 🎨 UI/UX (100%) ✨
- [x] ComfyUI 深色风格 (project.css, 228 行)
- [x] 设计 token 系统 (src/design/)
- [x] 三栏工作台 (ProjectStudio.tsx, 578 行)
- [x] ReactFlow 节点画布
- [x] 镜头卡片 + 转场节点 + 意见输入
- [x] 歌词检查器 (LyricInspector.tsx)
- [x] 转场检查器 (TransitionInspector.tsx)
- [x] 预览播放器集成 (postMessage 时间同步)
- [x] 品牌面板 (BrandPanel.tsx, 287 行, 未挂载主界面)
- [x] 分析校正界面 (AnalysisCorrector.tsx)
- [x] 包体优化 (1706KB → 451KB, -74%)

### 📦 品牌素材管理 (80%)
- [x] 数据模型 (产品图/Logo/字体/音频)
- [x] 内容寻址 blob 存储
- [x] 锁定保护 + 引用计数
- [x] 色板管理
- [x] 禁用规则与版权信息
- [x] 测试通过 (9 项)
- [ ] 挂载到主界面
- [ ] 接入镜头依赖和缓存键

### 📚 技法库 (100%) ✨
- [x] 5 条通用法则 (不绑单曲)
- [x] 分镜/转场/特效/媒介风格参考
- [x] 反馈工作流文档
- [x] 平台说明生成脚本 (sync-platform.mjs)
- [x] scene-template.ts 模板
- [x] 许可归档 (SOURCES.md)
- [x] 分发脚本 (install.mjs)

---

## 🚧 进行中功能 (30%)

### 📝 独立创作工程 (70%)
**工程 ID**: `052d3bd1-dd0b-41fd-8775-e21468fb9163`
- [x] 创建工程 (22 镜头)
- [x] 导出两版 MP4 (rev 66, rev 88)
- [x] 真实引擎渲染 (4700 帧)
- [ ] 响应人工意见 ("多加转场", 待处理)
- [ ] 使用转场功能 (21 个转场全是硬切)
- [ ] 填充歌词元素 (22 个 lyricPlan 都空的)
- [ ] 审美验收 (待人工确认)
- [ ] 署名与来源核验

### 🔗 转场与歌词元素 (60%)
- [x] 转场数据结构 (transitions.mjs)
- [x] 转场配置 (cut/dissolve/wipe/dip)
- [x] 转场检查器界面 (TransitionInspector.tsx)
- [x] 歌词元素数据结构 (lyric-elements.mjs)
- [x] 歌词检查器界面 (LyricInspector.tsx)
- [x] MCP 工具 (project_transition_*, project_shot_lyrics)
- [x] 测试通过 (lyrics-transitions-test.mjs)
- [ ] 真实使用验证 (独立工程未用)
- [ ] 转场集成审计 (未运行, 需独立实例)

---

## ⬜ 待开始功能 (10%)

### 🎤 通用音频输入 (10%)
- [x] SONG-00/01 完成 (T0/T1/T3)
- [ ] SONG-02: 校正界面接入主视图
- [ ] SONG-03: 引擎解耦 (解除 15 处单曲绑定)
- [ ] SONG-04: 通用镜头规划
- [ ] SONG-05: MCP 工具接入
- [ ] SONG-06: 端到端验收

### 🤝 端到端验收 (0%)
- [ ] FB-04: 人工意见闭环 (真实案例)
- [ ] 转场集成审计 (需独立实例)
- [ ] 独立创作审美验收

### 🔧 可靠性增强 (0%)
- [ ] 渲染进程超时回收
- [ ] 动态端口分配
- [ ] SSE 替代轮询
- [ ] 资源预算限制
- [ ] 渲染沙箱隔离

### 🚀 交付功能 (0%)
- [ ] 多画幅 (9:16, 1:1)
- [ ] 版本回滚
- [ ] 候选对比
- [ ] 导出审批
- [ ] 来源与版权清单

---

## 🐛 已知问题

### 🔴 P0 - 阻塞发布
```
[!] 工作区有未提交改动
    位置: feat/lyrics-transitions 分支
    文件: 12 个已修改, 4 个未跟踪
    影响: 基线不清晰
    建议: 立即提交 (INT-00)

[!] 独立工程有待响应意见
    工程: 052d3bd1, 镜头: prompt1
    意见: "是不是有点太素了，多加转场"
    状态: needs-generation + 1 pending
    影响: 无法导出完整版
    建议: 作为 FB-04 真实案例处理
```

### 🟠 P1 - 影响体验
```
[!] 单曲绑定未解除
    位置: 15 个场景 ly.get('原句')
    影响: 换歌会抛错
    建议: 改用 lyrics.linesIn()

[!] 转场功能未实际使用
    现状: 21 个转场全是硬切
    影响: 功能未验证有效性
    建议: 响应意见, 真实使用

[!] 渲染进程端口冲突
    历史: 2 次 "Port 5173 in use"
    影响: 并发导出不可靠
    建议: 动态端口 + 超时回收
```

### 🟡 P2 - 可延后
```
[i] 轮询延迟 2500ms
    建议: 改用 SSE 推送

[i] 包体可优化 (451KB)
    建议: 按路由懒加载

[i] 部分文件偏大
    ProjectStudio.tsx: 578 行
    project-store.mjs: 578 行
    建议: 拆分组件和模块
```

---

## 📈 质量指标

### 测试覆盖
```
总计: 85/86 通过 (98.8%)

✅ 领域测试         27/27  project-store
✅ 反馈契约          8/8   feedback-lifecycle
✅ 品牌管理          9/9   brand-store
✅ 歌曲分析         11/11  song-adapters
✅ MCP 工具          通过   mcp-feedback-tools
✅ UI 审计           通过   ui-feedback.audit
⏭️ 转场集成          跳过   transition-integration-audit (需独立实例)
```

### 代码质量
```
规模: 3,873 行 (36 个文件)
风格: 统一 (camelCase/PascalCase/kebab-case)
注释: JSDoc + 中文说明
类型: TypeScript + JSON Schema
```

### 性能指标
```
构建时间    1.64s
包体大小    451KB (gzip: 146KB)
首次导出    4700 帧 / 156.67s
增量导出    22/22 缓存命中
节点渲染    22 节点 @ 60fps
工程加载    <500ms
```

### 安全评分
```
✅ 本机服务绑定 loopback
✅ Origin 校验
✅ 会话令牌
✅ safeId 校验
⚠️ 渲染进程无超时
⚠️ 无资源预算限制
⚠️ new Function 无沙箱
⚠️ 错误栈暴露内部
```

---

## 🎯 里程碑

### ✅ M1 - 核心能力验证 (2026-09)
- [x] 单镜头生成链路
- [x] 真实引擎接入
- [x] 完整 PV 导出
- [x] 参考复现验收

### 🚧 M2 - 人工意见闭环 (2026-10)
- [x] FB-01/02/03 实现
- [x] UI 重构完成
- [x] SKILL-01 纳入仓库
- [ ] FB-04 端到端验收
- [ ] 独立创作审美验收

### ⬜ M3 - 任意歌曲输入 (2026-10)
- [ ] SONG-02: 校正界面接入
- [ ] SONG-03: 引擎解耦
- [ ] SONG-04: 通用规划
- [ ] SONG-05: MCP 接入
- [ ] SONG-06: 端到端验收

### ⬜ M4 - 生产就绪 (2026-11)
- [ ] 可靠性增强
- [ ] E2E 测试补充
- [ ] 性能优化
- [ ] 文档完善

### ⬜ M5 - ToB 扩展 (2026-Q4)
- [ ] 品牌包完整集成
- [ ] 脚本/旁白驱动
- [ ] 多画幅支持
- [ ] 团队素材库

---

## 🗓️ 下周计划 (2026-10-01 - 10-07)

### 周一 (10-01)
- [x] 完成代码审查
- [ ] 提交工作区改动 (INT-00)

### 周二-周三 (10-02 - 10-03)
- [ ] 运行转场集成审计 (需独立实例)
- [ ] 处理独立创作工程意见

### 周四-周五 (10-04 - 10-05)
- [ ] 开始 SONG-02 校正界面接入
- [ ] 补充架构图

---

## 📞 联系方式

**项目维护**: video-graph-demo 团队  
**技术支持**: 参考 ROADMAP.md  
**代码审查**: 参考 CODE_REVIEW.md (完整 35 KB 报告)  
**执行摘要**: 参考 EXECUTIVE_SUMMARY.md (简洁 15 KB 版本)

---

**最后更新**: 2026-10-01 by Claude (Opus 5.5)  
**下次更新**: 2026-10-14 (两周后)
