# 第三方来源与许可边界

> 工程侧记录，不替代针对具体分发方式的法律审查。

## ComfyUI：交互参考，未复制源码

- 本地参考路径：`../ComfyUI`。
- `LICENSE` 为 GNU GPL version 3 文本，`pyproject.toml` 指向该文件。此记录不擅自推断所有文件的 SPDX `only/or-later` 选择。
- 本产品参考其多行提示词、类型化输入、参数范围/步长、高级参数、种子冻结和指导组合的交互思路；当前相关 React/TypeScript 界面独立实现，未将 ComfyUI 源码搬入本产品。
- 若后续直接复制/修改并分发受 GPL 覆盖的代码，需审查署名、许可文本、修改说明、对应源码及组合/派生作品的相关义务。收费商业使用本身不等于被禁止；也不能把 GPL v3 当作 AGPL。
- ComfyUI 前端是独立的 `Comfy-Org/ComfyUI_frontend` 项目。本地后端 README 指明其通过 `comfyui-frontend-package` 安装，本地未有完整 `web` 源码。本次没有核实该独立前端及其依赖/资源的许可证，**禁止默认套用后端许可结论来复制前端代码或资源**。
- 参考代码位置：`nodes.py` 的 `CLIPTextEncode`、conditioning 组合/区域/范围节点与 sampler 输入；`comfy/comfy_types/node_typing.py` 的 widget/socket、默认值、步长、范围与种子控制定义。扩散 timestep 不是视频时间轴，conditioning 权重不是 LLM 的保证倍率。

## pdoom-video：真实引擎与参考工程

- 本地参考路径：`../pdoom-video`；代码采用 MIT 许可。
- 工程导入保存独立副本并保留 `LICENSE` 和 `CREDITS.md`；不修改参考仓库。
- 原始场景导入与独立编写的场景分别标记来源。共享引擎、字体、已对齐歌词数据与新写的镜头视觉代码不混为一谈。
- 歌曲与歌词不包含在代码的 MIT 许可里，保留各自作者权利。字体保留原有许可，包括 OFL/相关公共领域资料。商业宣发不得仅凭代码开源就假定音乐、歌词或字体资产已获得所有所需授权。

## npm 依赖

具体版本由 `package-lock.json` 固定，各包继续适用自身许可证。直接依赖/更新由集成者统一操作；提交代码不提交 `node_modules`。发布前应基于最终依赖清单检查许可证与必要通知。
