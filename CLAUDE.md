# VideoGraph 协作约定

- 全程中文；产品服务 ToB 宣发和音乐人 PV，节点画布是核心操作界面。
- 开始工作先读 `ROADMAP.md`，尤其“并行协作与冲突控制”。所有计划、认领、进度和待办只维护在那里，不另开平行计划。
- 未认领的工作包不能假设已有人负责；跨 owner 范围的改动交给集成者。共享接线文件与依赖锁由单一集成者修改。
- 不修改 `../pdoom-video`、`../world-execute-pv`、`../flowvid` 或 `../ComfyUI`。参考引擎以只读输入或本项目内的独立工程副本使用。
- 不提交 `.cache/`、`.queue/`、`projects/`、服务令牌、API key、用户音频、视频产物或 `node_modules/`。忽略规则不是工程备份。
- 并行开发使用独立工作副本、功能分支和运行目录；不得共写同一工程数据库或服务令牌。
- 结果必须区分“已写代码”“已运行验证”“人工已接受”。测试失败或未运行要明确记录；不以模板/复现冒充独立原创。
- MCP 操作说明在 `docs/MCP-GUIDE.md`。改动任何 MCP 工具的名称、参数或语义，必须在同一提交中更新该指南（含 toolset 行）；shotcraft skill 改动后 bump version。详见 ROADMAP“文档同步规则”。
- 当前安全的轻量检查是 `node --test scripts/project-store-test.mjs scripts/lyrics-transitions-test.mjs` 和 `npm run build`。浏览器/GPU/全量回归的环境要求见 README 与 ROADMAP。
