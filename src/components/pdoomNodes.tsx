import { Handle, Position, type Node, type NodeProps } from '@xyflow/react';
import {
  Activity,
  AudioWaveform,
  Braces,
  Boxes,
  BrainCircuit,
  CheckCircle2,
  Clock3,
  Database,
  FileCode2,
  Film,
  Gauge,
  GitBranch,
  Layers3,
  LockKeyhole,
  Mic2,
  Network,
  Palette,
  Play,
  Sparkles,
  TimerReset,
  WandSparkles,
  Zap,
} from 'lucide-react';
import type { ArtifactType, BlackboardStats, CacheState } from '../blackboard/store';
import { artifactLabels } from '../blackboard/store';

export type PdoomNodeKind =
  | 'audio-source'
  | 'stem-analysis'
  | 'lyrics-align'
  | 'beat-analysis'
  | 'style-bible'
  | 'shader-pass'
  | 'plate-scene'
  | 'timeline-director'
  | 'sample-plan'
  | 'composite'
  | 'blackboard';

export type PdoomNodeData = {
  kind: PdoomNodeKind;
  artifactType: ArtifactType;
  title: string;
  eyebrow: string;
  accent: 'mint' | 'blue' | 'orange' | 'violet' | 'yellow';
  cache: CacheState;
  summary: string;
  stats?: BlackboardStats;
  detail?: string[];
  policy?: string;
  onRun?: () => void;
};

export type PdoomNode = Node<PdoomNodeData>;

const cacheLabel: Record<CacheState, string> = {
  cold: '冷启动',
  hit: '缓存命中',
  miss: '待计算',
  stale: '已过期',
  locked: '已锁定',
};

const Icon = ({ kind }: { kind: PdoomNodeKind }) => {
  const icons: Record<PdoomNodeKind, React.ReactNode> = {
    'audio-source': <AudioWaveform size={15} />,
    'stem-analysis': <Layers3 size={15} />,
    'lyrics-align': <Mic2 size={15} />,
    'beat-analysis': <Activity size={15} />,
    'style-bible': <Palette size={15} />,
    'shader-pass': <Braces size={15} />,
    'plate-scene': <Boxes size={15} />,
    'timeline-director': <Clock3 size={15} />,
    'sample-plan': <Gauge size={15} />,
    composite: <Film size={15} />,
    blackboard: <Database size={15} />,
  };
  return icons[kind];
};

function PdoomHeader({ data }: { data: PdoomNodeData }) {
  return (
    <div className={`node-header pdoom-header-${data.accent}`}>
      <div className={`node-icon icon-${data.accent}`}><Icon kind={data.kind} /></div>
      <div className="node-heading"><span className="node-eyebrow">{data.eyebrow}</span><strong>{data.title}</strong></div>
      <span className={`cache-chip cache-${data.cache}`}><span className="cache-dot" />{cacheLabel[data.cache]}</span>
    </div>
  );
}

function PdoomCard({ data, selected }: { data: PdoomNodeData; selected?: boolean }) {
  return (
    <div className={`studio-node pdoom-node pdoom-${data.kind} ${selected ? 'is-selected' : ''}`}>
      <PdoomHeader data={data} />
      <div className="node-body pdoom-body">
        <div className="pdoom-summary">{data.summary}</div>
        {data.detail && <div className="pdoom-details">{data.detail.map((item) => <div key={item}><span className="pdoom-check">·</span>{item}</div>)}</div>}
        {data.kind === 'blackboard' && data.stats && <BlackboardStatsView stats={data.stats} />}
        {data.policy && <div className="cache-policy-line"><LockKeyhole size={11} /> {data.policy}</div>}
        {data.onRun && <button className="mini-button pdoom-run" onClick={data.onRun}><Play size={12} /> 运行此节点</button>}
      </div>
      <div className="node-footer"><span><GitBranch size={12} /> {artifactLabels[data.artifactType]} · {data.cache}</span><span className="footer-code">{data.artifactType.toUpperCase()}</span></div>
    </div>
  );
}

function BlackboardStatsView({ stats }: { stats: BlackboardStats }) {
  return (
    <div className="blackboard-stats">
      <div><strong>{stats.artifacts}</strong><span>产物</span></div>
      <div><strong>{stats.cacheHits}</strong><span>命中</span></div>
      <div><strong>{stats.tokensSaved}</strong><span>节省 token</span></div>
      <div><strong>{stats.locked}</strong><span>锁定</span></div>
    </div>
  );
}

export function PdoomNode({ data, selected }: NodeProps<Node<PdoomNodeData>>) {
  return <PdoomCard data={data} selected={selected} />;
}

export const pdoomNodeTypes = {
  'audio-source': PdoomNode,
  'stem-analysis': PdoomNode,
  'lyrics-align': PdoomNode,
  'beat-analysis': PdoomNode,
  'style-bible': PdoomNode,
  'shader-pass': PdoomNode,
  'plate-scene': PdoomNode,
  'timeline-director': PdoomNode,
  'sample-plan': PdoomNode,
  composite: PdoomNode,
  blackboard: PdoomNode,
};

export const pdoomNodeDefaults: Record<PdoomNodeKind, Omit<PdoomNodeData, 'kind' | 'stats' | 'onRun'>> = {
  'audio-source': { artifactType: 'audio-source', title: '音频源', eyebrow: '输入 / 音频', accent: 'mint', cache: 'locked', summary: '统一音频时基。所有分析和镜头时间都从这个不可变源派生。', detail: ['pdoom.mp3 / gapless timeline', '源文件 hash 锁定', '下游只读引用'] },
  'stem-analysis': { artifactType: 'stems', title: 'Stem 分离', eyebrow: '分析 / Demucs', accent: 'violet', cache: 'miss', summary: '将音频拆成 vocals / drums / bass / other，作为后续特征的唯一输入。', detail: ['htdemucs_ft', 'audio-separator lead vocal', '权重缓存可复用'] },
  'lyrics-align': { artifactType: 'lyrics-aligned', title: '逐词歌词对齐', eyebrow: '分析 / CTC + Whisper', accent: 'yellow', cache: 'miss', summary: 'CTC Viterbi 全曲约束路径，Whisper 交叉核验，再做 onset/refinement。', detail: ['词级 / 音节级 timestamps', 'confidence + manual anchors', '输出 lyrics.json'] },
  'beat-analysis': { artifactType: 'audio-analysis', title: '节拍与音频分析', eyebrow: '分析 / librosa', accent: 'orange', cache: 'miss', summary: '拟合 BPM、beat、downbeat、onset、RMS、频段包络和段落。', detail: ['100 fps normalized envelopes', 'kick / snare / hat / vocal onsets', '输出 audio.json'] },
  'style-bible': { artifactType: 'style-bible', title: '风格圣经', eyebrow: '控制 / 视觉规范', accent: 'yellow', cache: 'locked', summary: '把色板、字体、颗粒、HUD、镜头语言和禁用项变成可注入的长期约束。', detail: ['Archivo / Plex Mono / Cormorant', 'BT.709 / grain / halation', '每个 Plate 都继承'] },
  'shader-pass': { artifactType: 'shader-pass', title: 'Shader Pass', eyebrow: '镜头组件 / GLSL', accent: 'violet', cache: 'cold', summary: '可复用的 GPU 全屏或局部效果：raymarch、bloom、halation、线条和后处理。', detail: ['GLSL source + uniforms', 'renderer version pin', '静态编译检查'] },
  'plate-scene': { artifactType: 'plate', title: 'Plate 镜头', eyebrow: '镜头 / Three.js', accent: 'blue', cache: 'cold', summary: '一个可独立预览、可独立缓存的镜头模块；每帧是 song time 的确定性函数。', detail: ['scene.ts + motifs', 'frame/time/audio inputs', 'plate thumbnail artifact'] },
  'timeline-director': { artifactType: 'timeline', title: '时间线导演', eyebrow: '编排 / beat grid', accent: 'orange', cache: 'stale', summary: '用歌词行、词、beat、downbeat 定义镜头窗口，并生成主镜头和转场序列。', detail: ['lyric anchored cuts', 'snap to beat / downbeat', 'timeline.json'] },
  'sample-plan': { artifactType: 'sample-plan', title: '自适应采样计划', eyebrow: '渲染 / temporal AA', accent: 'yellow', cache: 'cold', summary: '根据运动变化选择 4/12/36/108/324 子帧，并记录每帧采样决策。', detail: ['shutter 0.2', 'tol 3 levels', 'motion blur + temporal AA'] },
  composite: { artifactType: 'composite', title: '片段合成', eyebrow: '渲染 / compositor', accent: 'blue', cache: 'cold', summary: '将 Plate、转场、字幕和后处理组合成可交付的局部片段。', detail: ['RGBA frame stream', 'WebSocket backpressure', 'segment manifest'] },
  blackboard: { artifactType: 'video', title: '黑板 / Blackboard', eyebrow: '系统 / artifact bus', accent: 'mint', cache: 'locked', summary: '所有中间产物、hash、血缘、缓存命中和 API 节省量的唯一可见事实源。', detail: ['exact / semantic / off', 'lineage + schema', '不存 API key'] },
};

export const pdoomInitialNodes: PdoomNode[] = [
  { id: 'pdoom-audio', type: 'audio-source', position: { x: 40, y: 80 }, data: { kind: 'audio-source', ...pdoomNodeDefaults['audio-source'] } },
  { id: 'pdoom-stems', type: 'stem-analysis', position: { x: 400, y: 70 }, data: { kind: 'stem-analysis', ...pdoomNodeDefaults['stem-analysis'] } },
  { id: 'pdoom-lyrics', type: 'lyrics-align', position: { x: 400, y: 330 }, data: { kind: 'lyrics-align', ...pdoomNodeDefaults['lyrics-align'] } },
  { id: 'pdoom-beats', type: 'beat-analysis', position: { x: 400, y: 600 }, data: { kind: 'beat-analysis', ...pdoomNodeDefaults['beat-analysis'] } },
  { id: 'pdoom-style', type: 'style-bible', position: { x: 780, y: 70 }, data: { kind: 'style-bible', ...pdoomNodeDefaults['style-bible'] } },
  { id: 'pdoom-shader', type: 'shader-pass', position: { x: 780, y: 350 }, data: { kind: 'shader-pass', ...pdoomNodeDefaults['shader-pass'] } },
  { id: 'pdoom-plate', type: 'plate-scene', position: { x: 1140, y: 70 }, data: { kind: 'plate-scene', ...pdoomNodeDefaults['plate-scene'] } },
  { id: 'pdoom-timeline', type: 'timeline-director', position: { x: 1140, y: 390 }, data: { kind: 'timeline-director', ...pdoomNodeDefaults['timeline-director'] } },
  { id: 'pdoom-samples', type: 'sample-plan', position: { x: 1500, y: 70 }, data: { kind: 'sample-plan', ...pdoomNodeDefaults['sample-plan'] } },
  { id: 'pdoom-composite', type: 'composite', position: { x: 1500, y: 390 }, data: { kind: 'composite', ...pdoomNodeDefaults.composite } },
  { id: 'pdoom-blackboard', type: 'blackboard', position: { x: 1880, y: 230 }, data: { kind: 'blackboard', ...pdoomNodeDefaults.blackboard } },
];

export const pdoomInitialEdges = [
  { id: 'pdoom-audio-stems', source: 'pdoom-audio', target: 'pdoom-stems', animated: true, className: 'edge-mint' },
  { id: 'pdoom-audio-lyrics', source: 'pdoom-audio', target: 'pdoom-lyrics', animated: true, className: 'edge-mint' },
  { id: 'pdoom-audio-beats', source: 'pdoom-audio', target: 'pdoom-beats', animated: true, className: 'edge-mint' },
  { id: 'pdoom-stems-lyrics', source: 'pdoom-stems', target: 'pdoom-lyrics', animated: true, className: 'edge-violet' },
  { id: 'pdoom-stems-beats', source: 'pdoom-stems', target: 'pdoom-beats', animated: true, className: 'edge-violet' },
  { id: 'pdoom-style-plate', source: 'pdoom-style', target: 'pdoom-plate', animated: true, className: 'edge-mint' },
  { id: 'pdoom-shader-plate', source: 'pdoom-shader', target: 'pdoom-plate', animated: true, className: 'edge-violet' },
  { id: 'pdoom-lyrics-timeline', source: 'pdoom-lyrics', target: 'pdoom-timeline', animated: true, className: 'edge-yellow' },
  { id: 'pdoom-beats-timeline', source: 'pdoom-beats', target: 'pdoom-timeline', animated: true, className: 'edge-orange' },
  { id: 'pdoom-plate-timeline', source: 'pdoom-plate', target: 'pdoom-timeline', animated: true, className: 'edge-blue' },
  { id: 'pdoom-timeline-samples', source: 'pdoom-timeline', target: 'pdoom-samples', animated: true, className: 'edge-orange' },
  { id: 'pdoom-samples-composite', source: 'pdoom-samples', target: 'pdoom-composite', animated: true, className: 'edge-yellow' },
  { id: 'pdoom-timeline-composite', source: 'pdoom-timeline', target: 'pdoom-composite', animated: true, className: 'edge-orange' },
  { id: 'pdoom-composite-blackboard', source: 'pdoom-composite', target: 'pdoom-blackboard', animated: true, className: 'edge-blue' },
];
