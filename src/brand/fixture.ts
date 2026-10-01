// fixture.ts — 内存版品牌适配器：给面板与集成者的演示/联调用例，不是持久实现。
// 真实存储在 src/server/brand/brand-store.mjs；fixture 的 hash 用演示摘要代替。
import type { BrandAsset, BrandAssetAdapter, BrandGuidelinesPatch, BrandImportInput, BrandLibrary } from './types';

const demoHash = (bytes: Uint8Array) => {
  let h = 0x811c9dc5;
  for (const byte of bytes) { h ^= byte; h = Math.imul(h, 0x01000193); }
  return (h >>> 0).toString(16).padStart(8, '0').repeat(8);
};
const seedAsset = (id: string, name: string, kind: BrandAsset['kind'], hash: string, copyright: string): BrandAsset => ({
  id, name, kind, hash, bytes: 1024, ref: `blobs/${hash}`, copyright, notes: undefined,
  locked: false, referencedBy: [], createdAt: Date.now(), updatedAt: Date.now(),
});

export function createFixtureBrandAdapter(): BrandAssetAdapter {
  let library: BrandLibrary = {
    schema: 1, revision: 0, updatedAt: Date.now(),
    guidelines: {
      palette: [
        { name: '墨黑', hex: '#0A0A0B', usage: '底色' },
        { name: '骨白', hex: '#EEE9DF', usage: '主文字' },
        { name: '信号橙', hex: '#FF4D12', usage: '唯一强调色' },
      ],
      allowedFonts: [{ family: 'Arial', weights: [400, 700], note: '系统栈兜底' }],
      requiredElements: ['左下角 Logo 水印'],
      forbidden: ['紫色霓虹赛博朋克', '发光大脑', 'Matrix 代码雨'],
      notes: '演示数据：与产品色板一致，仅用于面板联调。',
    },
    assets: [
      seedAsset('demo-logo-01', '产品 Logo 主标', 'logo', 'a'.repeat(64), '© G1en；仅限本产品演示'),
      seedAsset('demo-copy-01', '宣发口号 v2', 'copy', 'b'.repeat(64), '原创文案'),
    ],
  };
  const clone = () => JSON.parse(JSON.stringify(library)) as BrandLibrary;
  const fail = (message: string, status = 400): never => { const error = new Error(message) as Error & { status?: number }; error.status = status; throw error; };
  const findAsset = (id: string): BrandAsset => {
    const found = library.assets.find((entry) => entry.id === id);
    return found ?? fail('素材不存在', 404);
  };
  return {
    async list() { return clone(); },
    async importAsset(input: BrandImportInput, bytes: Uint8Array) {
      if (!input.name.trim()) fail('素材名称不能为空');
      if (!bytes.byteLength) fail('素材内容为空');
      const hash = demoHash(bytes);
      library.assets.push({
        id: `demo-${Math.random().toString(36).slice(2, 10)}`, name: input.name.trim(), kind: input.kind,
        hash, bytes: bytes.byteLength, ref: `blobs/${hash}`, copyright: input.copyright?.trim() || undefined,
        notes: input.notes?.trim() || undefined, locked: false, referencedBy: [], createdAt: Date.now(), updatedAt: Date.now(),
      });
      library.revision += 1;
      return clone();
    },
    async updateAsset(id, patch) {
      const asset = findAsset(id);
      const editing = Object.keys(patch).filter((key) => key !== 'locked');
      if (asset.locked && editing.length) fail('素材已锁定，请先解锁再编辑', 409);
      Object.assign(asset, patch, { updatedAt: Date.now() });
      library.revision += 1;
      return clone();
    },
    async removeAsset(id) {
      const asset = findAsset(id);
      if (asset.locked) fail('素材已锁定，请先解锁再删除', 409);
      if (asset.referencedBy.length) fail(`素材仍被引用（${asset.referencedBy.join(', ')}），请先解除引用再删除`, 409);
      library.assets = library.assets.filter((entry) => entry.id !== id);
      library.revision += 1;
      return clone();
    },
    async updateGuidelines(patch: BrandGuidelinesPatch) {
      library.guidelines = { ...library.guidelines, ...patch };
      library.revision += 1;
      return clone();
    },
    async bindReference(id, refKey) {
      const asset = findAsset(id);
      if (!asset.referencedBy.includes(refKey)) asset.referencedBy.push(refKey);
      library.revision += 1;
      return clone();
    },
    async unbindReference(id, refKey) {
      const asset = findAsset(id);
      const index = asset.referencedBy.indexOf(refKey);
      if (index < 0) fail('引用不存在', 404);
      asset.referencedBy.splice(index, 1);
      library.revision += 1;
      return clone();
    },
  };
}
