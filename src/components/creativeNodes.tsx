import { Handle, Position, type Node, type NodeProps } from '@xyflow/react';
import { BriefcaseBusiness, Camera, CheckCircle2, FileImage, Film, FolderOpen, Lightbulb, PackageOpen, Sparkles, WandSparkles } from 'lucide-react';

export type CreativeKind = 'creative-brief' | 'asset-brief' | 'asset-source' | 'shot-planner' | 'shot-review' | 'delivery-plan';
export type AssetSource = 'creator' | 'diffusion' | 'library' | 'missing';

export type CreativeData = {
  kind: CreativeKind;
  title: string;
  eyebrow: string;
  accent: 'mint' | 'blue' | 'orange' | 'violet' | 'yellow';
  status: 'draft' | 'planned' | 'needs-input' | 'ready';
  summary: string;
  fields: Array<{ label: string; value: string; placeholder?: string }>;
  source?: AssetSource;
  onRun?: () => void;
};

export type CreativeNode = Node<CreativeData>;

const iconMap: Record<CreativeKind, React.ReactNode> = {
  'creative-brief': <BriefcaseBusiness size={15} />,
  'asset-brief': <FileImage size={15} />,
  'asset-source': <FolderOpen size={15} />,
  'shot-planner': <Camera size={15} />,
  'shot-review': <WandSparkles size={15} />,
  'delivery-plan': <Film size={15} />,
};

const sourceLabel: Record<AssetSource, string> = {
  creator: '创作者提供', diffusion: '扩散模型生成', library: '素材库', missing: '待补充',
};

function CreativeNodeView({ data, selected }: NodeProps<Node<CreativeData>>) {
  return (
    <div className={`studio-node creative-node creative-${data.kind} ${selected ? 'is-selected' : ''}`}>
      <Handle type="target" position={Position.Left} className="handle handle-mint" />
      <div className={`node-header creative-header-${data.accent}`}>
        <div className={`node-icon icon-${data.accent}`}>{iconMap[data.kind]}</div>
        <div className="node-heading"><span className="node-eyebrow">{data.eyebrow}</span><strong>{data.title}</strong></div>
        <span className={`creative-status creative-status-${data.status}`}>{data.status === 'ready' ? '可执行' : data.status === 'needs-input' ? '需素材' : data.status === 'planned' ? '已规划' : '草稿'}</span>
      </div>
      <div className="node-body creative-body">
        <div className="creative-summary">{data.summary}</div>
        {data.fields.map((field) => <div className="creative-field" key={field.label}><span>{field.label}</span><div>{field.value || field.placeholder || '未填写'}</div></div>)}
        {data.source && <div className={`asset-source source-${data.source}`}><PackageOpen size={12} /> 素材来源：{sourceLabel[data.source]}</div>}
        {data.onRun && <button className="mini-button creative-run" onClick={data.onRun}><Sparkles size={12} /> 让 LLM 规划这一层</button>}
      </div>
      <div className="node-footer"><span><CheckCircle2 size={12} /> 可审阅 / 可微调</span><span className="footer-code">{data.kind.toUpperCase()}</span></div>
      <Handle type="source" position={Position.Right} className="handle handle-blue" />
    </div>
  );
}

export const creativeNodeTypes = {
  'creative-brief': CreativeNodeView,
  'asset-brief': CreativeNodeView,
  'asset-source': CreativeNodeView,
  'shot-planner': CreativeNodeView,
  'shot-review': CreativeNodeView,
  'delivery-plan': CreativeNodeView,
};

export const creativeInitialNodes: CreativeNode[] = [
  { id: 'creative-brief', type: 'creative-brief', position: { x: 50, y: 180 }, data: { kind: 'creative-brief', title: '创意导演', eyebrow: '入口 / CREATIVE DIRECTOR', accent: 'mint', status: 'draft', summary: '从歌曲、品牌目标和受众出发，提出视频概念、叙事结构和视觉策略。', fields: [{ label: '项目目标', value: '为音乐人制作一支完整 MV' }, { label: '核心输入', value: '一首歌 + 品牌/艺人背景 + 受众' }], } },
  { id: 'asset-brief', type: 'asset-brief', position: { x: 430, y: 80 }, data: { kind: 'asset-brief', title: '素材需求单', eyebrow: '规划 / ASSET BRIEF', accent: 'yellow', status: 'needs-input', summary: 'LLM 把创意拆成创作者必须提供或可生成的素材清单。', fields: [{ label: '需要的素材', value: '艺人肖像、Logo、字体、城市夜景' }, { label: '缺口', value: '2 个参考人物姿态、1 个品牌 Logo' }], onRun: () => undefined } },
  { id: 'asset-source', type: 'asset-source', position: { x: 430, y: 410 }, data: { kind: 'asset-source', title: '素材来源决策', eyebrow: '输入 / ASSET SOURCE', accent: 'orange', status: 'needs-input', summary: '逐项选择创作者上传、扩散模型生成或素材库检索。', fields: [{ label: '肖像', value: '等待上传' }, { label: 'Logo', value: '等待上传' }], source: 'missing' } },
  { id: 'shot-planner', type: 'shot-planner', position: { x: 820, y: 170 }, data: { kind: 'shot-planner', title: '镜头导演', eyebrow: '编排 / SHOT PLANNER', accent: 'blue', status: 'planned', summary: '根据音乐段落、素材可用性和风格圣经，生成主镜头与过渡镜头工作流。', fields: [{ label: '镜头数', value: '18 个主镜头 + 17 个过渡' }, { label: '技术栈', value: 'Three/WebGL + Canvas + GLSL' }], onRun: () => undefined } },
  { id: 'shot-review', type: 'shot-review', position: { x: 1210, y: 80 }, data: { kind: 'shot-review', title: '镜头审阅与微调', eyebrow: 'GUI / SHOT REVIEW', accent: 'violet', status: 'ready', summary: '创作者看到每个镜头、提示词、素材和预览，可逐镜头提出修改方向。', fields: [{ label: '当前选中', value: 'Shot 01 · Opening Signal' }, { label: '微调', value: '更像品牌纪录片，减少抽象噪声' }] } },
  { id: 'delivery-plan', type: 'delivery-plan', position: { x: 1210, y: 420 }, data: { kind: 'delivery-plan', title: '交付合成', eyebrow: '输出 / DELIVERY', accent: 'orange', status: 'planned', summary: '按时间线串联镜头与过渡，生成 1080p/4K MP4、预览和交付清单。', fields: [{ label: '输出', value: '1920×1080 · 60fps · H.264/AAC' }, { label: '交付版本', value: '预览版 / 母版 / 竖版裁切' }] } },
];

export const creativeInitialEdges = [
  { id: 'brief-assets', source: 'creative-brief', target: 'asset-brief', animated: true, className: 'edge-mint' },
  { id: 'assets-source', source: 'asset-brief', target: 'asset-source', animated: true, className: 'edge-yellow' },
  { id: 'assets-shots', source: 'asset-source', target: 'shot-planner', animated: true, className: 'edge-orange' },
  { id: 'brief-shots', source: 'creative-brief', target: 'shot-planner', animated: true, className: 'edge-blue' },
  { id: 'shots-review', source: 'shot-planner', target: 'shot-review', animated: true, className: 'edge-violet' },
  { id: 'review-delivery', source: 'shot-review', target: 'delivery-plan', animated: true, className: 'edge-blue' },
];
