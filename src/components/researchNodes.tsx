import { Handle, Position, type Node, type NodeProps } from '@xyflow/react';
import { BookOpenCheck, Camera, Globe2, Search, Sparkles } from 'lucide-react';
import type { LyricResearchKind } from '../lyrics/research';

export type LyricResearchNodeData = {
  kind: 'lyric-research';
  line: string;
  findings: Array<{ phrase: string; kind: LyricResearchKind; meaning: string; source: string }>;
  status: '待研究' | '研究中' | '待审批' | '已审批';
};

export type ShotDirectorNodeData = {
  kind: 'shot-director';
  shotId: string;
  lyricText: string;
  semanticSummary: string;
  visualIntent: string;
  status: '待生成' | '已规划' | '待审阅' | '已锁定';
  assets: string[];
};

export type CreativeResearchNode = Node<LyricResearchNodeData | ShotDirectorNodeData>;

export function LyricResearchNode({ data, selected }: NodeProps<Node<LyricResearchNodeData>>) {
  return (
    <div className={`studio-node research-node ${selected ? 'is-selected' : ''}`}>
      <Handle type="target" position={Position.Left} className="handle handle-mint" />
      <div className="node-header pdoom-header-yellow"><div className="node-icon icon-yellow"><BookOpenCheck size={15} /></div><div className="node-heading"><span className="node-eyebrow">歌词理解 / RESEARCH</span><strong>歌词语义研究</strong></div><span className="creative-status creative-status-planned">{data.status}</span></div>
      <div className="node-body creative-body">
        <div className="creative-summary">LLM 先解释歌词，再识别黑话、梗、文化引用和品牌风险；搜索结果必须有来源，未审批的解释不能直接驱动镜头。</div>
        <div className="creative-field"><span>歌词片段</span><div>{data.line}</div></div>
        <div className="research-findings">{data.findings.map((finding) => <div className="research-finding" key={finding.phrase}><Search size={11} /><span><b>{finding.phrase}</b> · {finding.meaning}<small>{finding.source}</small></span></div>)}</div>
        <button className="mini-button creative-run"><Globe2 size={12} /> 搜索并解释语境</button>
      </div>
      <div className="node-footer"><span><Sparkles size={12} /> 研究结果可审批</span><span className="footer-code">LYRIC_RESEARCH</span></div>
      <Handle type="source" position={Position.Right} className="handle handle-yellow" />
    </div>
  );
}

export function ShotDirectorNode({ data, selected }: NodeProps<Node<ShotDirectorNodeData>>) {
  return (
    <div className={`studio-node shot-director-node ${selected ? 'is-selected' : ''}`}>
      <Handle type="target" position={Position.Left} className="handle handle-yellow" />
      <div className="node-header pdoom-header-blue"><div className="node-icon icon-blue"><Camera size={15} /></div><div className="node-heading"><span className="node-eyebrow">逐镜头 / SHOT DIRECTOR</span><strong>{data.shotId} · 镜头导演</strong></div><span className="creative-status creative-status-ready">{data.status}</span></div>
      <div className="node-body creative-body">
        <div className="creative-field"><span>歌词语境</span><div>{data.lyricText}</div></div>
        <div className="creative-field"><span>LLM 视觉意图</span><div>{data.visualIntent}</div></div>
        <div className="creative-field"><span>素材依赖</span><div>{data.assets.join(' · ') || '暂无，等待素材规划'}</div></div>
        <button className="mini-button button-blue"><Sparkles size={12} /> 生成这个镜头</button>
      </div>
      <div className="node-footer"><span><Camera size={12} /> 每个镜头独立生成</span><span className="footer-code">SHOT_CONTEXT</span></div>
      <Handle type="source" position={Position.Right} className="handle handle-blue" />
    </div>
  );
}

export const researchNodeTypes = { 'lyric-research': LyricResearchNode, 'shot-director': ShotDirectorNode };

export const researchInitialNodes: CreativeResearchNode[] = [
  { id: 'lyric-research-1', type: 'lyric-research', position: { x: 220, y: 40 }, data: { kind: 'lyric-research', line: 'See through the shoggoth / the future goes FOOM', findings: [{ phrase: 'shoggoth', kind: 'meme', meaning: 'AI 社区关于模型不可解释性的隐喻', source: '待搜索：AI 文化语境' }, { phrase: 'FOOM', kind: 'slang', meaning: 'AI 能力快速爆发/递归自我改进的网络说法', source: '待搜索：AI safety 语境' }], status: '待研究' } },
  { id: 'shot-director-1', type: 'shot-director', position: { x: 700, y: 180 }, data: { kind: 'shot-director', shotId: 'SHOT 01', lyricText: 'See through the shoggoth / the future goes FOOM', semanticSummary: '未研究', visualIntent: '研究完成后由 LLM 提出：不要只做字幕，要把梗的文化语境变成镜头动作和材质。', status: '待生成', assets: ['Shoggoth reference', 'Logo/brand palette'] } },
];
