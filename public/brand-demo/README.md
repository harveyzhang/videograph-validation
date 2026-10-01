# brand-demo — 演示数据（ASSET-01）

此目录只是 **测试/演示数据**，不是任何真实品牌的资产库，也不是存储实现：

- `demo-library.json`：`BrandLibrary` 结构示例，供面板联调与契约对照（blob 引用是占位符，不含真实文件）。
- `demo-logo.svg`：一个中性占位 Logo，可用来在面板里走一遍导入流程。

真实存储在 `src/server/brand/brand-store.mjs`（本机 `.cache/brand/`，`.gitignore` 已覆盖）；
前端契约在 `src/brand/types.ts`；领域测试在 `scripts/tests/brand/brand-store.test.mjs`。
