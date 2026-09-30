import { useState } from 'react';
import { Check, Cpu, KeyRound, LoaderCircle, Plug, Plus, Trash2, X } from 'lucide-react';
import { defaultBaseUrl, kindLabels, type ProviderConfig, type ProviderKind } from '../llm/types';
import { newProvider, type useProviders } from '../llm/storage';

type Providers = ReturnType<typeof useProviders>;

export function SettingsModal({ providers, onClose }: { providers: Providers; onClose: () => void }) {
  const [draft, setDraft] = useState<ProviderConfig | null>(providers.providers[0] ?? null);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{ ok: boolean; text: string } | null>(null);

  const startNew = (kind: ProviderKind) => {
    setDraft(newProvider(kind));
    setTestResult(null);
  };

  const patch = (patch_: Partial<ProviderConfig>) => {
    setDraft((prev) => (prev ? { ...prev, ...patch_ } : prev));
    setTestResult(null);
  };

  const save = () => {
    if (!draft) return;
    providers.upsert(draft);
    setTestResult({ ok: true, text: '已保存到本地。' });
  };

  const test = async () => {
    if (!draft) return;
    setTesting(true);
    setTestResult(null);
    try {
      const reply = await providers.testConnection(draft);
      setTestResult({ ok: true, text: `连接成功 — 模型回复：${reply}` });
    } catch (error) {
      setTestResult({ ok: false, text: String(error).slice(0, 220) });
    } finally {
      setTesting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(event) => event.stopPropagation()}>
        <div className="modal-head">
          <span className="node-icon icon-blue"><Plug size={15} /></span>
          <div className="modal-heading">
            <span className="tiny-kicker">LLM PROVIDERS</span>
            <strong>模型接入设置</strong>
          </div>
          <button className="icon-button" onClick={onClose} aria-label="Close"><X size={15} /></button>
        </div>

        <div className="modal-body">
          <div className="provider-list">
            {providers.providers.length === 0 && <div className="provider-empty">尚未配置任何模型，先在右侧新增一个。</div>}
            {providers.providers.map((provider) => (
              <div key={provider.id} className={`provider-card ${providers.activeId === provider.id ? 'is-active' : ''}`}>
                <button className="provider-select" onClick={() => { providers.setActive(providers.activeId === provider.id ? null : provider.id); }}>
                  <span className={`radio ${providers.activeId === provider.id ? 'on' : ''}`} />
                  <span className="provider-meta">
                    <strong>{provider.name}</strong>
                    <span>{provider.model} · {kindLabels[provider.kind]}</span>
                  </span>
                </button>
                <button className="icon-button" onClick={() => setDraft(provider)} aria-label="Edit"><KeyRound size={14} /></button>
                <button className="icon-button" onClick={() => providers.remove(provider.id)} aria-label="Delete"><Trash2 size={14} /></button>
              </div>
            ))}
            <div className="provider-add">
              <button onClick={() => startNew('openai')}><Plus size={13} /> OpenAI 格式</button>
              <button onClick={() => startNew('anthropic')}><Plus size={13} /> Anthropic 格式</button>
            </div>
          </div>

          {draft && (
            <div className="provider-form">
              <div className="form-row">
                <label className="control-label">名称</label>
                <input value={draft.name} onChange={(event) => patch({ name: event.target.value })} />
              </div>
              <div className="form-row">
                <label className="control-label">接口格式</label>
                <div className="select-wrap">
                  <select value={draft.kind} onChange={(event) => patch({ kind: event.target.value as ProviderKind, baseUrl: defaultBaseUrl[event.target.value as ProviderKind] })}>
                    <option value="openai">{kindLabels.openai}</option>
                    <option value="anthropic">{kindLabels.anthropic}</option>
                  </select>
                  <Chevron />
                </div>
              </div>
              <div className="form-row">
                <label className="control-label">Base URL</label>
                <input value={draft.baseUrl} onChange={(event) => patch({ baseUrl: event.target.value })} placeholder={defaultBaseUrl[draft.kind]} />
              </div>
              <div className="form-row">
                <label className="control-label">模型</label>
                <input value={draft.model} onChange={(event) => patch({ model: event.target.value })} />
              </div>
              <div className="form-row">
                <label className="control-label">API Key</label>
                <input type="password" value={draft.apiKey} onChange={(event) => patch({ apiKey: event.target.value })} placeholder="sk-…" />
              </div>
              <div className="form-actions">
                <button className="toolbar-button" onClick={test} disabled={testing}>
                  {testing ? <LoaderCircle className="spin" size={14} /> : <Cpu size={14} />} 测试连接
                </button>
                <button className="run-button" onClick={save}>保存</button>
              </div>
              {testResult && <div className={`form-status ${testResult.ok ? 'ok' : 'bad'}`}>{testResult.ok ? <Check size={13} /> : <X size={13} />} {testResult.text}</div>}
              <div className="form-note">Key 仅保存在本机浏览器 localStorage。浏览器直连要求服务商开放 CORS；Anthropic 直连已自动附带 dangerous-direct-browser-access 头。</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function Chevron() {
  return <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="m6 9 6 6 6-6" /></svg>;
}
