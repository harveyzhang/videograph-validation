// 品牌素材领域契约（与 src/server/brand/validation.mjs 保持一致；集成者接线时以此为准）。
// 元数据不携带绝对路径、API key 或文件字节；blob 由存储层内容寻址管理。

export type BrandAssetKind = 'logo' | 'product-image' | 'font' | 'audio' | 'palette' | 'copy';

export interface BrandAsset {
  id: string;
  name: string;
  kind: BrandAssetKind;
  /** 内容 SHA-256；相同字节共享同一 blob。 */
  hash: string;
  bytes: number;
  /** 受控资源引用（`blobs/<hash>`）；前端永远拿不到本机绝对路径。 */
  ref: string;
  copyright?: string;
  notes?: string;
  locked: boolean;
  /** 引用键列表（如 `shot:open:logo`）；非空时删除被拒绝。 */
  referencedBy: string[];
  createdAt: number;
  updatedAt: number;
}

export interface BrandPaletteEntry { name: string; hex: string; usage?: string }
export interface BrandFontEntry { family: string; weights?: number[]; note?: string }

export interface BrandGuidelines {
  palette: BrandPaletteEntry[];
  allowedFonts: BrandFontEntry[];
  requiredElements: string[];
  forbidden: string[];
  notes?: string;
}

export interface BrandLibrary {
  schema: 1;
  revision: number;
  updatedAt: number;
  guidelines: BrandGuidelines;
  assets: BrandAsset[];
}

export interface BrandImportInput { name: string; kind: BrandAssetKind; copyright?: string; notes?: string }
export interface BrandAssetPatch { name?: string; copyright?: string; notes?: string; locked?: boolean }
export interface BrandGuidelinesPatch {
  palette?: BrandPaletteEntry[];
  allowedFonts?: BrandFontEntry[];
  requiredElements?: string[];
  forbidden?: string[];
  notes?: string;
}

/** UI 通过注入的适配器操作素材库；真实实现由集成者接到本地工程服务。 */
export interface BrandAssetAdapter {
  list(): Promise<BrandLibrary>;
  importAsset(input: BrandImportInput, bytes: Uint8Array): Promise<BrandLibrary>;
  updateAsset(id: string, patch: BrandAssetPatch): Promise<BrandLibrary>;
  removeAsset(id: string): Promise<BrandLibrary>;
  updateGuidelines(patch: BrandGuidelinesPatch): Promise<BrandLibrary>;
  bindReference?(id: string, refKey: string): Promise<BrandLibrary>;
  unbindReference?(id: string, refKey: string): Promise<BrandLibrary>;
}

export const BRAND_KIND_LABELS: Record<BrandAssetKind, string> = {
  logo: 'Logo', 'product-image': '产品图', font: '字体', audio: '音频', palette: '色板', copy: '文案',
};
