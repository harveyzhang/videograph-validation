// BrandPanel — 品牌与产品素材面板（ASSET-01）。通过注入的 adapter 操作，不自连服务；
// 集成者在热点文件里挂载并提供真实 adapter（fixture 见 ./fixture）。
import { useCallback, useEffect, useState } from 'react';
import { Lock, LockOpen, Plus, RefreshCw, Trash2, Upload, X } from 'lucide-react';
import { BRAND_KIND_LABELS, type BrandAssetAdapter, BrandAssetKind, BrandLibrary } from './types';

const panelStyle: React.CSSProperties = {
  display: 'flex', flexDirection: 'column', gap: 12, color: '#EEE9DF',
  background: '#1b1b1b', border: '1px solid #353535', borderRadius: 8, padding: 14, minHeight: 0,
};
const rowStyle: React.CSSProperties = { display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' };
const inputStyle: React.CSSProperties = {
  background: '#1e1e1e', color: '#EEE9DF', border: '1px solid #353535', borderRadius: 4, padding: '4px 8px', fontSize: 13,
};
const buttonStyle: React.CSSProperties = { ...inputStyle, cursor: 'pointer' };
const cardStyle: React.CSSProperties = { border: '1px solid #353535', borderRadius: 6, padding: 10, background: '#242424' };
const labelStyle: React.CSSProperties = { fontSize: 12, color: '#9C978F', display: 'block', marginBottom: 2 };

function sizeLabel(bytes: number) {
  return bytes >= 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

export function BrandPanel({ adapter }: { adapter: BrandAssetAdapter }) {
  const [library, setLibrary] = useState<BrandLibrary | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [importName, setImportName] = useState('');
  const [importKind, setImportKind] = useState<BrandAssetKind>('logo');
  const [importCopyright, setImportCopyright] = useState('');
  const [importBytes, setImportBytes] = useState<Uint8Array | null>(null);
  const [paletteDraft, setPaletteDraft] = useState({ name: '', hex: '', usage: '' });
  const [listDraft, setListDraft] = useState({ requiredElements: '', forbidden: '' });

  const act = useCallback(async (action: () => Promise<BrandLibrary>) => {
    setBusy(true); setError('');
    try { setLibrary(await action()); } catch (cause) { setError(String((cause as Error).message ?? cause)); } finally { setBusy(false); }
  }, []);
  useEffect(() => { void act(() => adapter.list()); }, [adapter, act]);

  const run = (action: () => Promise<BrandLibrary>) => { if (!busy) void act(action); };
  const refresh = () => run(() => adapter.list());

  return <section style={panelStyle} aria-label="品牌与产品素材">
    <div style={rowStyle}>
      <strong>品牌与产品素材</strong>
      <span style={{ color: '#9C978F', fontSize: 12 }}>rev {library?.revision ?? '…'} · {library?.assets.length ?? 0} 项素材</span>
      <button style={buttonStyle} onClick={refresh} disabled={busy} aria-label="刷新素材库"><RefreshCw size={13} /></button>
    </div>
    {error && <div role="alert" style={{ border: '1px solid #C21D0B', borderRadius: 4, padding: '6px 8px', color: '#FF8A3D', fontSize: 13 }}>
      {error}<button style={{ ...buttonStyle, border: 'none', background: 'transparent', color: '#9C978F' }} aria-label="关闭错误" onClick={() => setError('')}><X size={12} /></button>
    </div>}

    <div style={cardStyle}>
      <strong style={{ fontSize: 13 }}>导入素材</strong>
      <div style={{ ...rowStyle, marginTop: 8 }}>
        <label><span style={labelStyle}>名称</span>
          <input style={inputStyle} value={importName} onChange={(event) => setImportName(event.target.value)} placeholder="如：产品 Logo 主标" /></label>
        <label><span style={labelStyle}>类型</span>
          <select style={inputStyle} value={importKind} onChange={(event) => setImportKind(event.target.value as BrandAssetKind)}>
            {Object.entries(BRAND_KIND_LABELS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select></label>
        <label><span style={labelStyle}>版权 / 来源</span>
          <input style={{ ...inputStyle, width: 220 }} value={importCopyright} onChange={(event) => setImportCopyright(event.target.value)} placeholder="© 作者；许可说明" /></label>
        <label><span style={labelStyle}>文件</span>
          <input style={{ ...inputStyle, width: 200 }} type="file" onChange={(event) => {
            const file = event.target.files?.[0];
            if (!file) return;
            if (!importName && file.name) setImportName(file.name.replace(/\.[^.]+$/, ''));
            void file.arrayBuffer().then((buffer) => setImportBytes(new Uint8Array(buffer)));
            event.target.value = '';
          }} /></label>
        <button className="action-button" style={{ ...buttonStyle, borderColor: '#FF4D12', color: '#FF4D12' }}
          disabled={busy || !importBytes || !importName.trim()}
          onClick={() => run(async () => {
            const next = await adapter.importAsset({ name: importName, kind: importKind, copyright: importCopyright || undefined }, importBytes!);
            setImportName(''); setImportCopyright(''); setImportBytes(null);
            return next;
          })}><Upload size={13} />导入</button>
      </div>
    </div>

    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, overflow: 'auto', minHeight: 120 }}>
      {(library?.assets ?? []).map((asset) => <article key={asset.id} style={cardStyle}>
        <div style={rowStyle}>
          <strong>{asset.name}</strong>
          <span style={{ fontSize: 12, color: '#9C978F' }}>{BRAND_KIND_LABELS[asset.kind]} · {sizeLabel(asset.bytes)} · {asset.hash.slice(0, 12)}…</span>
          {asset.referencedBy.length > 0 && <span style={{ fontSize: 12, color: '#FF8A3D' }}>被引用 ×{asset.referencedBy.length}</span>}
          <span style={{ flex: 1 }} />
          <button style={buttonStyle} title={asset.locked ? '解锁' : '锁定（禁止编辑与删除）'}
            onClick={() => run(() => adapter.updateAsset(asset.id, { locked: !asset.locked }))}>
            {asset.locked ? <Lock size={13} /> : <LockOpen size={13} />}{asset.locked ? '解锁' : '锁定'}
          </button>
          <button style={buttonStyle} title={asset.locked || asset.referencedBy.length ? '锁定或被引用的素材不能删除' : '删除'}
            disabled={busy}
            onClick={() => { if (window.confirm(`删除素材「${asset.name}」？`)) run(() => adapter.removeAsset(asset.id)); }}>
            <Trash2 size={13} />删除
          </button>
        </div>
        {asset.copyright && <p style={{ margin: '4px 0 0', fontSize: 12, color: '#9C978F' }}>版权：{asset.copyright}</p>}
        {asset.referencedBy.length > 0 && <p style={{ margin: '4px 0 0', fontSize: 12, color: '#9C978F' }}>引用：{asset.referencedBy.join('、')}</p>}
      </article>)}
    </div>

    <div style={cardStyle}>
      <strong style={{ fontSize: 13 }}>品牌规范</strong>
      <div style={{ ...rowStyle, marginTop: 8 }}>
        <label><span style={labelStyle}>色名</span><input style={inputStyle} value={paletteDraft.name} onChange={(event) => setPaletteDraft({ ...paletteDraft, name: event.target.value })} /></label>
        <label><span style={labelStyle}>#RRGGBB</span><input style={{ ...inputStyle, width: 90 }} value={paletteDraft.hex} onChange={(event) => setPaletteDraft({ ...paletteDraft, hex: event.target.value })} placeholder="#FF4D12" /></label>
        <label><span style={labelStyle}>用途</span><input style={{ ...inputStyle, width: 140 }} value={paletteDraft.usage} onChange={(event) => setPaletteDraft({ ...paletteDraft, usage: event.target.value })} /></label>
        <button style={buttonStyle} disabled={busy}
          onClick={() => run(async () => {
            if (!library) return adapter.list();
            const palette = [...library.guidelines.palette];
            if (paletteDraft.name.trim() && paletteDraft.hex.trim()) palette.push({ name: paletteDraft.name.trim(), hex: paletteDraft.hex.trim(), usage: paletteDraft.usage.trim() || undefined });
            setPaletteDraft({ name: '', hex: '', usage: '' });
            return adapter.updateGuidelines({ palette });
          })}><Plus size={13} />加色</button>
      </div>
      <div style={{ ...rowStyle, marginTop: 8 }}>
        {(library?.guidelines.palette ?? []).map((entry) => <span key={`${entry.name}${entry.hex}`} style={{ ...inputStyle, display: 'inline-flex', alignItems: 'center', gap: 6 }} title={entry.usage}>
          <span style={{ width: 12, height: 12, borderRadius: 2, background: entry.hex, border: '1px solid #5E5B57', display: 'inline-block' }} />{entry.name} {entry.hex}
        </span>)}
      </div>
      <div style={{ ...rowStyle, marginTop: 10, alignItems: 'flex-start' }}>
        <label><span style={labelStyle}>必保留元素（每行一条）</span>
          <textarea style={{ ...inputStyle, width: 260 }} rows={3} value={listDraft.requiredElements}
            onChange={(event) => setListDraft({ ...listDraft, requiredElements: event.target.value })}
            placeholder={(library?.guidelines.requiredElements ?? []).join('\n')} /></label>
        <label><span style={labelStyle}>禁用规则（每行一条）</span>
          <textarea style={{ ...inputStyle, width: 260 }} rows={3} value={listDraft.forbidden}
            onChange={(event) => setListDraft({ ...listDraft, forbidden: event.target.value })}
            placeholder={(library?.guidelines.forbidden ?? []).join('\n')} /></label>
        <button style={buttonStyle} disabled={busy}
          onClick={() => run(() => adapter.updateGuidelines({
            requiredElements: listDraft.requiredElements.split('\n').map((line) => line.trim()).filter(Boolean),
            forbidden: listDraft.forbidden.split('\n').map((line) => line.trim()).filter(Boolean),
          }))}>保存规范</button>
      </div>
      <p style={{ margin: '8px 0 0', fontSize: 12, color: '#9C978F' }}>
        允许字体：{(library?.guidelines.allowedFonts ?? []).map((font) => `${font.family}${font.weights?.length ? `(${font.weights.join('/')})` : ''}`).join('、') || '（未设置）'}
      </p>
    </div>
  </section>;
}
